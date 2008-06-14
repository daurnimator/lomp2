--local format, gsub, strfind, strsub = string.format, string.gsub, string.find, string.sub
--local concat, getn, tinsert = table.concat, table.getn, table.insert

module ( "lomp" )
server = {}
require"socket"
require"socket.url"
require"copas"
require"mime" -- For base64 decoding of authorisation
require"xmlrpc"
--require"ex"
require"lfs"

local mimetypes = { }
do
	local f = io.open ( "/etc/mime.types" , "r" )
	if f then
		while true do
			local line = f:read ( )
			if not line then break end
			local _ , _ , typ , name = string.find ( line , "^(.*)\t+([^\t]+)$" )
			if typ then
				for e in string.gmatch ( name , "([^%s]+)" ) do
					mimetypes[e] = typ
				end
			end
		end
		f:close ( )
	else
		mimetypes["html"] = "text/html"
		mimetypes["htm"] = "text/html"
		mimetypes["txt"] = "text/plain"
		mimetypes["jpg"] = "image/jpeg"
		mimetypes["jpeg"] = "image/jpeg"
		mimetypes["gif"] = "image/gif"
		mimetypes["png"] = "image/png"
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
local function httpsend ( skt , requestdetails , status , headers , body )
	if type ( status ) ~= "number" or status < 100 or status > 599 then error ( "Invalid http code" ) end
	local reasonphrase = httpcodes [ status ]
	
	local sheaders = { }
	for k , v in pairs ( ( headers or { } ) ) do
		sheaders [ string.lower ( k ) ] = v
	end
	
	if requestdetails.Method ~= "HEAD" then 
		body = body or ( "<html><head><title>HTTP Code " .. status .. "</title></head><body><h1>HTTP Code " .. status .. "</h1><p>" .. reasonphrase .. "</p></body></html>" )
	else
		body = ""
	end
	
	local message = "HTTP/1.1 " .. status .. " " .. reasonphrase .. "\r\n" 

	sheaders [ "date" ] = httpdate ( )
	sheaders [ "server" ] = core._NAME .. ' ' .. core._VERSION
	sheaders [ "content-type" ] = sheaders [ "content-type" ] or "text/html"
	sheaders [ "content-length" ] = string.len ( body )
	
	for k,v in pairs ( sheaders ) do
		message = message .. k .. ": " .. v .. "\r\n"
	end
	
	--if requestdetails.headers [ "connection" ] == "close" then message = message .. "Connection: close\r\n" end
	message = message .. "\r\n" -- Signal end of header(s)
	
	message = message .. body
	
	local bytessent , err = copas.send ( skt , message )
	
	return status , reasonphrase , bytessent
end
local function dispatch ( baseenv , name )
	if type ( name ) ~= "string" then return false end
	local func = baseenv
	for k in string.gmatch ( name , "(%w+)%." ) do
		func = func [ k ]
	end
	func = func [ select ( 3 , string.find ( name , "([^%.]+)$" ) ) ]
	
	return func
end

local function auth ( headers )
	if config.authorisation then
		local preferred = "basic" -- Preferred method is basic auth (Only thing currently supported)
		if headers [ "authorization" ] then -- If using http authorization
			local _ , _ , AuthType , AuthString = string.find ( headers [ "authorization" ] , "([^ ]+)% +(.+)" )
			if string.lower ( AuthType )  == "basic" then -- If they are trying Basic Authentication:
				local _ , _ , user , pass = string.find ( mime.unb64 ( AuthString ) , "([^:]+):(.+)" ) -- Decrypt username:password ( Sent in base64 )
				--print(AuthType,AuthString,user,password,config.username,config.password)
				-- Check credentials:
				if user == config.username and pass == config.password then
					return true
				else -- Credentials incorrect
					return false , preferred 
				end
			--elseif string.lower ( AuthType ) == "digest" then 
				-- TODO: Implement digest authentication
			end
		else -- No "Authorization" header present: Other authorisation being used?
			return false , preferred 
		end
	else -- Open Access Wanted
		return true
	end
end

local function xmlrpcserver ( skt , requestdetails , body )
	local authorised , typ = auth ( requestdetails.headers )
	if not authorised then
		if typ == "basic" then
			-- Send a xml fault document
			updatelog ( "Unauthorised login blocked." , 2 )
			httpsend ( skt , requestdetails , 401 , { [ 'WWW-Authenticate' ] = 'Basic realm=" ' .. core._NAME .. ' ' .. core._VERSION .. '"' ; [ 'content-length' ] = "text/xml" } , xmlrpc.srvEncode ( { faultCode = 401 , faultString = httpcodes [ 401 ] } , true ) )
			return false
		end
	else -- Authorised
		--print (body)
		local method_name , list_params = xmlrpc.srvDecode ( body )
		list_params = list_params[1] --I don't know why it needs this, but it does
		
		local function d ( ... ) return dispatch ( _M , ... ) end
		xmlrpc.srvMethods ( d )
		local func = xmlrpc.dispatch ( method_name )
		local function interpret ( ok , err , ... )
			if not ok then
				return ok , err
			else
				return ok , { err , ... }
			end
		end

		local function depack ( t , i , j )
			i = i or 1
			if ( j and i > j ) or ( not j and t [ tostring ( i ) ] == nil ) then return end 
			return t [ tostring ( i ) ] , depack ( t , i + 1 , j )
		end 
				
		local ok , result = interpret ( pcall ( func , depack ( list_params or { } ) ) )

		httpsend ( skt , requestdetails , 200 , { [ 'content-length' ] = "text/xml" } , xmlrpc.srvEncode ( result , not ok) )
			
		return true
	end
end
local function basiccmdserver ( skt , requestdetails )
	-- Execute action based on GET string.
	local authorised , typ = auth ( requestdetails.headers )
	if not authorised then
		if typ == "basic" then
			-- Send an xml fault document
			updatelog ( "Unauthorised login blocked." , 2 )
			httpsend ( skt , requestdetails , 401 , { ['WWW-Authenticate'] = 'Basic realm=" ' .. core._NAME .. ' ' .. core._VERSION .. '"' } )
			return false
		end		
	else
		local cmd = requestdetails.queryvars [ "cmd" ]
		
		--for k , v in pairs ( requestdetails.queryvars ) do print ( k,v ) end
		
		local i = 1
		local params = { }
		while true do
			if requestdetails.queryvars [ tostring ( i ) ] then
				local v = requestdetails.queryvars [ tostring ( i ) ]
				local t = v:sub ( 1 , 1 )
				local s = v:sub ( 2 , -1 )
				if t == "s" then
					params [ i ] = s
				elseif t == "n" and tonumber ( s ) then
					params [ i ] = tonumber ( s )
				elseif t == "-" then
					params [ i ] = nil
				elseif t == "b" and s == "f" or s == "false" then
					params [ i ] = false
				elseif t == "b" then
					params [ i ] = true
				else
					httpsend ( skt , 400 )
					return false
				end
			else break
			end
			i = i + 1
		end
		
		local func = dispatch ( _M , cmd )
		
		if func then 
			local doc
			local function makeresponse ( pcallok , ok , ... )
				if pcallok and ok then
					doc = "<html><head><title>Completed Command: " .. cmd .. "</title></head><body><h1>Completed Command: " .. cmd .. "</h1><h2>Results:</h2><ul>" 
					for i , v in ipairs ( { ok , ... } ) do
						if tostring ( v ) then
							doc = doc .. "<li>" .. tostring ( v ) .. "</li>"
						else
						end
					end
					doc = doc .. "</ul></body></html>" 
					
					return 200 , doc
				else
					doc = "<html><head><title>Failure in: " .. cmd .. "</title></head><body><h1>Failure in: " .. cmd .. "</h1><h2>Error:</h2>" 
					if not pcallok then
						doc = doc .. "<p>" .. ok .. "</p>"
					else
						doc = doc .. "<ul>"
						for i , v in ipairs ( { ok , ... } ) do
							doc = doc .. "<li>" .. tostring ( v ) .. "</li>"
						end
						doc = doc .. "</ul>"
					end
					doc = doc .. "</body></html>" 
					
					return 500 , doc
				end
			end
			local status , doc = makeresponse ( pcall ( func , unpack ( params ) ) )
			local code , str , msg , bytessent = httpsend ( skt , requestdetails , status , nil , doc )
			return true
		else 
			httpsend ( skt , requestdetails , 404 )
			return false
		end
	end
end
local function webserver ( skt , requestdetails , body ) -- Serve html interface
		local code , doc , hdr , mimetyp = 206 , nil , { } , "text/html"
		local publicdir = "."
		local allowdirectorylistings = true
		
		function pathtomime ( path )
			local _ , _ , extension = string.find ( path , "%.(.+)$" )
			return mimetypes [ extension ]
		end

		local defaultfiles = { "index.html" , "index.htm" }
			
		local sfile = string.gsub ( requestdetails.file , "/%.[^/]*" , "" ) -- Strip out ".." and "." of file request
		local path = publicdir .. sfile -- Prefix with public dir path
			
		if string.sub ( path , -1 ) ~= "/" and lfs.attributes ( path , "mode" ) ~= "directory" then -- Requesting a specific file
			local f , filecontents
			f = io.open ( path , "rb" )
			if f then
				filecontents = f:read ( "*all" )
				f:close ( )
				
				code = 200
				doc = filecontents
			else -- no such file
				code = 404
				return
			end
		else -- Want index file
			if string.sub ( path , -1 ) ~= "/" then path = path .. "/" end -- Ensure path ends in directory seperator
			for i , v in ipairs ( defaultfiles ) do
				local f , filecontents
				f = io.open ( path .. v )
				if f then
					filecontents = f:read ( "*all" )
					f:close ( )
					
					code = 200
					doc = filecontents
					break
				end
			end
			if not doc and lfs.attributes ( path , "mode" ) == "directory" and allowdirectorylistings then -- Directory listing
				doc = "<html><head><title>" .. core._NAME .. ' ' .. core._VERSION .. " Directory Listing</title></head><body><h1>Listing of " .. sfile .. "</h1><ul>"
				local t = { }
				for entry in lfs.dir ( path ) do
					if string.sub ( entry , 1 , 1 ) ~= "." then
						t [ #t + 1 ] = entry
					end
				end
				table.sort ( t )
				if sfile ~= "/" then doc = doc .. "<li><a href='" .. ".." .. "'>" .. ".." .. "</a></li>" end
				for i , v in ipairs ( t ) do
					doc = doc .. "<li><a href='" .. v .. "'>" .. v .. "</a></li>"
				end
				doc = doc .. "</ul></body></html>"
				
				code = 200
			else -- If still around at this point: forbidden to list the directory
				print ( path , doc,  lfs.attributes ( path , "mode" ) , allowdirectorylistings )
				code = 403
			end
		end
		
		hdr [ 'content-length' ]  = pathtomime ( path )
		local code , str , bytessent = httpsend ( skt , requestdetails , code , hdr , doc )
			
		-- Apache Log Format
		local apachelog = string.format ( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"', skt:getpeername ( ) , os.date ( "!%m/%b/%Y:%H:%M:%S GMT" ) , requestdetails.Path , requestdetails.Major , requestdetails.Minor , code , bytessent , ( requestdetails.headers [ "referer" ] or "-" ) , ( requestdetails.headers[ "agent" ] or "-" ) )
		print ( apachelog )
		
		return true
end

local function lompserver ( skt )
	-- Retrive HTTP header
	local found , chunk , code , request , rsize = false , 0 , false , "" , 0
	while not found do
		if chunk < 25 then
			local data = copas.receive ( skt )
			if data then
				request = request .. data .. "\r\n"
				
				local length = string.len ( data )
				if length < 1 then found = true end
				rsize = rsize + length
			else
				return false
			end
			chunk = chunk + 1
		else -- max of 25 lines, more and request could be a DOS Attack
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
			queryvars [ socket.url.unescape ( k ) ] = socket.url.unescape ( v )
		end
	end
	local headers = { } for k , v in string.gmatch ( request , "\r\n([^:]+): ([^\r\n]+)" ) do headers [ string.lower ( k ) ] = v end
	if not headers [ "host" ] then headers [ "host" ] = "default" end
	
	local requestdetails = { Method = Method , Path = Path , Major = Major , Minor = Minor , file = file , querystring = querystring , queryvars = queryvars , headers = headers }
	
	local body
	if headers [ "content-length" ] then body = copas.receive ( skt , headers [ "content-length" ] ) end
	
	if Method == "POST" then
		if file == "/LOMP" and headers [ "content-type" ] == "text/xml" then -- This is an xmlrpc command for lomp
			return xmlrpcserver ( skt , requestdetails , body )
		end
	elseif Method == "GET" then
		if file == "/BasicCMD" then
			return basiccmdserver ( skt , requestdetails , headers )
		else
			return webserver ( skt , requestdetails , body )
		end
	elseif Method == "HEAD" then	
	elseif Method == "PUT" then
	elseif Method == "DELETE" then
	elseif Method == "TRACE" then -- Send back request as body
		return httpsend ( skt , requestdetails , 200 , { [ 'content-type'] = "message/http" } , request )
	elseif Method == "OPTIONS" then	
	else
		httpsend ( skt , requestdetails , 501 , { Allow = "GET, POST" } )
		return true
	end
	
	httpsend ( skt , requestdetails , 503 )
end
function server.initiate ( host , port )
	server.server , err = socket.bind ( host , port )
	if server.server then 
		--[[copas.addserver( server , function echoHandler ( skt )
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
		end ) --]] -- Echo Handler
		copas.addserver ( server.server , lompserver )
		updatelog ( "Server started; bound to '" .. host .. "', port #" .. port , 4 ) 
		return true
	else
		return ferror ( "Server could not be started: " .. err , 0 )
	end
end
function server.step ( )
	copas.step ( )
end
