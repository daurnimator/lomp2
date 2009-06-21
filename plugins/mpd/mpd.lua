--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dir = dir -- Grab vars needed
local updatelog , ferror = updatelog , ferror

local send = inqueue
table.insert ( outqueues , queue.newqueue(128) )
local cmdidentifier = #outqueues 
local cmdreceive = outqueues [ #outqueues ]
table.insert ( outqueues , queue.newqueue(128) )
local varidentifier = #outqueues 
local varreceive = outqueues [ #outqueues ]
-- MPD Plugin
 -- Lets you use any mpd client to control lomp!

module ( "mpd" , package.see ( lomp ) )

_NAME = "MPD Compatability layer for lomp"
_VERSION = 0.1

loadfile ( dir .. "config" ) ( ) -- Load config

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "socket"
require "copas"

if type ( address ) ~= "string" then address = "*" end
if type ( port ) ~= "number" or port > 65535 or port <= 0 then port = 6600 end

local mpdversion = "0.13.0"

local plrev = { }

local commands = { }
local allcommands = { 	
	-- Protocol things
	command_list_begin = true , command_list_ok_begin = true , 
	commands = true , notcommands = true ,
	
	-- Admin Commands
	disableoutput = false , enableoutput = false , kill = true , update = false ,
	
	-- Informational Commands
	status = true , stats = false , outputs = true , tagtypes = false , urlhandlers = false ,
	
	-- Playlist Commands
	add = false , addid = false , clear = false , currentsong = false , delete = false , deleteid = false , load = false , rename = false , move = false , moveid = false ,
	playlist = false , playlistinfo = false , playlistid = false , plchanges = false , plchangesposid = false ,
	rm = false , save = false , shuffle = false , swap = false , swapid = false ,
	listplaylist = false , listplaylistinfo = false , playlistadd = false , playlistclear = false , playlistdelete = false , playlistmove = false , playlistfind = false , playlistsearch = false ,
	
	-- Playback Commands
	crossfade = false , 
	next = true , pause = true , play = true , stop = true , previous = true ,
	playid = false , 
	random = false , ["repeat"] = true ,
	seek = false , seekid = false ,
	setvol = false ,
	volume = false ,
	
	-- Misc
	clearerror = false , close = true , password = false , ping = true ,
}

local function execute ( name , parameters )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	if parameters and type ( parameters ) ~= "table" then return false end
	
	send:insert ( { cmdidentifier , "cmd" , { cmd = name , params = parameters } } )
	
	return unpack ( cmdreceive:remove ( ) )
end
local function getvar ( name )
	-- Executes the value of a variable
	-- Example of string: vars.pl
	if type ( name ) ~= "string" then return false end

	local timeout = nil
	
	send:insert ( { varidentifier , "var" , name } )
	local val = varreceive:remove ( )
	if val [ 1 ] == false then return nil , val [ 2 ]
	else return val [ 2 ] end
end
local function makeackmsg ( errorid , position ,  current_command ,  message_text )
	--[[	ACK_ERROR_NOT_LIST = 1 
		ACK_ERROR_ARG = 2 
		ACK_ERROR_PASSWORD = 3 
		ACK_ERROR_PERMISSION = 4 
		ACK_ERROR_UNKNOWN = 5 
		ACK_ERROR_NO_EXIST = 50 
		ACK_ERROR_PLAYLIST_MAX = 51 
		ACK_ERROR_SYSTEM = 52 
		ACK_ERROR_PLAYLIST_LOAD = 53 
		ACK_ERROR_UPDATE_ALREADY = 54 
		ACK_ERROR_PLAYER_SYNC = 55 
		ACK_ERROR_EXIST = 56 
	--]]
	return "ACK [".. errorid .. "@".. position .. "] {" ..  ( current_command or "" ) .. "} " .. ( message_text or "" ) .. "\n"
end

local function doline ( line , skt )
	local i , j , cmd = string.find ( line , "([^ \t]+)" )
	if i then
		if commands [ cmd ] then
			local t , err = commands [ cmd ] ( line , skt )
			if type ( t ) == "table" then
				local r = ""
				for k , v in pairs ( t ) do
					r = r .. k .. ": " .. tostring ( v ) .. "\n"
				end
				r = r .. "OK\n"
				return r
			elseif type ( t ) == "string" then
				return t
			elseif t == nil then
				return "OK\n"
			elseif t == false then
				return false , err
			else
				error ( "Bad type" )
			end
		else
			return false , { 5 , nil , 'unknown command "' .. cmd .. '"' }
		end
	else
		updatelog ( "FAILED CMD FIND" .. line .. i .. j .. cmd , 5 )
		return 
	end
end

local function mpdserver ( skt )
	copas.send ( skt , "OK MPD " .. mpdversion .. "\n")
	while true do
		local line , err = copas.receive( skt )
		if line then 
			if line ~= "status" then updatelog ( "New MPD Command: " .. line , 5 ) end
			local ok , ack = doline ( line , skt )
			if ok then
			elseif ok == false then
				ok = makeackmsg ( ack [ 1 ] , 0 , ack [ 2 ] , ack [ 3 ] )
			--else -- nil.... bad commands array entry
			end
			updatelog ( "MPD Replying: \n" .. ( ok or "NO OK" ) , 5 )
			local bytessent , err = copas.send ( skt , ok )
		else
			if err == "closed" then
				-- "MPD Client Disconnected"
				return
			else
				return ferror ( "MPD Socket Error: " .. err , 3 , _G )
			end
		end
	end
end

commands.command_list_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	--local i , max = 0 , 100
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
		--[[i = i + 1
		if i >= max then 
			table.insert ( thingstodo , function return false , { 1 , max , nil , "command list too long" } )
			break 
		end--]]
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			r = r .. a
		elseif ok == false then
			r = r .. a
			return r
		else
		end
	end
	r = r .. "OK\n"
	return r
end

commands.command_list_ok_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	--local i , max = 0 , 100
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
		--[[i = i + 1
		if i >= max then 
			table.insert ( thingstodo , function return false , { 1 , max , nil , "command list too long" } )
			break 
		end--]]
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			r = r .. a .. "OK\n"
		elseif ok == false then
			r = r .. a
			return r
		else
		end
	end
	return r
end

commands.commands = function ( line , skt )
	local r = ""
	for k in pairs ( commands ) do
		r = r .. "command: " .. k .. "\n"
	end
	r = r .. "OK\n"
	return r	
end

commands.notcommands = function ( line , skt )
	local r = ""
	
	for k in pairs ( allcommands ) do
		if not commands [ k ] then
			r = r .. "command: " .. k .. "\n"
		end
	end
	r = r .. "OK\n"
	return r	
end

commands.kill = function ( line , skt )
	execute ( "core.quit" )
	return
end

commands.status = function ( line , skt )
	local state = getvar ( "core.playback.state" )
	if state == "stopped" then state = "stop"
	elseif state == "playing" then state = "play"
	elseif state == "paused" then state = "pause"
	end
	function booleantonumber ( boolean )
		if boolean == true then return 1
		elseif boolean == false then return 0
		else return nil end
	end
	plrev [ #plrev + 1 ] = { getvar ( "{ vars.pl [ vars.softqueuepl ].revision , vars.hardqueue.revision }" ) }
	local t = {	
		volume = select ( 2 , execute ( "player.getvolume" ) ) [ 1 ] ;
		["repeat"] = booleantonumber ( getvar ( "vars.rpt" ) ) ;
		random = 0 ;
		playlist = #plrev ;
		playlistlength = getvar ( "#vars.pl [ vars.softqueuepl ]" ) ;
		xfade = 0 ;
		state = state ;
	}
	if state ~= "stop" then
		t.song = getvar ( "vars.ploffset" )
		--t.songid
		local time = getvar ( "vars.queue [ 0 ].details.length" )
		t.time =  math.floor ( time/60 ) .. ":" .. time % 60
		--t.bitrate
		print(getvar ( "vars.queue [ 0 ].details.samplerate" ) , ":" , getvar ( "vars.queue [ 0 ].details.bitrate" ) , ":" , getvar ( "vars.queue [ 0 ].details.channels" ))
		t.audio = getvar ( "vars.queue [ 0 ].details.samplerate" ) .. ":" .. getvar ( "vars.queue [ 0 ].details.bitrate" ) .. ":" .. getvar ( "vars.queue [ 0 ].details.channels" )
		--t.updating_db
		--t.error
	end
	return t
end
commands.outputs = function ( line , skt )
	return {
		outputid = 0 ;
		outputname = "default detected output" ;
		outputenabled = 1 ;
	}
end
commands.urlhandlers = function ( line , skt )
	return {
		handler = "http://" ;
	}
end
commands.clear = function ( line , skt )
	execute ( "core.playlist.clear" , { getvar ( "vars.softqueuepl" ) } )
	return
end
commands.playlistinfo = function ( line , skt )
	r = ""
	local pl = getvar ( "vars.pl [ vars.softqueuepl ]" )
	local queue = getvar ( "vars.hardqueue" )
	
	function tag ( item , tag )
		local tag = item.details.tags [ tag ]
		if not tag or not tag [ 1 ] then return "" 
		else
			local r = tag [ 1 ]
			for i = 2, #tag do
				r = r .. "; " .. tag [ i ]
			end
			return r
		end
	end
	
	i = 1
	while true do
		local t = pl [ i ]
		if not t then break end
		print("W" , t.source , t.details , t.details.length )
		r = r .. "file: " .. t.source .. "\nTime: " .. t.details.length .. "\nArtist: " .. tag ( t , "artist" )  .. "\nAlbum: " .. tag ( t , "album" ) .. "\nTitle: " .. tag ( t , "title" ) .. "\nTrack: " .. tag ( t , "tracknumber" ) .. "\nGenre: " .. tag ( t , "genre" ) .. "\nDisc: " .. tag ( t , "discnumber" ) .. "\nPos: " .. i - 1 .. "\nId: " .. i - 1 .. "\n"
		i = i + 1
	end
	print(r)
	print(getvar ( "vars.queue" )[1].source )
	print(getvar ( "vars.pl [ vars.softqueuepl ]" ) )
	print(getvar ( "vars.hardqueue" ) )
	return r .. "\n"
end
commands.pause = function ( line , skt )
	local pause = tonumber ( string.match ( line , "pause[ \t]+([01])" ) )
	if pause == 1 then
		execute ( "core.playback.pause" )
	elseif pause == 0 then
		execute ( "core.playback.unpause" )
	else -- Its a toggle
		execute ( "core.playback.togglepause" )
	end
	return
end
commands.play = function ( line , skt )
	local song = tonumber ( string.match ( line , "play[ \t]+(%d+)" ) )
	if song then
		execute ( "core.playback.goto" , { song } )
		execute ( "core.playback.play" )
	else 
		execute ( "core.playback.play" )
	end
	return
end
commands.stop = function ( line , skt )
	execute ( "core.playback.stop" )
	return
end
commands.next = function ( line , skt )
	execute ( "core.playback.forward" )
	return
end
commands.previous = function ( line , skt )
	execute ( "core.playback.backward" )
	return
end
commands["repeat"] = function ( line , skt ) -- repeat is a lua reserverd word, must put in quotes
	local rpt = tonumber ( string.match ( line , "repeat[ \t]+([01])" ) )
	if rpt == 1 then
		execute ( "core.enablelooping" )
		return
	elseif rpt == 0 then
		execute ( "core.disablelooping" )
		return
	else
		return false , { 2 , "repeat" , "Bad argument" }
	end
end
commands.close = function ( line , skt )
	skt:close ( )
	return
end
commands.ping = function ( line , skt )
	return
end


function initiate ( host , port )
	local srv, err
	srv , err = socket.bind ( host , port , 100 )
	if srv then 
		copas.addserver ( srv , mpdserver )
		return updatelog ( "MPD server started; bound to '" .. host .. "', port #" .. port , 4 , _G ) 
	else
		return ferror ( "MPD server could not be started: " .. err , 1 , _G )
	end
end

function run ( address , port )
	initiate ( address ,  port )
	copas.loop ( )
end

thread.newthread ( run , { address , port} )

return _NAME , _VERSION
