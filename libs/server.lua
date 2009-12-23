-- 
-- server.lua by blastbeat of the luadch project
-- Re-used here under the MIT/X Consortium License
-- 
-- Modifications (C) 2008-2009 Matthew Wild, Waqas Hussain , Daurnimator
--

-- // wrapping luadch stuff // --

local clean = function( tbl )
    for i, k in pairs( tbl ) do
        tbl[ i ] = nil
    end
end

local log = lomp.updatelog
local table_concat = table.concat

local out_put = function (...) return log ( "INFO: " .. table_concat{...} , 5 ); end
local out_error = function (...) return log ( "ERROR: " .. table_concat{...} , 5 ); end
local mem_free = collectgarbage

----------------------------------// DECLARATION //--

--// constants //--

local STAT_UNIT = 1    -- byte

--// lua functions //--

local type = type
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local collectgarbage = collectgarbage
local setmetatable = setmetatable

--// lua lib methods //--

local os_time = os.time
local os_difftime = os.difftime
local table_remove = table.remove
local string_sub = string.sub
local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield

--// extern libs //--

local luasec = select( 2, pcall( require, "ssl" ) )
local luasocket = require "socket"

--// extern lib methods //--

local ssl_wrap = ( luasec and luasec.wrap )
local socket_bind = luasocket.bind
local socket_sleep = luasocket.sleep
local socket_select = luasocket.select
local ssl_newcontext = ( luasec and luasec.newcontext )

--// functions //--

local id
local loop
local step
local stats
local idfalse
local addtimer
local closeall
local addserver
local getserver
local wrapserver
local getsettings
local closesocket
local removesocket
local removeserver
local changetimeout
local wrapconnection
local changesettings

--// tables //--

local _server
local _readlist
local _timerlist
local _sendlist
local _socketlist
local _closelist
local _readtimes
local _writetimes

--// simple data types //--

local _
local _readlistlen
local _sendlistlen
local _timerlistlen

local _sendtraffic
local _readtraffic

local _selecttimeout
local _sleeptime

local _starttime
local _currenttime

local _maxsendlen
local _maxreadlen

local _checkinterval
local _sendtimeout
local _readtimeout

local _cleanqueue

local _timer

local _maxclientsperserver

----------------------------------// DEFINITION //--

_server = { }    -- key = port, value = table; list of listening servers
_readlist = { }    -- array with sockets to read from
_sendlist = { }    -- arrary with sockets to write to
_timerlist = { }    -- array of timer functions
_socketlist = { }    -- key = socket, value = wrapped socket (handlers)
_readtimes = { }   -- key = handler, value = timestamp of last data reading
_writetimes = { }   -- key = handler, value = timestamp of last data writing/sending
_closelist = { }    -- handlers to close

_readlistlen = 0    -- length of readlist
_sendlistlen = 0    -- length of sendlist
_timerlistlen = 0    -- lenght of timerlist

_sendtraffic = 0    -- some stats
_readtraffic = 0

_selecttimeout = 0    -- timeout of socket.select
_sleeptime = 0    -- time to wait at the end of every loop

_maxsendlen = 51000 * 1024    -- max len of send buffer
_maxreadlen = 25000 * 1024    -- max len of read buffer

_checkinterval = 1200000    -- interval in secs to check idle clients
_sendtimeout = 60000    -- allowed send idle time in secs
_readtimeout = 6 * 60 * 60    -- allowed read idle time in secs

_cleanqueue = false    -- clean bufferqueue after using

_maxclientsperserver = 1000

----------------------------------// PRIVATE //--

wrapserver = function( listeners, socket, ip, serverport, pattern, sslctx, maxconnections, startssl )    -- this function wraps a server

    maxconnections = maxconnections or _maxclientsperserver

    local connections = 0

    local dispatch, disconnect = listeners.incoming or listeners.listener, listeners.disconnect

    local err

    local ssl = false

    if sslctx then
        ssl = true
        if not ssl_newcontext then
            out_error "luasec not found"
            ssl = false
        end
        if type( sslctx ) ~= "table" then
            out_error "server.lua: wrong server sslctx"
            ssl = false
        end
        sslctx, err = ssl_newcontext( sslctx )
        if not sslctx then
            err = err or "wrong sslctx parameters"
            out_error( "server.lua: ", err )
            ssl = false
        end
    end
    if not ssl then
      sslctx = false;
      if startssl then
         out_error( "server.lua: Cannot start ssl on port: ", serverport )
         return nil, "Cannot start ssl,  see log for details"
       else
         out_put("server.lua: ", "ssl not enabled on ", serverport);
       end
    end

    local accept = socket.accept

    --// public methods of the object //--

    local handler = { }

    handler.shutdown = function( ) end

    handler.ssl = function( )
        return ssl
    end
    handler.remove = function( )
        connections = connections - 1
    end
    handler.close = function( )
        for _, handler in pairs( _socketlist ) do
            if handler.serverport == serverport then
                handler.disconnect( handler, "server closed" )
                handler.close( true )
            end
        end
        socket:close( )
        _sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
        _readlistlen = removesocket( _readlist, socket, _readlistlen )
        _socketlist[ socket ] = nil
        handler = nil
        socket = nil
        mem_free( )
        out_put "server.lua: closed server handler and removed sockets from list"
    end
    handler.ip = function( )
        return ip
    end
    handler.serverport = function( )
        return serverport
    end
    handler.socket = function( )
        return socket
    end
    handler.readbuffer = function( )
        if connections > maxconnections then
            out_put( "server.lua: refused new client connection: server full" )
            return false
        end
        local client, err = accept( socket )    -- try to accept
        if client then
            local ip, clientport = client:getpeername( )
            client:settimeout( 0 )
            local handler, client, err = wrapconnection( handler, listeners, client, ip, serverport, clientport, pattern, sslctx, startssl )    -- wrap new client socket
            if err then    -- error while wrapping ssl socket
                return false
            end
            connections = connections + 1
            out_put( "server.lua: accepted new client connection from ", tostring(ip), ":", tostring(clientport), " to ", tostring(serverport))
            return dispatch( handler )
        elseif err then    -- maybe timeout or something else
            out_put( "server.lua: error with new client connection: ", tostring(err) )
            return false
        end
    end
    return handler
end

wrapconnection = function( server, listeners, socket, ip, serverport, clientport, pattern, sslctx, startssl )    -- this function wraps a client to a handler object

    socket:settimeout( 0 )

    --// local import of socket methods //--

    local send
    local receive
    local shutdown

    --// private closures of the object //--

    local ssl

    local dispatch = listeners.incoming or listeners.listener
    local disconnect = listeners.disconnect

    local bufferqueue = { }    -- buffer array
    local bufferqueuelen = 0    -- end of buffer array

    local toclose
    local fatalerror
    local needtls

    local bufferlen = 0

    local noread = false
    local nosend = false

    local sendtraffic, readtraffic = 0, 0

    local maxsendlen = _maxsendlen
    local maxreadlen = _maxreadlen

    --// public methods of the object //--

    local handler = bufferqueue    -- saves a table ^_^

    handler.dispatch = function( )
        return dispatch
    end
    handler.disconnect = function( )
        return disconnect
    end
    handler.setlistener = function( listeners )
        dispatch = listeners.incoming
        disconnect = listeners.disconnect
    end
    handler.getstats = function( )
        return readtraffic, sendtraffic
    end
    handler.ssl = function( )
        return ssl
    end
    handler.send = function( _, data, i, j )
        return send( socket, data, i, j )
    end
    handler.receive = function( pattern, prefix )
        return receive( socket, pattern, prefix )
    end
    handler.shutdown = function( pattern )
        return shutdown( socket, pattern )
    end
    handler.close = function( forced )
        if not handler then return true; end
        _readlistlen = removesocket( _readlist, socket, _readlistlen )
        _readtimes[ handler ] = nil
        if bufferqueuelen ~= 0 then
            if not ( forced or fatalerror ) then
                handler.sendbuffer( )
                if bufferqueuelen ~= 0 then   -- try again...
                    if handler then
                        handler.write = nil    -- ... but no further writing allowed
                    end
                    toclose = true
                    return false
                end
            else
                send( socket, table_concat( bufferqueue, "", 1, bufferqueuelen ), 1, bufferlen )    -- forced send
            end
        end
        _ = shutdown and shutdown( socket )
        socket:close( )
        _sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
        _socketlist[ socket ] = nil
        if handler then
            _writetimes[ handler ] = nil
            _closelist[ handler ] = nil
            handler = nil
        end
        socket = nil
        mem_free( )
	if server then
		server.remove( )
	end
        out_put "server.lua: closed client handler and removed socket from list"
        return true
    end
    handler.ip = function( )
        return ip
    end
    handler.serverport = function( )
        return serverport
    end
    handler.clientport = function( )
        return clientport
    end
    local write = function( data )
        bufferlen = bufferlen + #data
        if bufferlen > maxsendlen then
            _closelist[ handler ] = "send buffer exceeded"   -- cannot close the client at the moment, have to wait to the end of the cycle
            handler.write = idfalse    -- dont write anymore
            return false
        elseif socket and not _sendlist[ socket ] then
            _sendlistlen = _sendlistlen + 1
            _sendlist[ _sendlistlen ] = socket
            _sendlist[ socket ] = _sendlistlen
        end
        bufferqueuelen = bufferqueuelen + 1
        bufferqueue[ bufferqueuelen ] = data
        if handler then
        	_writetimes[ handler ] = _writetimes[ handler ] or _currenttime
        end
        return true
    end
    handler.write = write
    handler.bufferqueue = function( )
        return bufferqueue
    end
    handler.socket = function( )
        return socket
    end
    handler.pattern = function( new )
        pattern = new or pattern
        return pattern
    end
    handler.setsend = function ( newsend )
        send = newsend or send
        return send
    end
    handler.bufferlen = function( readlen, sendlen )
        maxsendlen = sendlen or maxsendlen
        maxreadlen = readlen or maxreadlen
        return maxreadlen, maxsendlen
    end
    handler.lock = function( switch )
        if switch == true then
            handler.write = idfalse
            local tmp = _sendlistlen
            _sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
            _writetimes[ handler ] = nil
            if _sendlistlen ~= tmp then
                nosend = true
            end
            tmp = _readlistlen
            _readlistlen = removesocket( _readlist, socket, _readlistlen )
            _readtimes[ handler ] = nil
            if _readlistlen ~= tmp then
                noread = true
            end
        elseif switch == false then
            handler.write = write
            if noread then
                noread = false
                _readlistlen = _readlistlen + 1
                _readlist[ socket ] = _readlistlen
                _readlist[ _readlistlen ] = socket
                _readtimes[ handler ] = _currenttime
            end
            if nosend then
                nosend = false
                write( "" )
            end
        end
        return noread, nosend
    end
    local _readbuffer = function( )    -- this function reads data
        local buffer, err, part = receive( socket, pattern )    -- receive buffer with "pattern"
        if not err or ( err == "timeout" or err == "wantread" ) then    -- received something
            local buffer = buffer or part or ""
            local len = #buffer
            if len > maxreadlen then
                disconnect( handler, "receive buffer exceeded" )
                handler.close( true )
                return false
            end
            local count = len * STAT_UNIT
            readtraffic = readtraffic + count
            _readtraffic = _readtraffic + count
            _readtimes[ handler ] = _currenttime
            --out_put( "server.lua: read data '", buffer, "', error: ", err )
            return dispatch( handler, buffer, err )
        else    -- connections was closed or fatal error
            out_put( "server.lua: client ", tostring(ip), ":", tostring(clientport), " error: ", tostring(err) )
            fatalerror = true
            disconnect( handler, err )
	    _ = handler and handler.close( )
            return false
        end
    end
    local _sendbuffer = function( )    -- this function sends data
        local buffer = table_concat( bufferqueue, "", 1, bufferqueuelen )
        local succ, err, byte = send( socket, buffer, 1, bufferlen )
        local count = ( succ or byte or 0 ) * STAT_UNIT
        sendtraffic = sendtraffic + count
        _sendtraffic = _sendtraffic + count
        _ = _cleanqueue and clean( bufferqueue )
        --out_put( "server.lua: sended '", buffer, "', bytes: ", tostring(succ), ", error: ", tostring(err), ", part: ", tostring(byte), ", to: ", tostring(ip), ":", tostring(clientport) )
        if succ then    -- sending succesful
            bufferqueuelen = 0
            bufferlen = 0
            _sendlistlen = removesocket( _sendlist, socket, _sendlistlen )    -- delete socket from writelist
            _ = needtls and handler.starttls(true)
            _writetimes[ handler ] = nil
	    _ = toclose and handler.close( )
            return true
        elseif byte and ( err == "timeout" or err == "wantwrite" ) then    -- want write
            buffer = string_sub( buffer, byte + 1, bufferlen )    -- new buffer
            bufferqueue[ 1 ] = buffer    -- insert new buffer in queue
            bufferqueuelen = 1
            bufferlen = bufferlen - byte
            _writetimes[ handler ] = _currenttime
            return true
        else    -- connection was closed during sending or fatal error
            out_put( "server.lua: client ", tostring(ip), ":", tostring(clientport), " error: ", tostring(err) )
            fatalerror = true
            disconnect( handler, err )
            _ = handler and handler.close( )
            return false
        end
    end

    if sslctx then    -- ssl?
        ssl = true
        local wrote
        local read
        local handshake = coroutine_wrap( function( client )    -- create handshake coroutine
                local err
                for i = 1, 10 do    -- 10 handshake attemps
                    _sendlistlen = ( wrote and removesocket( _sendlist, socket, _sendlistlen ) ) or _sendlistlen
                    _readlistlen = ( read and removesocket( _readlist, socket, _readlistlen ) ) or _readlistlen
                    read, wrote = nil, nil
                    _, err = client:dohandshake( )
                    if not err then
                        out_put( "server.lua: ssl handshake done" )
                        handler.readbuffer = _readbuffer    -- when handshake is done, replace the handshake function with regular functions
                        handler.sendbuffer = _sendbuffer
                        -- return dispatch( handler )
                        return true
                    else
                        out_put( "server.lua: error during ssl handshake: ", tostring(err) )
                        if err == "wantwrite" and not wrote then
                            _sendlistlen = _sendlistlen + 1
                            _sendlist[ _sendlistlen ] = client
                            wrote = true
                        elseif err == "wantread" and not read then
                                _readlistlen = _readlistlen + 1
                                _readlist [ _readlistlen ] = client
                                read = true
                        else
                        	break;
                        end
                        --coroutine_yield( handler, nil, err )    -- handshake not finished
                        coroutine_yield( )
                    end
                end
                disconnect( handler, "ssl handshake failed" )
                _ = handler and handler.close( true )    -- forced disconnect
                return false    -- handshake failed
            end
        )
        if startssl then    -- ssl now?
            --out_put("server.lua: ", "starting ssl handshake")
	    local err
            socket, err = ssl_wrap( socket, sslctx )    -- wrap socket
            if err then
                out_put( "server.lua: ssl error: ", tostring(err) )
                mem_free( )
                return nil, nil, err    -- fatal error
            end
            socket:settimeout( 0 )
            handler.readbuffer = handshake
            handler.sendbuffer = handshake
            handshake( socket ) -- do handshake
            if not socket then
                return nil, nil, "ssl handshake failed";
            end
        else
            -- We're not automatically doing SSL, so we're not secure (yet)
            ssl = false
            handler.starttls = function( now )
                if not now then
                    --out_put "server.lua: we need to do tls, but delaying until later"
                    needtls = true
                    return
                end
                --out_put( "server.lua: attempting to start tls on " .. tostring( socket ) )
                local oldsocket, err = socket
                socket, err = ssl_wrap( socket, sslctx )    -- wrap socket
                --out_put( "server.lua: sslwrapped socket is " .. tostring( socket ) )
                if err then
                    out_put( "server.lua: error while starting tls on client: ", tostring(err) )
                    return nil, err    -- fatal error
                end

                socket:settimeout( 0 )

                -- add the new socket to our system

                send = socket.send
                receive = socket.receive
                shutdown = id

                _socketlist[ socket ] = handler
                _readlistlen = _readlistlen + 1
                _readlist[ _readlistlen ] = socket
                _readlist[ socket ] = _readlistlen

                -- remove traces of the old socket

                _readlistlen = removesocket( _readlist, oldsocket, _readlistlen )
                _sendlistlen = removesocket( _sendlist, oldsocket, _sendlistlen )
                _socketlist[ oldsocket ] = nil

                handler.starttls = nil
                needtls = nil
                
                -- Secure now
                ssl = true

                handler.readbuffer = handshake
                handler.sendbuffer = handshake
                handshake( socket )    -- do handshake
            end
            handler.readbuffer = _readbuffer
            handler.sendbuffer = _sendbuffer
        end
    else    -- normal connection
        ssl = false
        handler.readbuffer = _readbuffer
        handler.sendbuffer = _sendbuffer
    end

    send = socket.send
    receive = socket.receive
    shutdown = ( ssl and id ) or socket.shutdown

    _socketlist[ socket ] = handler
    _readlistlen = _readlistlen + 1
    _readlist[ _readlistlen ] = socket
    _readlist[ socket ] = _readlistlen

    return handler, socket
end

id = function( )
end

idfalse = function( )
    return false
end

removesocket = function( list, socket, len )    -- this function removes sockets from a list ( copied from copas )
    local pos = list[ socket ]
    if pos then
        list[ socket ] = nil
        local last = list[ len ]
        list[ len ] = nil
        if last ~= socket then
            list[ last ] = pos
            list[ pos ] = last
        end
        return len - 1
    end
    return len
end

closesocket = function( socket )
    _sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
    _readlistlen = removesocket( _readlist, socket, _readlistlen )
    _socketlist[ socket ] = nil
    socket:close( )
    mem_free( )
end

----------------------------------// PUBLIC //--

addserver = function( listeners, port, addr, pattern, sslctx, maxconnections, startssl )    -- this function provides a way for other scripts to reg a server
    local err
    --out_put("server.lua: autossl on ", port, " is ", startssl)
    if type( listeners ) ~= "table" then
        err = "invalid listener table"
    end
    if not type( port ) == "number" or not ( port >= 0 and port <= 65535 ) then
        err = "invalid port"
    elseif _server[ port ] then
        err =  "listeners on port '" .. port .. "' already exist"
    elseif sslctx and not luasec then
        err = "luasec not found"
    end
    if err then
        out_error( "server.lua, port ", port, ": ", err )
        return nil, err
    end
    addr = addr or "*"
    local server, err = socket_bind( addr, port )
    if err then
        out_error( "server.lua, port ", port, ": ", err )
        return nil, err
    end
    local handler, err = wrapserver( listeners, server, addr, port, pattern, sslctx, maxconnections, startssl )    -- wrap new server socket
    if not handler then
        server:close( )
        return nil, err
    end
    server:settimeout( 0 )
    _readlistlen = _readlistlen + 1
    _readlist[ _readlistlen ] = server
    _server[ port ] = handler
    _socketlist[ server ] = handler
    out_put( "server.lua: new server listener on '", addr, ":", port, "'" )
    return handler
end

getserver = function ( port )
	return _server[ port ];
end

removeserver = function( port )
    local handler = _server[ port ]
    if not handler then
        return nil, "no server found on port '" .. tostring( port ) "'"
    end
    handler.close( )
    _server[ port ] = nil
    return true
end

closeall = function( )
    for _, handler in pairs( _socketlist ) do
        handler.close( )
        _socketlist[ _ ] = nil
    end
    _readlistlen = 0
    _sendlistlen = 0
    _timerlistlen = 0
    _server = { }
    _readlist = { }
    _sendlist = { }
    _timerlist = { }
    _socketlist = { }
    mem_free( )
end

getsettings = function( )
    return  _selecttimeout, _sleeptime, _maxsendlen, _maxreadlen, _checkinterval, _sendtimeout, _readtimeout, _cleanqueue, _maxclientsperserver
end

changesettings = function( new )
    if type( new ) ~= "table" then
        return nil, "invalid settings table"
    end
    _selecttimeout = tonumber( new.timeout ) or _selecttimeout
    _sleeptime = tonumber( new.sleeptime ) or _sleeptime
    _maxsendlen = tonumber( new.maxsendlen ) or _maxsendlen
    _maxreadlen = tonumber( new.maxreadlen ) or _maxreadlen
    _checkinterval = tonumber( new.checkinterval ) or _checkinterval
    _sendtimeout = tonumber( new.sendtimeout ) or _sendtimeout
    _readtimeout = tonumber( new.readtimeout ) or _readtimeout
    _cleanqueue = new.cleanqueue
    _maxclientsperserver = new._maxclientsperserver or _maxclientsperserver
    return true
end

addtimer = function( listener )
    if type( listener ) ~= "function" then
        return nil, "invalid listener function"
    end
    _timerlistlen = _timerlistlen + 1
    _timerlist[ _timerlistlen ] = listener
    return true
end

stats = function( )
    return _readtraffic, _sendtraffic, _readlistlen, _sendlistlen, _timerlistlen
end

local dontstop = true; -- thinking about tomorrow, ...

local setquitting = function (quit)
	dontstop = not quit;
	return;
end

step = function( )
        local read, write, err = socket_select( _readlist, _sendlist, _selecttimeout )
        for i, socket in ipairs( write ) do    -- send data waiting in writequeues
            local handler = _socketlist[ socket ]
            if handler then
                handler.sendbuffer( )
            else
                closesocket( socket )
                out_put "server.lua: found no handler and closed socket (writelist)"    -- this should not happen
            end
        end
        for i, socket in ipairs( read ) do    -- receive data
            local handler = _socketlist[ socket ]
            if handler then
                handler.readbuffer( )
            else
                closesocket( socket )
                out_put "server.lua: found no handler and closed socket (readlist)"    -- this can happen
            end
        end
        for handler, err in pairs( _closelist ) do
            handler.disconnect( )( handler, err )
            handler.close( true )    -- forced disconnect
        end
        clean( _closelist )
        _currenttime = os_time( )
        if os_difftime( _currenttime - _timer ) >= 1 then
            for i = 1, _timerlistlen do
                _timerlist[ i ]( )    -- fire timers
            end
            _timer = _currenttime
        end
        socket_sleep( _sleeptime )    -- wait some time
        --collectgarbage( )
	
	return dontstop
end

loop = function ( )
    while step ( ) do end
    return "quitting"
end

--// EXPERIMENTAL //--

local wrapclient = function( socket, ip, serverport, listeners, pattern, sslctx, startssl )
    local handler = wrapconnection( nil, listeners, socket, ip, serverport, "clientport", pattern, sslctx, startssl )
    _socketlist[ socket ] = handler
    _sendlistlen = _sendlistlen + 1
    _sendlist[ _sendlistlen ] = socket
    _sendlist[ socket ] = _sendlistlen
    return handler, socket
end

local addclient = function( address, port, listeners, pattern, sslctx, startssl )
    local client, err = luasocket.tcp( )
    if err then
        return nil, err
    end
    client:settimeout( 0 )
    _, err = client:connect( address, port )
    if err then    -- try again
        local handler = wrapclient( client, address, port, listeners )
    else
        wrapconnection( nil, listeners, client, address, port, "clientport", pattern, sslctx, startssl )
    end
end

--// EXPERIMENTAL //--

----------------------------------// BEGIN //--

setmetatable ( _socketlist, { __mode = "k" } )
setmetatable ( _readtimes, { __mode = "k" } )
setmetatable ( _writetimes, { __mode = "k" } )

_timer = os_time( )
_starttime = os_time( )

addtimer( function( )
        local difftime = os_difftime( _currenttime - _starttime )
        if difftime > _checkinterval then
            _starttime = _currenttime
            for handler, timestamp in pairs( _writetimes ) do
                if os_difftime( _currenttime - timestamp ) > _sendtimeout then
                    --_writetimes[ handler ] = nil
                    handler.disconnect( )( handler, "send timeout" )
                    handler.close( true )    -- forced disconnect
                end
            end
            for handler, timestamp in pairs( _readtimes ) do
                if os_difftime( _currenttime - timestamp ) > _readtimeout then
                    --_readtimes[ handler ] = nil
                    handler.disconnect( )( handler, "read timeout" )
                    handler.close( )    -- forced disconnect?
                end
            end
        end
    end
)

----------------------------------// PUBLIC INTERFACE //--

return {

    addclient = addclient,
    wrapclient = wrapclient,
    
    loop = loop,
    setquitting = setquitting,
    step = step,
    stats = stats,
    closeall = closeall,
    addtimer = addtimer,
    addserver = addserver,
    getserver = getserver,
    getsettings = getsettings,
    setquitting = setquitting,
    removeserver = removeserver,
    changesettings = changesettings,
}
