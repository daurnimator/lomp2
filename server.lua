--[[module ( "lomp" )
require"general"
require"socket"
require"xmlrpc"

server = { backlog = 5 , timeout = 2 }
function server.listen ( force )
	if force or not server.master then 
		local err
		if server.master then server.master:close() end
		server.master , err =  socket.tcp()
		if err then updatelog ( "Could not create tcp socket: " .. err , 0 ) end
		do
			local err , a
			a , err = server.master:bind ( config.address , config.port )
			if err then updatelog ( "Could not bind master socket: " .. err , 0 ) end
		end
		do
			local err , a
			a , err = server.master:listen ( server.backlog )
			if err then updatelog ( "Could not listen to master socket: " .. err , 0 ) end
		end
	end
end
function server.accept ( )
	local err
	server.client , err = server.master:accept ( )
end
function server.interpret ( method_call )
	local a , b , c , d
	server.cmd = function ( cmdtbl )
		for i , v in ipairs ( cmdtbl ) do
			--_G[v.cmd] ( unpack ( v ) )
			print(v.cmd.."\n")
		end
		return "returned interpreter test"
	end
	a , b = xpcall ( e = assert( loadstring ( "a = lomp.server.cmd { " .. data .. " } print('cmd result ' ..a) return a" ) print( e) return e ) ( ) , updatelog )
	print(a,b,c)
	--assert(loadstring( "cmd { " .. data .. " }")) ( )
	return b
	method_name, list_params = xmlrpc.srvDecode ( method_call ) 
	xmlrpc.srvMethods ( _G )
	local a , b = packn ( 1 , xmlrpc.dispatch (method_name) ( unpack ( list_params ) ) )
	if a then
		method_response = xmlrpc.srvEncode ( b )
	else
		method_response = xmlrpc.srvEncode ( { faultCode = 1 , faultString = b } , 1 ) -- Generate fault
		updatelog ( "Error interpreting command.\n" .. b )
	end
	return method_response
end
function server.go ( )
	while true do
		while server.master do
			while server.client do
				local a , b , c , d , e , f , g
				a , b = server.client:receive ( "*a")
				if not a then updatelog ( b ) 
				else
					p("Received: " .. a )
					c =  server.interpret ( a )
					p("To Send: ".. c)
					d , f , g = server.client:send ( c )
					p("Sent: " .. d , f,g)
					server.client:close ( )
				end
			end
			p(server.master)
			server.accept ( )
		end
		server.listen ( )
	end
	server.master = nil
end

--]]

module ( "lomp" )
server = {}
require"socket"
require"socket.url"
require"copas"
require"mime" -- For base64 decoding of authorisation
require"xmlrpc"

local httpcodes = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[307] = "Temporary Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Time-out",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Large",
	[415] = "Unsupported Media Type",
	[416] = "Requested range not satisfiable",
	[417] = "Expectation Failed",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Time-out",
	[505] = "HTTP Version not supported"
	}
	
local function httpdate ( )
	--eg, "Sun, 10 Apr 2005 20:27:03 GMT"
	return os.date ( "%a, %d %b %Y %H:%M:%S GMT" )
end

local function httpresponse ( skt , status, headers , body , typ , fatal )
	str = httpcodes[status]
	typ = typ or "text/html"
	body = body or "<html><head><title>HTTP Code " .. status .. "</title></head><body><h1>HTTP Code " .. status .. "</h1><p>" .. str .. "</p></body></html>" 
	local message = "HTTP/1.0 " .. status .. " " .. str .. "\r\n" 
	message = message .. "Date: " .. httpdate ( ) .. "\r\n"
	message = message .. "Server: " .. "lomp 0.0.1" .. "\r\n"
	message = message .. "Content-Type: " .. typ .. "\r\n"
	message = message .. "Content-Length: " .. string.len ( body ) .. "\r\n"
	for k,v in pairs ( headers ) do
		message = message .. k .. ": " .. v .. "\r\n"
	end
	if fatal then message = message .. "Connection: close\r\n" end
	message = message .. "\r\n"
	message = message .. body
	
	copas.send ( skt , message )
	
	return code , str , message
end

--[[local function echoHandler(skt)
	while true do
		local data = copas.receive(skt)
		if data == "quit" then
			break
		end
		if data then 
			print(data)
			copas.send(skt, data)
		end
	end
end--]]

local function lompserver ( skt )
	local found , chunk , code , request , size = false , 0 , false , "" , 0
	while not found and chunk < 20 do -- max of 20 lines, more and possible DOS Attack
		local data = copas.receive ( skt )
		request = request .. data .. "\r\n"
		local length = string.len ( data )
		size = size + length
		if length < 1 then
			found = true;
		end
		local position , len = string.find ( request, '\r\n\r\n' )
		if position ~= nil then
			found = true
		end
		chunk = chunk + 1
	end
	--print( request )
	
	local _, _, Method, Path, Major, Minor  = string.find(request, "([A-Z]+) (.+) HTTP/(%d).(%d)")
	Path = socket.url.unescape ( Path )
	local headers = {} for k, v in string.gmatch ( request , "\r\n([^:]+): ([^\r\n]+)" ) do headers[string.lower ( k )] = v end
	if not headers["host"] then headers["host"] = "default" end
	if headers["content-length"] then body = copas.receive ( skt , headers["content-length"] ) end
	
	--print( body )
	if config.authorisation then
		local authorised = false
		if headers["authorization"] then
			local _ , _ , AuthType , AuthString = string.find ( headers["authorization"] , "([^ ]+)% +(.+)" )
			if string.lower ( AuthType )  == "basic" then
				local _ , _ , user , pass = string.find ( mime.unb64 ( AuthString ) , "([^:]+):(.+)" )
				--print(AuthType,AuthString,user,password,config.username,config.password)
				if user == config.username and pass == config.password then authorised = true end
			elseif string.lower ( AuthType ) == "digest" then
				
			end
		end
		if not authorised then httpresponse ( skt , 401 , { ['WWW-Authenticate'] = 'Basic realm="LOMP"' } , nil , nil , true ) return false end
	end
	if Method == "POST" then
		local method_name , list_params = xmlrpc.srvDecode ( body )
		if _M[method_name] then
			local s = { _M[method_name]( unpack ( list_params ) ) }
			local x = xmlrpc.srvEncode ( s )
			httpresponse ( skt , 200 , { } , x , "text/xml" )
		elseif method_name == "cmds" then
			local x = ""
			for k , v in pairs( _M ) do
				if not ( string.sub ( k , 1 , 1 ) == "_" ) then
					x = x .. k .. "\n"
				end
			end
			httpresponse ( skt , 200 , { } , x , "text" )
		else
			local x = xmlrpc.srvEncode ( { faultCode = 404 , faultString = httpcodes[404] } , true )
			httpresponse ( skt , 404 , { } , x , "text/xml" )
		end
		print ( "Received Command: " .. method_name )
		return true 
	elseif Method == "GET" then
	elseif Method == "HEAD" then
	elseif Method == "PUT" then
	elseif Method == "DELETE" then
	elseif Method == "TRACE" then
	elseif Method == "CONNECT" then
	elseif Method == "OPTIONS" then	
	else
		httpresponse ( skt , 405, nil , nil , true )
		return true
	end
	
	httpresponse ( skt , 503, nil , nil , true )
end
function server.inititate ( host , port )
	server.server = socket.bind ( host , port)
	--copas.addserver(server, echoHandler) -- Echo Handler
	copas.addserver ( server.server , lompserver )
end
function server.step ( )
	copas.step ( )
end
