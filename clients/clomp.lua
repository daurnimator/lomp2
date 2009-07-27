--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
local lompclient = require "clients.eventserverlib"

local client = lompclient.connect ( "localhost" , 5667 )

local waiting
while true do
	if not waiting then
		local line = io.read ( "*l" )
	
		if line then
			client:send ( line )
		end
		waiting = true
	end
	
	local code , str , data =  client:receive ( )
	if code == false then
		error ( str )
	elseif code == nil then
	elseif code >= 0 then
		waiting = false
		if code == 0 then
			print ( "Success! " .. tostring ( data ) )
		else
			print( "Fail! " .. code .. ": " .. tostring ( data ) )
		end
	else
		print ( code , str , data )
	end
end
