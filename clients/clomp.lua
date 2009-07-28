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

local function basiccmd ( cmd ) return function ( ... )
	local args = { ... }
	for i = 1 , select ( "#" , ... ) do
		local a = args [ i ]
		if a == nil then args [ i ] = Json.null
		elseif a == "false" then args [ i ] = false
		elseif a == "true" then args [ i ] = true
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
end end

local translate
translate = {
	play = { basiccmd ( "core.playback.play" ) , "" , "Start playing" } ;
	togglepause = { basiccmd ( "core.playback.togglepause" ) , "" , "Toggles between paused and playing" } ;
	pause = { basiccmd ( "core.playback.pause" ) , "" , "Pause" } ;
	unpause = { basiccmd ( "core.playback.unpause" ) , "" , "Start playing again if in paused state" } ;
	next = { basiccmd ( "core.playback.forward" ) , "" , "Play the next song in the queue" } ;
	previous = { basiccmd ( "core.playback.backward" ) , "" , "Play the last song that was played, the current song is placed in the hardqueue" } ;
	seek = { basiccmd ( "core.playback.seek" ) , "<offset> [<relative?> [<percent?>]]" , "Seeks the current song to the given offset, if relative is true, the offset is from the current position, if percent is true, the offset is given as a percentage of the current song's length" } ;
	stop = { basiccmd ( "core.playback.stop" ) , "" , "Stops the current song" } ;
	addfile = { basiccmd ( "core.localfileio.addfile" ) , " <path> <playlist> [<position>]" , "add the song at the path given (on the server) to the playlist specified, in the position given (position defaults to the end of the playlist)" } ;
	addfolder = { basiccmd ( "core.localfileio.addfolder" ) , " <path> <playlist> [<position> [<recurse>]]" , "add a folder to a playlist starting at given position, recursing to given number of levels, or true for infinite (default is no recursion)" } ;
	quit = { basiccmd ( "core.quit" ) , "" , "makes the server quit" } ;
	manual = { function ( )
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
	end , "" , "opens a telnet like session with the server" } ;
	help = { function ( ... )
		local t , maxlen = { } , 0
		if select ( "#" , ... ) == 0 then
			for k , v in pairs ( translate ) do
				local params , helptxt = v [ 2 ] , v [ 3 ]
				if ( #k + #params ) > maxlen then maxlen = #k + #params end
				t [ #t + 1 ] = { k , params , helptxt }
			end
			print ( "Valid functions are:" )
		else
			for i , v in ipairs ( { ... } ) do
				local f = translate [ v ]
				if f then
					local params , helptxt = f [ 2 ] , f [ 3 ]
					if ( #v + #params ) > maxlen then maxlen = #v + #params end
					t [ #t + 1 ] = { v , params , helptxt }
				end
			end
		end
		
		table.sort ( t , function ( a , b ) return a[1] < b[1] end )
		for k , v in ipairs ( t ) do
			io.write ( v [ 1 ] , " " , v [ 2 ] , string.rep ( " " , maxlen - ( #v [ 1 ] + #v [ 2 ] ) ) , " : " , v [ 3 ] , "\n" )
		end
	end , "" , "displays help" } ;
}

local ret = translate [ arg [ 1 ] ]
if ret then
	ret [ 1 ] ( select ( 2 , ... ) )
	print ( )
	os.exit ( 0 )
else
	io.write ( "Invalid command, see: '" , arg [ 0 ]  , " help'" , "\n\n" )
	os.exit ( 1 )
end
