package.path = package.path .. ";../libs/?.lua"

local xmlrpc = require ( "xmlrpc" )
local socket = require ( "socket" )

function auth ( username , password )
	require"mime" -- For base64 encoding of authorisation
	local e = mime.b64 ( username .. ":" .. password )
	return "Basic " .. e
end

function cmd ( method_name , params , address , port , headers )
	address = address or "127.0.0.1"
	port = port or 5667
	headers = headers or { }
	
	local method_call = xmlrpc.clEncode ( method_name, params )
	--print(method_call)
	
	local client , err = socket.connect ( address , port )
	if not client then print ( "Could not connect: " .. err ) return false end
	local serverpath = "/LOMP"
	local str = "POST " .. serverpath .. " HTTP/1.0\r\n"
	str = str .. "Host: " .. address .. ":" .. port .. "\r\n"
	str = str .. "Content-Length: " .. string.len ( method_call ) .. "\r\n"
	str = str .. "Content-Type: text/xml\r\n"
	str = str .. "User-Agent: CLOMP 0.0.1\r\n"
	for k,v in pairs ( headers ) do
		str = str .. k .. ": " .. v .. "\r\n"
	end
	str = str .. "\r\n"
	str = str .. method_call
	client:send ( str )
	
	local r = ""
	while not string.find( r , "\r\n\r\n" ) do
		local d = client:receive ( ) .. "\r\n"
		if d then r = r .. d end
	end
	print ( r )
	local _ , _ , major , minor , code , str = string.find ( r , "HTTP/(%d).(%d)%s+(%d%d%d)%s+([A-Z]+)" )
	code = tonumber ( code )
	local rheaders = {} 
	for k, v in string.gmatch ( r , "\r\n([^:]+): ([^\r\n]+)" ) do rheaders [ string.lower ( k ) ] = v end
	
	if rheaders [ "content-length" ] then body = client:receive ( rheaders [ "content-length" ] ) end
	
	if code == 401 then -- Don't have authorisation - Need to authenticate
		local _ , _ , authtype , realm = string.find ( rheaders [ "www-authenticate" ] , "(%w+)%s+realm=[\'\"]?([^,\r]+)" )
		print ( authtype , realm )
		headers [ "Authorization" ] = auth ( "lompuser" , "changeme" ) -- Username/password
		return cmd ( method_name , params , address , port , headers )
	end	
	
	local ok , response , faultcode = xmlrpc.clDecode ( body )
	if ok then
		
		return true
	else
		error ( "Code: " .. faultcode .. "\t Message: " .. response )
		return false
	end
	
	print(body)
end
