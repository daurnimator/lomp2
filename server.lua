--local format, gsub, strfind, strsub = string.format, string.gsub, string.find, string.sub
--local concat, getn, tinsert = table.concat, table.getn, table.insert

module ( "lomp" )
server = {}
require"socket"
require"socket.url"
require"copas"
require"mime" -- For base64 decoding of authorisation
require"xmlrpc"
require"ex"

local mime = { }
do
	local f = io.open ( "/etc/mime.types" , "r" )
	if f then
		while true do
			local line = f:read ( )
			if not line then break end
			local _ , _ , typ , name = string.find ( line , "^(.*)\t+([^\t]+)$" )
			if typ then
				for e in string.gmatch ( name , "([^%s]+)" ) do
					mime[e] = typ
				end
			end
		end
		f:close ( )
	else
		mime["html"] = "text/html"
		mime["htm"] = "text/html"
		mime["txt"] = "text/plain"
		mime["jpg"] = "image/jpeg"
		mime["jpeg"] = "image/jpeg"
		mime["gif"] = "image/gif"
		mime["png"] = "image/png"
	end
end


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
	return os.date ( "!%a, %d %b %Y %H:%M:%S GMT" )
end

local function httpresponse ( skt , status, headers , body , typ , fatal )
	local str = httpcodes[status]
	headers = headers or {}
	typ = typ or "text/html"
	body = body or "<html><head><title>HTTP Code " .. status .. "</title></head><body><h1>HTTP Code " .. status .. "</h1><p>" .. str .. "</p></body></html>" 
	local message = "HTTP/1.0 " .. status .. " " .. str .. "\r\n" 
	message = message .. "Date: " .. httpdate ( ) .. "\r\n"
	message = message .. "Server: " .. core._NAME .. ' ' .. core._VERSION .. "\r\n"
	message = message .. "Content-Type: " .. typ .. "\r\n"
	message = message .. "Content-Length: " .. string.len ( body ) .. "\r\n"
	for k,v in pairs ( headers ) do
		message = message .. k .. ": " .. v .. "\r\n"
	end
	if fatal then message = message .. "Connection: close\r\n" end
	message = message .. "\r\n" -- Signal end of header(s)
	message = message .. body
	
	local bytessent , err = copas.send ( skt , message )
	
	return code or 0 , str , message , bytessent
end

--[[local function echoHandler( skt )
	while true do
		local data = copas.receive( skt )
		if data == "quit" then
			break
		end
		if data then 
			print(data)
			copas.send(skt, data .. "\r\n")
		end
	end
end--]]

local function auth ( headers )
	if config.authorisation then
		if headers["authorization"] then -- If using http authorization
			local _ , _ , AuthType , AuthString = string.find ( headers["authorization"] , "([^ ]+)% +(.+)" )
			if string.lower ( AuthType )  == "basic" then -- If they are trying Basic Authentication:
				local _ , _ , user , pass = string.find ( mime.unb64 ( AuthString ) , "([^:]+):(.+)" ) -- Decrypt username:password ( Sent in base64 )
				--print(AuthType,AuthString,user,password,config.username,config.password)
				-- Check credentials:
				if user == config.username and pass == config.password then
					return true
				else -- Credentials incorrect
					return false , "basic"
				end
			--elseif string.lower ( AuthType ) == "digest" then 
				-- TODO: Implement digest authentication
			end
		else -- No "Authorization" header present: Other authorisation being used?
			return false , "basic" -- Tell them to login using Basic Auth (Only thing currently supported)
		end
	else -- Open Access Wanted
		return true
	end
end

local function xmlrpcserver ( skt , r , headers , body )
			local authorised , typ = auth ( headers )
			if not authorised then
				if typ == "basic" then
					-- Send a xml fault document
					updatelog ( "Unauthorised login blocked." , 2 )
					httpresponse ( skt , 401 , { ['WWW-Authenticate'] = 'Basic realm=" ' .. core._NAME .. ' ' .. core._VERSION .. '"' } , xmlrpc.srvEncode ( { faultCode = 401 , faultString = httpcodes[401] } , true ) , "text/xml" , true )
				end
			else -- Authorised
				--print( body )
				--print(list_params)
				--print ( "Received Command: " , method_name , "Parameters: " , unpack ( list_params or {} ) )
				--[[if _M[method_name] then
					local s = { _M[method_name] ( unpack ( list_params ) ) }
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
				end--]]
				--for k,v in pairs(_M) do print(k,v) end
				local method_name , list_params = xmlrpc.srvDecode ( body )
				list_params = list_params[1] --I don't know why it needs this, but it does
				print ( "Received Command: " , method_name , "Parameters: " , unpack ( list_params or {} ) )
				for k,v in pairs(list_params) do print(k,v) end
				local function dispatch (name)
					--[[if name == "cmds" then return true
					elseif name == "restart" then return true end
					local ok, _, obj, method = string.find (name, "^([^.]+)%.(.+)$")
					if not ok then
						return _M[name]
					else
						return function (...)
							return _M[obj][method] (obj, unpack (...))
						end
					end--]]
					print ("dispatch")
					for k,v in pairs (_M) do print (k,v) end
					return function ( ... ) print ( ... ) return _M[name] ( ... ) end
				end
				xmlrpc.srvMethods ( dispatch )
				local func = xmlrpc.dispatch ( method_name )
				local ok, result, err = pcall (func, unpack (list_params or {}))
				if ok then
					result = { code = 3, message = result, }
				end--]]
				--result = dispatch ( method_name ) ( unpack ( list_params ) )
				httpresponse ( skt , 200 , { } , xmlrpc.srvEncode (result, not ok) , "text/xml" )
				
				return true
			end
end

local function webserver ( skt , r , headers , body )
		-- Serve html :D
		--local authorised , typ = auth ( headers )
		local code , doc , hdr , mimetyp = 206 , nil , { } , "text/html"
		local defaultfiles = { "index.html" , "index.htm" }
		local file = r.file
		local sfile = string.gsub ( file , "/%.[^/]*" , "" )
		if not authorised and sfile ~= file then 
			--code = 307
			--hdr["Location"] = "http://" .. headers["host"] .. sfile
			code = 401
		else 
			file = "." .. file
			local f , filecontents
			if string.sub ( file , -1 ) ~= "/" then 
				local entry = os.dirent ( file )
				if entry and entry.type == "directory" then file = file .. "/" end
			end
			if string.sub ( file , -1 ) == "/" then 
				local entry , err
				for i , v in ipairs ( defaultfiles ) do
					entry , err = os.dirent ( file .. v )
					if entry then break end
				end
				if not entry then
					--doc = "<html><head><title>" .. core._NAME .. ' ' .. core._VERSION .. " Web Client</title></head><body><h1>Coming Soon!</h1></body></html>"
					-- Directory listing
					do
						doc = "<html><head><title>" .. core._NAME .. ' ' .. core._VERSION .. " Directory Listing</title></head><body><h1>Listing of " .. file .. "</h1><ul>"
						local t = { }
						for entry in os.dir ( file ) do 
							if string.sub ( entry.name , 1 , 1 ) ~= "." then
								t[#t+1] = entry
							end
						end
						table.sort ( t , function (a,b) if string.lower( a.name ) < string.lower( b.name ) then return true end end)
						table.sort ( t , function (a,b) if string.lower( a.type ) < string.lower( b.type ) then return true end end)
						for i , v in ipairs ( t ) do
							local n = v.name
							if v.type == "directory" then n = n .. "/" end
							doc = doc .. "<li><a href='" .. n .. "'>" .. n .. "</a> " .. v.size .. " Bytes</li>"
						end
						doc = doc .. "</ul></body></html>"
					end
					code = 200
				end
			else 
				f = io.open ( file , "rb" )
			end
			if doc then
			elseif not f then
				code = 404
			else
				filecontents = f:read ( "*all" )
				f:close()
				
				doc = filecontents
				code = 200
			end
			local _ , _ , extension = string.find ( file , "%.(.+)$" )
			mimetyp = mime[extension]
		end
		do
			local code , str , msg , bytessent = httpresponse ( skt , code , hdr , doc , mimetyp )
			-- Apache Log Format
			print ( string.format ( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"', skt:getpeername ( ) , os.date ( "!%m/%b/%Y:%H:%M:%S GMT" ) , r.Path , r.Major , r.Minor , code , bytessent , headers["referer"] or "-" , headers["agent"] or "-" ) )
		end
		return true
end

local function lompserver ( skt )
	-- Retrive HTTP header
	local found , chunk , code , request , rsize = false , 0 , false , "" , 0
	while not found do
		if chunk < 20 then
			local data = copas.receive ( skt )
			if data then
				request = request .. data .. "\r\n"
				
				local length = string.len ( data )
				if length < 1 then found = true end
				rsize = rsize + length
				
				local position , len = string.find ( request, '\r\n\r\n' )
				if position then found = true end
			else
				return false
			end
			chunk = chunk + 1
		else -- max of 20 lines, more and possible DOS Attack
			return false
		end
	end
	--print( request )
	
	local _ , _ , Method , Path , Major , Minor = string.find ( request , "([A-Z]+) ([^ ]+) HTTP/(%d).(%d)" )
	Method = string.upper ( Method )
	if not Major then return false end -- Not HTTP
	local file , querystring = string.match ( Path , "([^%?]+)%??(.*)$" ) 	-- HTTP Reserved characters: !*'();:@&=+$,/?%#[]
															-- HTTP Unreserved characters: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~
															-- Lua reserved pattern characters: ^$()%.[]*+-?
															-- Intersection of http and lua reserved: *+$?%[]
															-- %!%*%'%(%)%;%:%@%&%=%+%$%,%/%?%%%#%[%]
	file = socket.url.unescape ( file )
	local queryvars = { }
	if querystring then
		for k, v in string.gmatch( querystring , "([%w%-%_%.%~]+)=([%w%-%_%.%~]+)&?") do
			queryvars[socket.url.unescape ( k )] = socket.url.unescape ( v )
		end
	end
	local headers = {} for k, v in string.gmatch ( request , "\r\n([^:]+): ([^\r\n]+)" ) do headers[string.lower ( k )] = v end
	if not headers["host"] then headers["host"] = "default" end
	
	local r = { Method = Method , Path = Path , Major = Major , Minor = Minor , file = file , querystring = querystring , queryvars = queryvars }
	
	local body
	if headers["content-length"] then body = copas.receive ( skt , headers["content-length"] ) end
	
	if Method == "POST" then
		if headers["content-type"] == "text/xml" then -- This is an xmlrpc command
			return xmlrpcserver ( skt , r , headers , body )
		end
	elseif Method == "GET" then
		return webserver ( skt , r , headers , body )
	elseif Method == "HEAD" then
	elseif Method == "PUT" then
	elseif Method == "DELETE" then
	elseif Method == "TRACE" then
	elseif Method == "CONNECT" then
	elseif Method == "OPTIONS" then	
	else
		httpresponse ( skt , 405, { Allow = "GET, POST" } , nil , nil ,true )
		return true
	end
	
	httpresponse ( skt , 503, nil , nil , nil , true )
end
function server.inititate ( host , port )
	server.server , err = socket.bind ( host , port )
	--copas.addserver(server, echoHandler) -- Echo Handler
	if server.server then 
		copas.addserver ( server.server , lompserver )
		updatelog ( "Server started bound to '" .. "', port #" .. port , 4 ) 
		return true
	else
		updatelog ( "Server could not be started: " .. err , 0 )
		return false
	end
end
function server.step ( )
	copas.step ( )
end
