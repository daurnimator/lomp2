--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

package.path = package.path .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/lib/lua/5.1/?.lua;/usr/lib/lua/5.1/?/init.lua;./libs/?.lua;./libs/?/init.lua;"
package.cpath = package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/lib/lua/5.1/loadall.so;./libs/?.so"

local tonumber , getmetatable , setmetatable = tonumber , getmetatable , setmetatable
local tblconcat = table.concat
local error = error
local print = print
pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

local socket = require "socket"
local Json = require "Json"

module ( "lompclient" )

local function send ( ob , data )
	local client = getmetatable ( ob ).client
	if not client then error ( "Client not connected" ) end

	client:send ( data .. "\n" )
	return
end
local function receive ( ob )
	local client = getmetatable ( ob ).client
	if not client then error ( "Client not connected" ) end
	
	local line , err = client:receive ( "*l" )
	if not line then
		if err == "timeout" then return nil
		else return false , err end
	end
	
	local s , e , statuscode = line:find ( "^(%d+)%s*" )
	statuscode = tonumber ( statuscode )
	if statuscode >= 0 then
		local s , e , length , alreadyread = line:find ( "(%d+)%s*(.*)" , e + 1 )
		if not length or length == "0" then return statuscode end
		
		length = tonumber ( length )
		
		local lefttoread = length - #alreadyread
		local t = { ( alreadyread or "" ) }
		repeat
			local newdata = client:receive ( lefttoread )
			t [ #t + 1 ] = newdata
			lefttoread = lefttoread - # ( newdata or "" )
		until lefttoread == 0
		
		local decoded = Json.Decode ( tblconcat ( t , "\n" ) )
		return statuscode , nil , decoded
	elseif statuscode < 0 then
		local s , e , var , length , alreadyread = line:find ( "(%S+)%s+(%d+)%s*(.*)" , e + 1 )
		local data = ( alreadyread or "" ) .. client:receive ( length - # ( alreadyread or "" ) )
		local decoded = Json.Decode ( data )
		return statuscode , var , decoded
	else
		return false , "Not valid"
	end
end

function connect ( address , port )
	local ob , err = socket.connect ( address , port )
	if not ob then return false , err end
	ob:settimeout ( 0.03 )
	
	ob:send ( "LOMP 1\n" )

	local client = setmetatable ( { } , { client = ob , __index = { receive = receive , send = send } } ) 

	local code , str
	repeat 
		code , str = receive ( client )
		if code == false then error ( str ) end
	until code ~= nil
	if code ~= 0 then error ( "Not a lomp server" ) end
	
	return client
end

return _M
