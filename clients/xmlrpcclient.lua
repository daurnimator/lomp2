--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

local xmlrpc = require ( "xmlrpc" )
local socket = require ( "socket" )

function auth ( username , password )
	require"mime" -- For base64 encoding of authorisation
	local e = mime.b64 ( username .. ":" .. password )
	return "Basic " .. e
end

function cmd ( method_name , params , address , port , headers )
	address = address or "127.0.0.1"
	port = port or 5666
	headers = headers or { }
	
	local method_call = xmlrpc.clEncode ( method_name, params )
	
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
		print(ok,response,faultcode,body)
		return response
		--response = response or lxp.lom.parse(b)[2][2][1][1] -- MASSIVE HACK
		--return loadstring ( "return {" .. response  .. "}") ( )
	else
		error ( "Code: " .. faultcode .. "\t Message: " .. response )
		return false
	end
end

function pt (t)
	for k , v in pairs ( t ) do
		print ( k , v )
	end
end

function b ( f )
	cmd("core.setsoftqueueplaylist",{0})
	--cmd("core.localfileio.addfolder" , { ( f or "/media/temp/Done Torrents/ACDC - Highway To Hell (1979) [FLAC]" ) ,0,1,"true"})
	--cmd("core.playback.play")
end

function q ( num )
	return table.serialise ( cmd("getvar",{"queue[" .. ( num or 0 )  .. "].details"})[1])
end
