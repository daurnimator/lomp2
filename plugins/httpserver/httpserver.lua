--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local dir = dir -- Grab vars needed
local lomp = lomp

local updatelog , ferror = lomp.updatelog , lomp.ferror

local tblsort , tblconcat = table.sort , table.concat
local strfind , strgmatch , strformat , strgsub , strsub = string.find , string.gmatch , string.format ,  string.gsub , string.sub
local osdate , ostime = os.date , os.time
local ioopen = io.open
local pcall , unpack , require , loadfile , pairs , ipairs , setfenv , setmetatable , tonumber , tostring , type = pcall , unpack , require , loadfile , pairs , ipairs , setfenv , setmetatable , tonumber , tostring , type

local p , ts = print , table.serialise

module ( "httpserver" )

_NAME = "Lomp HTTP Server"
_VERSION = "0.1"

local versionstring =  _NAME .. " " .. _VERSION --core._NAME .. ' ' .. core._VERSION

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
local url = require "socket.url"
local server = require "server"
local mime = require "mime" -- For base64 decoding of authorisation
local lfs = require "lfs"

function loadconfig ( )
	local httpconfig = { }
	local configfunc , err = loadfile ( dir .. "config" )
	if not configfunc then return ferror ( "Could not load httpserver config: " .. err ) end
	
	setfenv ( configfunc , httpconfig )  ( ) -- Load config

	if httpconfig.address == nil then
		updatelog ( 'No httpserver binding address defined, using "*"' , 2 )
		httpconfig.address = "*"
	end
	if type ( httpconfig.address ) ~= "string" then
		updatelog ( 'Invalid httpserver binding address defined' , 0 )
	end

	if type ( httpconfig.port ) ~= "number" or httpconfig.port < 0 or httpconfig.port > 65536  then
		updatelog ( 'Invalid or no httpserver port defined, using 5667' , 2 )
		httpconfig.port = 5666
	end
	if httpconfig.authorisation ~= true then
		httpconfig.authorisation = false
		updatelog ( 'HTTP authorisation disabled' , 2 )
	else -- If authorisation is enabled:
		if type ( httpconfig.username ) ~= "string" then
			updatelog ( 'Invalid or no httpserver username defined, using "lompuser"' , 2 )
			httpconfig.username = "lompuser"
		end
		if type ( httpconfig.password ) ~= "string" then 
			updatelog ( 'Invalid or no httpserver password defined, disabling authorisation' , 2 )
			httpconfig.password = nil
			httpconfig.authorisation = false
		end
	end
	
	return httpconfig
end

local httpconfig = loadconfig ( )

local mimetypes = setmetatable ( { } , { __index = function ( ) return "application/octet-stream" end } )
do -- Load mime types
	local f = ioopen ( "/etc/mime.types" , "r" )
	if f then -- On a unix based system, and mime types file available.
		while true do
			local line = f:read ( )
			if not line then break
			elseif line:sub ( 1 , 1 ) == "#" then
				-- Is a comment
			else
				local typ , name = line:match ( "^(%S+)%s+(.+)$" )
				if typ then
					for e in strgmatch ( name , "%S+" ) do
						mimetypes [ e ] = typ
					end
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
	local extension = path:match ( "%.?([^%./]+)$" )
	local mimetyp
	if extension then
		mimetyp = mimetypes [ extension ] 
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
	return osdate ( "!%a, %d %b %Y %H:%M:%S GMT" , time )
end

local function httperrorpage ( status )
	return "<html><head><title>HTTP Code " .. status .. "</title></head><body><h1>HTTP Code " .. status .. "</h1><p>" .. httpcodes [ status ] .. "</p><hr><i>Generated on " .. osdate ( ) .." by " .. versionstring .. " </i></body></html>"
end

local conns = { }

local function httpsend ( conn , session , responsedetails )
	local status , body = responsedetails.status , responsedetails.body
	
	if type ( status ) ~= "number" or status < 100 or status > 599 then error ( "Invalid http code" ) end
	if type ( body ) ~= "string" then body = httperrorpage ( status ) end
	local sheaders = { }
	for k , v in pairs ( responsedetails.headers or { } ) do
		sheaders [ k:lower ( ) ] = v
	end

	if session.Method == "HEAD" then body = "" end
	do -- Zlib
		local ok , zlib = pcall ( require , 'zlib' )
		if ok and type ( zlib ) == "table" then 
			if #body > 32 then
				local acceptencoding = ( session.headers [ "accept-encoding" ] or "" ):lower ( )
				if ( strfind ( acceptencoding , "gzip" ) or strfind ( acceptencoding , "[^%w]*[^%w]" ) ) then
					local zbody = zlib.compress ( body , 9 , nil , 15 + 16 )
					if #zbody < #body then -- If gzip'd body is shorter than uncompressed body
						local vary = ( session.headers [ 'vary' ] or 'accept-encoding' ):lower ( )
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
			if #body > 0 then -- ETag (md5 of body)
				local etag = session.headers [ "etag" ]
				if not etag then 
					sheaders [ "etag" ] = bodymd5
				end
			end
		else -- Don't have md5 library
			--updatelog ( "md5 library missing" , 5 )
		end
	end
	do -- If modified...
		if status >= 200 and status < 300 then
			local modifiedSince = session.headers [ 'if-modified-since' ] or 0
			local lastModified = sheaders [ 'last-modified' ] or 1
			local noneMatch = session.headers [ 'if-none-match' ] or 0
			local etag = sheaders [ 'etag' ] or 1
			
			if modifiedSince == lastModified or noneMatch == etag then
				status = 304
				httperrorpage ( status )
			end
		end
	end

	local message = { "HTTP/" .. session.Major .. "." .. session.Minor .." " .. status .. " " .. httpcodes [ status ] }
	local msgcount = 1
	
	sheaders [ "date" ] = httpdate ( )
	sheaders [ "server" ] = versionstring
	sheaders [ "content-type" ] = sheaders [ "content-type" ] or "text/html"
	sheaders [ "content-length" ] = #body
	
	local requestconnection = session.headers [ "connection" ]
	if requestconnection then
		requestconnection = requestconnection:lower ( )
		if requestconnection == "close" then
			sheaders [ "connection" ] = "Close"
		elseif requestconnection == "keep-alive" then
			sheaders [ "connection" ] = "Keep-Alive"
		end
	elseif session.Major == "1" and session.Minor == "0" then
		sheaders [ "connection" ] = "Close"
	end
	
	for k,v in pairs ( sheaders ) do
		msgcount = msgcount + 1
		message [ msgcount ] = k .. ": " .. v
	end
	
	message [ msgcount + 1 ] = "" -- Signal end of header(s)
	message [ msgcount + 2 ] = body
	
	conn.write ( tblconcat ( message , "\r\n" ) )
	
	-- Apache Log Format
	local apachelog = strformat ( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"' , session.peer , osdate ( "!%m/%b/%Y:%H:%M:%S GMT" ) , session.Path , session.Major , session.Minor , status , #message , ( session.headers [ "referer" ] or "-" ) , ( session.headers [ "agent" ] or "-" ) )
	updatelog ( "HTTP Server: " .. apachelog , 5 )
	
	if sheaders [ "connection" ] == "Close" then conn.close ( ) end
	conns [ conn ] = nil -- Reset connection
	
	return status , reasonphrase
end

local function execute ( name , ... )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	if parameters and type ( parameters ) ~= "table" then return false end
	
	local function interpret ( ok , ... )
		if not ok then return false , ( ... )
		else return ok , { ... } end
	end
	
	return interpret ( lomp.cmd ( name , ... ) )
end

local function getvar ( name )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	
	local ok , results = lomp.var ( name )
	if ok then 
		return results
	else
		return nil , results
	end
end

local function auth ( headers )
	if httpconfig.authorisation then
		if headers [ "authorization" ] then -- If using http authorization
			local AuthType , AuthString = headers [ "authorization" ]:match ( "(%S+)%s+(.*)%s*" )
			if AuthType then
				AuthType = AuthType:lower ( )
				if AuthType == "basic" then -- If they are trying Basic Authentication:
					local user , pass = mime.unb64 ( AuthString ):match ( "([^:]+):(.+)" ) -- Decrypt username:password ( Sent in base64 )
					if user == httpconfig.username and pass == httpconfig.password then
						return true
					end
				elseif AuthType == "digest" then 
					-- TODO: implement digest authentication
				end
			end
		end
		return false , { ['WWW-Authenticate'] = 'Basic realm=" ' .. versionstring .. '"' } 
	else -- Open Access Wanted
		return true
	end
end

local function xmlrpcserver ( skt , session )
	local xmlrpc = require "xmlrpc"
	local authorised , headers = auth ( session.headers )
	if not authorised then
		if typ == "basic" then
			-- Send a xml fault document
			updatelog ( "Unauthorised login blocked." , 3 )
			headers [ 'content-length' ] = "text/xml"
			httpsend ( skt , session , { status = 401 , headers = headers , body = xmlrpc.srvEncode ( { faultCode = 401 , faultString = httpcodes [ 401 ] } , true ) } )
			return false
		end
	else -- Authorised
		local method_name , list_params = xmlrpc.srvDecode ( session.body )
		list_params = list_params [ 1 ] -- KLUDGE: I don't know why it needs this, but it does -- maybe its so you can have multiple methodnames?? but then wtf is the previous cmd...
		
		local function depack ( t , i , j ) -- like unpack but uses a string indexed array (rather than number)
			if not t then return end
			i = i or 1
			if ( j and i > j ) or ( not j and t [ tostring ( i ) ] == nil ) then return end 
			return t [ tostring ( i ) ] , depack ( t , i + 1 , j )
		end
		
		local ok , result = execute ( method_name , depack ( list_params ) )

		if ok then
			--result = table.serialise ( result ) -- MASSIVE HACK, makes it hard for non-lua xmlrpc clients - not really xmlrpc any more.
			--print(result,table.serialise(result))
		end
		local body = xmlrpc.srvEncode ( result , not ok )
		--print(body)
		
		httpsend ( skt , session , { status = 200 , headers = { [ 'content-length' ] = "text/xml" } , body = body } )
			
		return true
	end
end

local function basiccmdserver ( skt , session )
	-- Execute action based on GET string.
	local authorised , headers = auth ( session.headers )
	if not authorised then
		if typ == "basic" then
			-- Send an xml fault document
			updatelog ( "Unauthorised login blocked." , 3 )
			httpsend ( skt , session , { status = 401 , headers = headers } )
			return false
		end		
	else
		local cmd = session.queryvars [ "cmd" ]
		
		local i = 1
		local params = { }
		while true do
			if session.queryvars [ tostring ( i ) ] then
				local v = session.queryvars [ tostring ( i ) ]
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
					httpsend ( skt , session , { status = 400 } )
					return false
				end
			else
				break
			end
			i = i + 1
		end
		
		do
			local function makeresponse ( ok , response )
				local doc
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
					doc = "<html><head><title>Failure in: " .. cmd .. "</title></head><body><h1>Failure in: " .. cmd .. "</h1><h2>Error:</h2><p>" .. response .. "</p></body></html>" 
					
					return 500 , doc
				end
			end
			local status , doc = makeresponse ( execute ( cmd , unpack ( params ) ) )
			local code , str , msg , bytessent = httpsend ( skt , session , { status = status , body = doc } )
			return true
		end
	end
end
local function webserver ( skt , session )
	local code , doc , hdr = nil , nil , { }
	local publicdir = "."
	local allowdirectorylistings = true
	
	local defaultfiles = { "index.html" , "index.htm" }
	
	local sfile = session.file
	repeat
		local reps
		sfile , reps = sfile:gsub ( "([^/]+)/%.%./" , "")
	until reps == 0
	
	local path = publicdir .. sfile -- Prefix with public dir path
	local attributes = lfs.attributes ( path )
		
	if sfile:find ( "^%.%." ) then
		code = 403
	elseif strsub ( path , -1 ) ~= "/" then -- Requesting a specific path
		if not attributes then -- Path doesn't exist
			code = 404
		elseif attributes.mode == "directory" then -- Its a directory: forward client to there
			code = 301
			hdr [ "location" ] = sfile .. "/"
		elseif attributes.mode == "file" then -- Its a file: serve it up!			
			local f
			f , err = ioopen ( path , "rb" )
			if f then					
				doc = f:read ( "*a" )
				f:close ( )
				
				if offset and length then -- Partial Content
					code = 206
				else -- Standard OK
					code = 200 
				end
				
				hdr [ "content-type" ] = pathtomime ( path )
				hdr [ "last-modified" ] = httpdate ( attributes.modification )
				local mimemajor , mimeminor = hdr [ "content-type" ]:match ( "([^/]+)/(.+)" )
				if mimemajor == "image" then
					hdr [ "expires" ] = httpdate ( ostime ( ) + 86400 ) -- 1 day in the future
				elseif mimeminor == "css" then
					hdr [ "expires" ] = httpdate ( ostime ( ) + 86400 ) -- 1 day in the future
				else
					hdr [ "expires" ] = httpdate ( ostime ( ) + 30 ) -- 30 seconds in the future
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
			local doct = { "<html><head><title>" .. versionstring .. " Directory Listing</title></head><body><h1>Listing of " .. sfile .. "</h1><ul>" }
			local t = { }
			for entry in lfs.dir ( path ) do
				if entry:sub ( 1 , 1 ) ~= "." then
					t [ #t + 1 ] = entry
				end
			end
			tblsort ( t )
			if sfile ~= "/" then doct [ #doct + 1 ] = "<li><a href='" .. ".." .. "'>" .. ".." .. "</a></li>" end
			for i , v in ipairs ( t ) do
				doct [ #doct + 1 ] = "<li><a href='" .. sfile .. v .. "'>" .. v .. "</a></li>"
			end
			doct [ #doct + 1 ] = "</ul></body></html>"
			
			doc = tblconcat ( doct )
			
			code = 200
		else
			code =  403
		end
	end
	local code , str , bytessent = httpsend ( skt , session , { status = ( code or 404 ) , headers = hdr , body = doc } )
	
	return true
end

local function jsonserver ( skt , session )
	local Json = require "Json"
	--print ( "Json cmd received: " , session.body )
	local hdr = { [ "content-type" ] = "application/json" }
	if session.Method == "POST" then
		local o = Json.Decode ( session.body )
		if type ( o ) == "table" then
			local t = { }
			local code = 200
			for i , v in ipairs ( o ) do
				if v.cmd then
					if v.params and type ( v.params ) == "table" then
						t [ i ] = { execute ( v.cmd , unpack ( v.params ) ) }
					else
						t [ i ] = { execute ( v.cmd ) }
					end
				else -- Not a command?
					code = 206
					t [ i ] = { false , "Provide a function" }
				end
			end
			--print ( "Json reply: " , Json.Encode ( t ) )
			httpsend ( skt , session , { status = code , headers = hdr , body = Json.Encode ( t ) } )

		else -- Json decoding failed
			httpsend ( skt , session , { status = 400 , headers = hdr , body = Json.Encode ( { false , "Could not decode Json" } ) } )
		end
	elseif session.Method == "GET" then 
		local t = { }
		local i = 1
		while true do
			local v = session.queryvars [ tostring ( i ) ]
			if not v then break end
			local result , err = getvar ( v )
			if err then
				t [ i ] = { false , err }
			elseif result == nil then
				t [ i ] = { true , Json.Null } -- NOTE: Should this be { false , "No value" } ??
			else
				t [ i ] = { true , result }
			end
			i = i + 1
		end
		--print ( "Json reply: " , Json.Encode ( t ) )
		httpsend ( skt , session , { status = 200 , headers = hdr , body = Json.Encode ( t ) } )
	else
		-- Unsupported json method
		httpsend ( skt , session , { status = 400 , headers = hdr } )
	end
end

local function httpserver ( conn , data, err )
	if not data then return end
	local session = conns [ conn ]
	if not session then
		if data == "\r" then return end
		
		session = { body = { } , gotrequest = false , needbody = false , headers = { } }
		session.Method , session.Path , session.Major , session.Minor = data:match ( "(%u+)%s+(%S+)%sHTTP/(%d).(%d)" )
		if not session.Method then conn.close ( ) return end
		session.Method = session.Method:upper ( )
		
		local file , querystring = session.Path:match ( "([^%?]+)%??(.*)$" ) 	-- HTTP Reserved characters: !*'();:@&=+$,/?%#[]
																-- HTTP Unreserved characters: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~
																-- Lua reserved pattern characters: ^$()%.[]*+-?
																-- Intersection of http and lua reserved: *+$?%[]
																-- %!%*%'%(%)%;%:%@%&%=%+%$%,%/%?%%%#%[%]
		session.file = url.unescape ( file )
		local queryvars = { }
		if querystring then
			for k, v in strgmatch ( querystring , "([^=]+)=([^&]+)&?" ) do --"([%w%-%%%_%.%~]+)=([%w%%%-%_%.%~]+)&?") do
				queryvars [ url.unescape ( k ) ] = url.unescape ( v )
			end
		end
		
		session.querystring , session.queryvars , session.peer = querystring , queryvars , conn.socket ( ):getpeername ( )
		
		conns [ conn ] = session
	elseif not session.gotrequest then
		if data ~= "" then -- \r\n is already stripped, look for an empty line to signify end of headers
			local key , val = data:match ( "([^:]+):%s*(.*)" )
			if key then
				key = key:lower ( )
				session.lastheader = key
				session.headers [ key ] = val
			else
				session.headers [ session.lastheader ] = session.headers [ session.lastheader ] .. "\n" .. data
			end
		else
			session.gotrequest = true
			
			if not session.headers [ "host" ] then session.headers [ "host" ] = "default" end
			
			if session.headers [ "content-length" ] then session.needbody = true end
		end
	elseif session.needbody then
		local bodylen = tonumber ( session.headers [ "content-length" ] )
		
		session.body [ #session.body + 1 ] = data
		local body = tblconcat ( session.body )
		if # ( body ) < bodylen then return end
		session.body = body
		session.needbody = false
	end
	
	if session and session.gotrequest and not session.needbody then
		if session.Method == "POST" then
			if session.file == "/LOMP" and session.headers [ "content-type" ] == "text/xml" then -- This is an xmlrpc command for lomp
				xmlrpcserver ( conn , session )
			elseif session.file == "/JSON" then
				jsonserver ( conn , session )
			else
				webserver ( conn , session )
			end
		elseif session.Method == "GET" or session.Method == "HEAD" then
			if session.file == "/BasicCMD" then
				basiccmdserver ( conn , session )
			elseif session.file == "/JSON" then
				jsonserver ( conn , session )
			else
				webserver ( conn , session )
			end
		--elseif session.Method == "TRACE" then -- Send back request as body
		--	httpsend ( conn , session , { status = 200 , headers = { [ 'content-type'] = "message/http" } , body = session.request )
		--elseif Method == "PUT" or Method == "DELETE" or Method == "OPTIONS" then	
		else
			httpsend ( conn , session , { status = 501 , headers = { Allow = "GET, POST, HEAD" } } )
		end
	end
end

function initiate ( host , port )
	server.addserver ( {
			incoming = httpserver ;
			disconnect = function ( conn , err )
				conns [ conn ] = nil
			end ;
		} , port , host , "*l" )
	updatelog ( "HTTP Server started; bound to '" .. host .. "', port #" .. port , 4 )
end

initiate ( httpconfig.address , httpconfig.port )
lomp.addstep ( server.step )

return _NAME , _VERSION
