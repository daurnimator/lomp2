#! /usr/bin/env lua
--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local lompclient = require "clients.eventserverlib"
local Json = require "Json"

local client = lompclient.connect ( os.getenv ( "LOMP_HOST" ) or "localhost" , os.getenv ( "LOMP_PORT" ) or 5667 )

local function basiccmd ( cmd , ... )
	local args = { ... }
	for i = 1 , select ( "#" , ... ) do
		local a = args [ i ]
		if a == nil then args [ i ] = Json.null
		elseif tonumber ( a ) then args [ i ] = tonumber ( a )
		end
	end
	local encoded = Json.Encode ( args )
	client:send ( table.concat ( { "CMD" , cmd , encoded } , " " ) )
	while true do
		local code , str , data =  client:receive ( )
		if code == nil then
		elseif code == 0 then 
			if data [ 1 ] then
				print ( table.serialise ( data ) )
			else
				print ( "Error in lomp server: " .. data [ 2 ] )
			end
			return
		elseif code < 0 then
		else error ( lompclient.codes [ code ] ) end
	end
end

local translate
translate = {
	play = function ( ... )
		return basiccmd ( "core.playback.play" , ... )
	end ;
	togglepause = function ( ... )
		return basiccmd ( "core.playback.togglepause" , ... )
	end ;
	pause = function ( ... )
		return basiccmd ( "core.playback.pause" , ... )
	end ;
	unpause = function ( ... )
		return basiccmd ( "core.playback.unpause" , ... )
	end ;
	next = function ( ... )
		return basiccmd ( "core.playback.forward" , ... )
	end ;
	previous = function ( ... )
		return basiccmd ( "core.playback.backward" , ... )
	end ;
	seek = function ( ... )
		return basiccmd ( "core.playback.seek" , ... )
	end ;
	stop = function ( ... )
		return basiccmd ( "core.playback.stop" , ... )
	end ;
	quit = function ( ... )
		return basiccmd ( "core.quit" , ... )
	end ;
	manual = function ( )
		local waiting
		while true do
			if not waiting then
				local line = io.read ( "*l" )
				if line then
					client:send ( line )
					waiting = true
				end
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
	end ;
	help = function ( ... )
		if ( ... ) == nil then
			local t = { }
			for k , v in pairs ( translate ) do 
				t [ #t + 1 ] = k
			end
			table.sort ( t )
			print ( "Valid functions are:" )
			print ( table.concat ( t , "\n" ) )
		end
	end ;
}

local func = translate [ arg [ 1 ] ]
if func then
	func ( select ( 2 , ... ) )
	print()
	os.exit ( 0 )
else
	print ( "Invalid command, see: '" , arg [ 0 ]  .. " help'" )
	print()
	os.exit ( 1 )
end
