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

local client

local function basiccmd ( cmd ) return function ( ... )
	local q = client:CMD ( cmd , function ( ... )
		local data = { ... }
		if data [ 1 ] then
			print ( "Result(s):" )
			for i , v in ipairs ( data ) do
				if type ( v ) == "table" then
					print ( table.serialise ( v ) )
				else
					print ( v )
				end
			end
		else
			print ( "Error in lomp server: " .. data [ 2 ] )
		end
	end , ... )
	
	repeat
		local ret = client:step ( )
	until ret == q
end end

local translate
translate = {
	setplaylist = 	{ func = basiccmd ( "core.setsoftqueueplaylist" ) , params = "<playlist number>" , help = "sets which playlist is the soft queue" } ;
	setploffset = 	{ func = basiccmd ( "core.setploffset" ) , params = "[<offset>]" , help = "sets what number item the soft queue is up to in the softqueueplaylist, default is 0" } ;
	loop = 		{ func = basiccmd ( "core.loop" ) , params = "<loop?>" , help = "enables/disables looping the soft queue" } ;
	["repeat"] = 	{ func = basiccmd ( "core.repeat" ) , params = "<repeat?>" , help = "enables/disables repeating the soft queue playlist" } ;
	reloadlibrary = 	{ func = basiccmd ( "core.reloadlibrary" ) , params = "" , help = "reloads the library (with directories set in config file)" } ;
	quit = 		{ func = basiccmd ( "core.quit" ) , params = "" , help = "makes the server quit" } ;
	play = 		{ func = basiccmd ( "core.playback.play" ) , params = "[<offset>[ <percent?>]]" , help = "Start current song playing, at the given offset (seconds or percent if 2nd argument is true)" } ;
	togglepause = 	{ func = basiccmd ( "core.playback.togglepause" ) , params = "" , help = "Toggles between paused and playing" } ;
	pause = 		{ func = basiccmd ( "core.playback.pause" ) , params = "" , help = "Pause" } ;
	unpause = 	{ func = basiccmd ( "core.playback.unpause" ) , params = "" , help = "Start playing again if in paused state" } ;
	goto =		{ func = basiccmd ( "core.playback.goto" ) , params = "<queue index>" , help = "Move forward through queue until the given index is the current song" } ;
	forward = 	{ func = basiccmd ( "core.playback.forward" ) , params = "" , help = "Play the next song in the queue" } ;
	backward = 	{ func = basiccmd ( "core.playback.backward" ) , params = "" , help = "Play the last song that was played, the current song is placed in the hardqueue" } ;
	seek = 		{ func = basiccmd ( "core.playback.seek" ) , params = "<offset>[ <relative?>[ <percent?>]]" , help = "Seeks the current song to the given offset, if relative is true, the offset is from the current position, if percent is true, the offset is given as a percentage of the current song's length" } ;
	stop = 		{ func = basiccmd ( "core.playback.stop" ) , params = "" , help = "Stops the current song" } ;
	newpl = 		{ func = basiccmd ( "core.playlist.new" ) , params = "<name>" , help = "Create a new playlist with the given name, returns it's playlist number" } ;
	deletepl = 	{ func = basiccmd ( "core.playlist.delete" ) , params = "<playlist number>" , help = "Deletes the playlist with the given playlist number" } ;
	clearpl =		{ func = basiccmd ( "core.playlist.clear" ) , params = "<playlist number>" , help = "Clears the playlist with the given playlist number" } ;
	renamepl = 	{ func = basiccmd ( "core.playlist.rename" ) , params = "<playlist number> <new name>" , help = "Renames the playlist with the given playlist number to the given name" } ;
	randomisepl =	{ func = basiccmd ( "core.playlist.randomise" ) , params = "<playlist number>" , help = "Randomise the playlist with the given playlist number" } ;
	copyitem = 	{ func = basiccmd ( "core.item.copytoplaylist" ) , params = "<old playlist number> <old position> <new playlist number> [<new position>]" , help = "Copies the song in given old position in old playlist to the new playlist in the given position or to the end" } ;
	moveitem = 	{ func = basiccmd ( "core.item.movetoplaylist" ) , params = "<old playlist number> <old position> <new playlist number> [<new position>]" , help = "Moves the song in given old position in old playlist to the new playlist in the given position or to the end" } ;
	addfile = 		{ func = basiccmd ( "core.localfileio.addfile" ) , params = " <path> <playlist number>[ <position>]" , help = "add the song at the path given (on the server) to the playlist specified, in the position given (position defaults to the end of the playlist)" } ;
	addfolder = 	{ func = basiccmd ( "core.localfileio.addfolder" ) , params = " <path> <playlist number>[ <position>[ <recurse>[ <addhiddenfiles?>]]]" , help = "add a folder to a playlist starting at given position, recursing to given number of levels, or true for infinite (default is no recursion)" } ;
	setvolume =  	{ func = basiccmd ( "player.setvolume" ) , params = "<volume>" , help = "set the volume of the player (volume is between 0% and 1000%)" } ;
	mute =  		{ func = basiccmd ( "player.mute" ) , params = "" , help = "mute the player" } ;
	unmute =  	{ func = basiccmd ( "player.unmute" ) , params = "" , help = "unmute the player" } ;
	manual = 	{ func = function ( )
		print ( "Entered a raw lomp connection. Ctrl+Z to exit." )
		local waiting
		while true do
			if not waiting then
				local line = io.read ( "*l" )
				if line then
					client:rawsend ( line )
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
					print ( "Success! " ..  table.serialise ( data ) )
				else
					print( "Fail! " .. code .. ": " ..  table.serialise ( data ) )
				end
			else
				print ( code , str , data )
			end
		end
	end , params = "" , help = "opens a telnet like session with the server" } ;
	help = 		{ func = function ( ... )
		local argn = select ( "#" , ... )
		local t , maxlen = { } , 0
		if argn == 0 then
			for k , v in pairs ( translate ) do
				local params , helptxt = v.params , v.help
				if ( #k + #params ) > maxlen then maxlen = #k + #params end
				t [ #t + 1 ] = { k , params , helptxt }
			end
			print ( "Valid functions are:" )
		else
			local args = { ... }
			for i = 1 , argn do
				local arg = args [ i ]
				local f = translate [ arg ]
				if f then
					local params = f.params
					local len = #arg + #params + 1
					if len > maxlen then maxlen = len end
					t [ #t + 1 ] = { arg , params , f.help }
				end
			end
		end
		
		table.sort ( t , function ( a , b ) return a[1] < b[1] end )
		for k , v in ipairs ( t ) do
			io.write ( " " , v [ 1 ] , " " , v [ 2 ] , "\n   " , v [ 3 ] , "\n" )
		end
	end , params = "" , help = "displays help" } ;
}

local ret = translate [ arg [ 1 ] ]
if ret then
	if arg [ 1 ] ~= "help" then
		client = lompclient.connect ( os.getenv ( "LOMP_HOST" ) or "localhost" , os.getenv ( "LOMP_PORT" ) or 5667 )
		if not client then error ( "Cannot connect to server" ) end
	end
	
	ret.func ( select ( 2 , ... ) )
	print ( )
	os.exit ( 0 )
else
	io.write ( "Invalid command, see: '" , arg [ 0 ]  , " help'" , "\n\n" )
	os.exit ( 1 )
end
