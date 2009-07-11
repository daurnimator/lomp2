--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local versionstring = "Lomp Server 0.0.1" --core._NAME .. ' ' .. core._VERSION

local tsort = table.sort
local strlen , strlower , strupper , strfind , strgmatch , strformat , strgsub , strsub , strmatch = string.len , string.lower , string.upper , string.find , string.gmatch , string.format ,  string.gsub , string.sub , string.match

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "socket"
require "socket.url"
require "copas"
require "mime" -- For base64 decoding of authorisation
require "lfs"

server = { }

local apachelog = ""

local mimetypes = { }
do -- Load mime types
	local f = io.open ( "/etc/mime.types" , "r" )
	if f then -- On a unix based system, and mime types file available.
		while true do
			local line = f:read ( )
			if not line then break end
			local _ , _ , typ , name = strfind ( line , "^(.*)\t+([^\t]+)$" )
			if typ then
				for e in strgmatch ( name , "([^%s]+)" ) do
					mimetypes [ e ] = typ
				end
			end
		end
		f:close ( )
	else -- Else just load up some basic mime types
		mimetypes [ "html" ] = "text/html"
		mimetypes [ "htm" ] = "text/html"
		mimetypes [ "css" ] = "text/css"
		mimetypes [ "txt" ] = "text/plain"
		mimetypes [ "jpg" ] = "image/jpeg"
		mimetypes [ "jpeg" ] = "image/jpeg"
		mimetypes [ "gif" ] = "image/gif"
		mimetypes [ "png" ] = "image/png"
	end
end
local function pathtomime ( path )
	local mimetyp
	local _ , _ , extension = strfind ( path , "%.([^%./]+)$" ) 
	if extension then
		mimetyp = mimetypes [ extension ] or "application/octet-stream" 
	else
		mimetyp = "text/plain"
	end
	return mimetyp
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
	
local function httpdate ( time )
	--eg, "Sun, 10 Apr 2005 20:27:03 GMT"
	return os.date ( "!%a, %d %b %Y %H:%M:%S GMT" , time )
end
local function httperrorpage ( status )
	return "<html><head><title>HTTP Code " .. status .. "</title></head><body><h1>HTTP Code " .. status .. "</h1><p>" .. httpcodes [ status ] .. "</p><hr><i>Generated on " .. os.date ( ) .." by " .. versionstring .. " </i></body></html>"
end
local function httpsend ( skt , requestdetails , responsedetails )
	local status , body = responsedetails.status , responsedetails.body
	
	if type ( status ) ~= "number" or status < 100 or status > 599 then error ( "Invalid http code" ) end
	if type ( body ) ~= "string" then body = httperrorpage ( status ) end
	local sheaders = { }
	for k , v in pairs ( ( responsedetails.headers or { } ) ) do
		sheaders [ strlower ( k ) ] = v
	end

	if requestdetails.Method == "HEAD" then body = "" end
	do -- Zlib
		local ok , zlib = pcall ( require , 'zlib' )
		if ok and type ( zlib ) == "table" then 
			if strlen ( body ) > 32 then
				local acceptencoding = ( requestdetails.headers [ "accept-encoding" ] or "" ):lower ( )
				if ( strfind ( acceptencoding , "gzip" ) or strfind ( acceptencoding , "[^%w]*[^%w]" ) ) then
					local zbody = zlib.compress( body , 9, nil, 15 + 16 )
					if zbody:len ( ) < body:len() then
						local vary = ( requestdetails.headers [ 'vary' ] or 'accept-encoding' ):lower ( )
						if strfind ( vary , '[^%w]accept-encoding[^%w]' ) then
							vary = vary .. ',' .. 'accept-encoding'
						end
						sheaders [ "vary" ] = vary
						sheaders [ "content-encoding" ] = "gzip"
						body = zbody
					end
				end
			end
		else -- Don't have zlib
			--updatelog ( "Zlib missing" , 5 )
		end
	end
	do -- md5
		local ok , md5 = pcall ( require , 'md5' )
		if type ( md5 ) == "table" and md5.sumhexa then
			local bodymd5 = md5.sumhexa ( body )
			sheaders [ "content-md5" ] = bodymd5
			if strlen ( body ) > 0 then -- ETag (md5 of body)
				local etag = requestdetails.headers [ "etag" ]
				if not etag then 
					sheaders [ "etag" ] = bodymd5
				end
			end
		else -- Don't have md5 library
			--print ( "md5 library missing" )
		end
	end
	do -- If modified...
		if status >= 200 and status < 300 then
			local modifiedSince = requestdetails.headers [ 'if-modified-since' ] or 0
			local lastModified = sheaders [ 'last-modified' ] or 1
			local noneMatch = requestdetails.headers [ 'if-none-match' ] or 0
			local etag = sheaders [ 'etag' ] or 1
			
			if modifiedSince == lastModified or noneMatch == etag then
				status = 304
				httperrorpage ( status )
			end
		end
	end

	local message = "HTTP/1.1 " .. status .. " " .. httpcodes [ status ] .. "\r\n" 
	sheaders [ "date" ] = httpdate ( )
	sheaders [ "server" ] = versionstring
	sheaders [ "content-type" ] = sheaders [ "content-type" ] or "text/html"
	sheaders [ "content-length" ] = strlen ( body )
	
	for k,v in pairs ( sheaders ) do
		message = message .. k .. ": " .. v .. "\r\n"
	end
	
	message = message .. "Connection: close\r\n" -- Multiple HTTP commands not allowed, tell client to close connection
	
	message = message .. "\r\n" -- Signal end of header(s)
	message = message .. body
	
	local bytessent , err = copas.send ( skt , message )
	
	if not bytessent then
		print ( err , requestdetails.body , message )
	else
		-- Apache Log Format
		apachelog = apachelog .. strformat ( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"' , requestdetails.peer , os.date ( "!%m/%b/%Y:%H:%M:%S GMT" ) , requestdetails.Path , requestdetails.Major , requestdetails.Minor , status , bytessent , ( requestdetails.headers [ "referer" ] or "-" ) , ( requestdetails.headers[ "agent" ] or "-" ) ) .. "\n"
		--print ( "Apache Style Log: " .. apachelog )
	end
		
	return status , reasonphrase , bytessent
end
local function execute ( thread , name , parameters )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	if parameters and type ( parameters ) ~= "table" then return false end
	
	local timeout = nil
	thread:send ( timeout , "cmd" , { cmd = name , parameters = parameters } )
	
	local val , key = thread:receive ( timeout , "returncmd" )
	return unpack ( val )
end
local function getvar ( thread , name )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	
	local timeout = nil
	thread:send ( timeout , "var" , name )
	
	local val , key = thread:receive ( timeout , "returnvar" )
	local ok , err = unpack ( val )
	if ok then
		return unpack ( err )
	else
		return false , err
	end
end
local function auth ( headers )
	if config.authorisation then
		local preferred = "basic" -- Preferred method is basic auth (Only thing currently supported)
		if headers [ "authorization" ] then -- If using http authorization
			local _ , _ , AuthType , AuthString = strfind ( headers [ "authorization" ] , "([^ ]+)% +(.+)" )
			if strlower ( AuthType )  == "basic" then -- If they are trying Basic Authentication:
				local _ , _ , user , pass = strfind ( mime.unb64 ( AuthString ) , "([^:]+):(.+)" ) -- Decrypt username:password ( Sent in base64 )
				--print(AuthType,AuthString,user,password,config.username,config.password)
				-- Check credentials:
				if user == config.username and pass == config.password then
					return true
				else -- Credentials incorrect
					return false , preferred 
				end
			--elseif strlower ( AuthType ) == "digest" then 
				-- TODO: Implement digest authentication
			end
		else -- No "Authorization" header present: Other authorisation being used?
			return false , preferred 
		end
	else -- Open Access Wanted
		return true
	end
end

local function xmlrpcserver ( thread , skt , requestdetails )
	require "xmlrpc"
	local authorised , typ = auth ( requestdetails.headers )
	if not authorised then
		if typ == "basic" then
			-- Send a xml fault document
			updatelog ( "Unauthorised login blocked." , 3 , _G )
			httpsend ( skt , requestdetails , { status = 401 , headers = { [ 'WWW-Authenticate' ] = 'Basic realm="' .. versionstring .. '"' ; [ 'content-length' ] = "text/xml" } , body = xmlrpc.srvEncode ( { faultCode = 401 , faultString = httpcodes [ 401 ] } , true ) } )
			return false
		end
	else -- Authorised
		local method_name , list_params = xmlrpc.srvDecode ( requestdetails.body )
		list_params = list_params [ 1 ] -- KLUDGE: I don't know why it needs this, but it does -- maybe its so you can have multiple methodnames?? but then wtf is the previous cmd...
		
		local function depack ( t , i , j )
			i = i or 1
			if ( j and i > j ) or ( not j and t [ tostring ( i ) ] == nil ) then return end 
			return t [ tostring ( i ) ] , depack ( t , i + 1 , j )
		end
		list_params = { depack ( list_params or { } ) }
		
		local ok , result = execute ( thread , method_name , list_params )

		if ok then
			--result = table.serialise ( result ) -- MASSIVE HACK, makes it hard for non-lua xmlrpc clients - not really xmlrpc any more.
			print(result,table.serialise(result))
		end
		local body = xmlrpc.srvEncode ( result , not ok )
		print(body)
		
		httpsend ( skt , requestdetails , { status = 200 , headers = { [ 'content-length' ] = "text/xml" } , body = body } )
			
		return true
	end
end
local function basiccmdserver ( thread , skt , requestdetails )
	-- Execute action based on GET string.
	local authorised , typ = auth ( requestdetails.headers )
	if not authorised then
		if typ == "basic" then
			-- Send an xml fault document
			updatelog ( "Unauthorised login blocked." , 3 , _G )
			httpsend ( skt , requestdetails , { status = 401 , headers = { ['WWW-Authenticate'] = 'Basic realm=" ' .. versionstring .. '"' } } )
			return false
		end		
	else
		local cmd = requestdetails.queryvars [ "cmd" ]
		
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
					httpsend ( skt , requestdetails , { status = 400 } )
					return false
				end
			else break
			end
			i = i + 1
		end
		
		do
			local doc
			local function makeresponse ( ok , response )
				if ok then
					doc = "<html><head><title>Completed Command: " .. cmd .. "</title></head><body><h1>Completed Command: " .. cmd .. "</h1><h2>Results:</h2><ul>" 
					for i , v in ipairs ( response ) do
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
						doc = doc .. "<p>" .. response .. "</p>"
					end					
					doc = doc .. "</body></html>" 
					
					return 500 , doc
				end
			end
			local status , doc = makeresponse ( execute ( thread , cmd , params ) )
			local code , str , msg , bytessent = httpsend ( skt , requestdetails , { status = status , body = doc } )
			return true
		end
	end
end
local function webserver ( thread , skt , requestdetails )
		local code , doc , hdr = nil , nil , { }
		local publicdir = "."
		local allowdirectorylistings = true
		
		local defaultfiles = { "index.html" , "index.htm" }
			
		--local sfile = strgsub ( requestdetails.file , "/%.[^/]*" , "" ) -- Strip out ".." and "." of file request
		local sfile = requestdetails.file 
		
		local path = publicdir .. sfile -- Prefix with public dir path
		
		local attributes = lfs.attributes ( path )
		if strsub ( path , -1 ) ~= "/" then -- Requesting a specific path
			if not attributes then -- Path doesn't exist
				code = 404
			elseif attributes.mode == "directory" then -- Its a directory: forward client to there
				code = 301
				hdr [ "location" ] = sfile .. "/"
			elseif attributes.mode == "file" then -- Its a file: serve it up!			
				local f , filecontents
				f , err = io.open ( path , "rb" )
				if f then
					local offset 
					local length
					
					--print ( "Range: ", requestdetails.headers [ "range" ] )
					--[[do
						local s , e , r_A , r_B = strfind ( requestdetails.headers [ "range" ] , "(%d*)%s*-%s*(%d*)" )	
						if s and e then
							r_A = tonumber (r_A)
							r_B = tonumber (r_B)
							
							if r_A then
								f:seek ("set", r_A)
								if r_B then return r_B + 1 - r_A end
							else
								if r_B then f:seek ("end", - r_B) end
							end
						end
					end--]]
					
					f:seek ( "set" , offset )
					filecontents = f:read ( length or "*all" )
					f:close ( )
					
					if offset and length then -- Partial Content
						code = 206
					else -- Standard OK
						code = 200 
					end
					doc = filecontents
					
					hdr [ "content-type" ] = pathtomime ( path )
					hdr [ "last-modified" ] = httpdate ( attributes.modification )
					local mimemajor , mimeminor = strmatch ( hdr [ "content-type" ] , "([^/]+)/(.+)") 
					if mimemajor == "image" then
						hdr [ "expires" ] = httpdate ( os.time ( ) + 86400 ) -- 1 day in the future
					elseif mimeminor == "css" then
						hdr [ "expires" ] = httpdate ( os.time ( ) + 86400 ) -- 1 day in the future
					else
						hdr [ "expires" ] = httpdate ( os.time ( ) + 30 ) -- 30 seconds in the future
					end
				end
			end
		elseif attributes.mode == "directory" then -- Want index file or directory listing
			for i , v in ipairs ( defaultfiles ) do
				if lfs.attributes ( path .. v , "mode" ) == "file" then
					code = 301
					hdr [ "location" ] = sfile .. v
					break
				end
			end
			if not code and allowdirectorylistings then -- Directory listing
				doc = "<html><head><title>" .. versionstring .. " Directory Listing</title></head><body><h1>Listing of " .. sfile .. "</h1><ul>"
				local t = { }
				for entry in lfs.dir ( path ) do
					if strsub ( entry , 1 , 1 ) ~= "." then
						t [ #t + 1 ] = entry
					end
				end
				tsort ( t )
				if sfile ~= "/" then doc = doc .. "<li><a href='" .. ".." .. "'>" .. ".." .. "</a></li>" end
				for i , v in ipairs ( t ) do
					doc = doc .. "<li><a href='" .. sfile .. v .. "'>" .. v .. "</a></li>"
				end
				doc = doc .. "</ul></body></html>"
				
				code = 200
			end
		end
		if not code then -- If still around at this point: couldn't access file or forbidden to list the directory
			code = 403		
		end
		local code , str , bytessent = httpsend ( skt , requestdetails , { status = ( code or 404 ) , headers = hdr , body = doc } )
		
		return true
end
local function jsonserver ( thread , skt , requestdetails )
	require "Json"
	--print ( "Json cmd received: " , requestdetails.body )
	local hdr = { ["content-type"] = "application/json" }
	if requestdetails.Method == "POST" then
		local o = Json.Decode ( requestdetails.body )
		if type ( o ) == "table" then
			local t = { }
			local code = 200
			for i , v in ipairs ( o ) do
				if v.cmd then
					t [ i ] = { execute ( thread , v.cmd , v.params ) }
				else -- Not a command?
					code = 206
					t [ i ] = { false , "Provide a function" }
				end
			end
			--print ( "Json reply: " , Json.Encode ( t ) )
			httpsend ( skt , requestdetails , { status = code , headers = hdr , body = Json.Encode ( t ) } )

		else -- Json decoding failed
			httpsend ( skt , requestdetails , { status = 400 , headers = hdr , body = Json.Encode ( { false , "Could not decode Json" } ) } )
		end
	elseif requestdetails.Method == "GET" then 
		local t = { }
		local i = 1
		while true do
			local v = requestdetails.queryvars [ tostring ( i ) ]
			if not v then break end
			t [ i ] = getvar ( thread , v )
			i = i + 1
		end
		httpsend ( skt , requestdetails , { status = 200 , headers = hdr , body = Json.Encode ( t ) } )
	else
		-- Unsupported json method
		httpsend ( skt , requestdetails , { status = 400 , headers = hdr } )
	end
end
local function lompserver ( thread , skt )
	while true do -- Keep doing it until connection is closed.
		-- Retrive HTTP header
		local found , chunk , code , request , rsize = false , 0 , false , "" , 0
		while not found do
			if chunk < 25 then
				local data , err = copas.receive ( skt )
				if err == "closed" then return end
				if rsize <= 1 and data == "\r\n" then -- skip blank lines @ start
				elseif data then
					request = request .. data .. "\r\n"
					
					local length = strlen ( data )
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
		
		local _ , _ , Method , Path , Major , Minor = strfind ( request , "([A-Z]+) ([^ ]+) HTTP/(%d).(%d)" )
		Method = strupper ( Method )
		if not Major then return false end -- Not HTTP
		local file , querystring = strmatch ( Path , "([^%?]+)%??(.*)$" ) 	-- HTTP Reserved characters: !*'();:@&=+$,/?%#[]
																-- HTTP Unreserved characters: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~
																-- Lua reserved pattern characters: ^$()%.[]*+-?
																-- Intersection of http and lua reserved: *+$?%[]
																-- %!%*%'%(%)%;%:%@%&%=%+%$%,%/%?%%%#%[%]
		file = socket.url.unescape ( file )
		local queryvars = { }
		if querystring then
			for k, v in strgmatch( querystring , "([^=]+)=([^&]+)" ) do --"([%w%-%%%_%.%~]+)=([%w%%%-%_%.%~]+)&?") do
				queryvars [ socket.url.unescape ( k ) ] = socket.url.unescape ( v )
			end
		end
		local headers = { } for k , v in strgmatch ( request , "\r\n([^:]+): ([^\r\n]+)" ) do headers [ strlower ( k ) ] = v end
		if not headers [ "host" ] then headers [ "host" ] = "default" end
		
		local requestdetails = { Method = Method , Path = Path , Major = Major , Minor = Minor , file = file , querystring = querystring , queryvars = queryvars , headers = headers , peer = skt:getpeername ( ) }
		
		if headers [ "content-length" ] then requestdetails.body = copas.receive ( skt , headers [ "content-length" ] ) end
		
		if Method == "POST" then
			if file == "/LOMP" and headers [ "content-type" ] == "text/xml" then -- This is an xmlrpc command for lomp
				xmlrpcserver ( thread , skt , requestdetails )
			elseif file == "/JSON" then
				jsonserver ( thread , skt , requestdetails )
			else
				webserver ( thread , skt , requestdetails )
			end
		elseif Method == "GET" or Method == "HEAD" then
			if file == "/BasicCMD" then
				basiccmdserver ( thread , skt , requestdetails )
			elseif file == "/JSON" then
				jsonserver ( thread , skt , requestdetails )
			else
				webserver ( thread , skt , requestdetails )
			end
		elseif Method == "TRACE" then -- Send back request as body
			httpsend ( skt , requestdetails , 200 , { [ 'content-type'] = "message/http" } , request )
		--elseif Method == "PUT" or Method == "DELETE" or Method == "OPTIONS" then	
		else
			httpsend ( skt , requestdetails , { status = 501 , headers = { Allow = "GET, POST, HEAD" } } )
		end
		
		break
	end
end
function server.initiate ( thread , host , port )
	local srv, err
	srv , err = socket.bind ( host , port , 100 )
	if srv then 
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
		copas.addserver ( srv , function ( skt ) return lompserver ( thread , skt ) end )
		updatelog ( "Server started; bound to '" .. host .. "', port #" .. port , 4 , _G ) 
		return true
	else
		return ferror ( "Server could not be started: " .. err , 0 )
	end
end
function server.step ( )
	copas.step ( )
end

server.initiate ( ... )
while true do
	server.step ( )
end
