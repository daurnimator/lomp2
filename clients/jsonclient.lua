--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

require "Json"
local http = require("socket.http")
local ltn12 = require("ltn12")

function auth ( username , password )
	require"mime" -- For base64 encoding of authorisation
	local e = mime.b64 ( username .. ":" .. password )
	return "Basic " .. e
end

function cmd ( method_name , params , address , port , headers )
	address = address or "127.0.0.1"
	port = port or 5667
	headers = headers or { }
	
	local method_call = Json.Encode ( { { cmd = method_name , params = params } } )
	local sink = { }
	
	local b , c , h = http.request {
		url = "http://" .. address .. ":" .. port .. "/JSON" ;
		method = "POST" ;
		headers = { ["content-length"] = #method_call ; authentication = auth ( "lompuser" , "changeme") } ;
		sink = ltn12.sink.table ( sink ) ;
		source = ltn12.source.string ( method_call ) ;
	}
	if b == 1 then
		local r = Json.Decode ( table.concat ( sink ) ) [ 1 ]
		if r [ 1 ] then
			print ( table.serialise ( r [ 2 ] ) )
		else
			print ( "FAIL" , table.serialise ( r ) )
		end
	else
		print(b,c,h)
	end

end