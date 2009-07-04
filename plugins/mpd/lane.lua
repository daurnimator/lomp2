--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "socket"
require "copas"

if type ( address ) ~= "string" then address = "*" end
if type ( port ) ~= "number" or port > 65535 or port <= 0 then port = 6600 end

local mpdversion = "0.13.0"

local plrev = { { 0 , 0 } }

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

	local timeout = nil
	thread:send ( timeout , "cmd" , { cmd = name , parameters = parameters } )
	
	local val , key = thread:receive ( timeout , "returncmd" )
	local ok , err = unpack ( val )
	if ok then
		return unpack ( err )
	else
		return false , err
	end
end
local function getvar ( name )
	-- Executes the value of a variable
	-- Example of string: vars.playlist
	if type ( name ) ~= "string" then return false end

	local timeout = nil
	thread:send ( timeout , "var" , name )
	local val , key = thread:receive ( timeout , "returnvar" )
	local ok , err = unpack ( val )
	if ok then
		return err
	else
		return false , err
	end
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
				r = r
				return r
			elseif type ( t ) == "string" then
				return t
			elseif t == nil then
				return ""
			elseif t == false then
				return false , err
			else
				error ( "Bad type" )
			end
		else
			return false , { 5 , nil , 'unknown command "' .. cmd .. '"' }
		end
	else
		updatelog ( "FAILED CMD FIND" .. line .. i .. j .. cmd , 5 , _G )
		return 
	end
end

local function mpdserver ( skt )
	copas.send ( skt , "OK MPD " .. mpdversion .. "\n")
	while true do
		local line , err = copas.receive( skt )
		if line then
			if line ~= "status" then updatelog ( "New MPD Command: " .. line , 5 , _G ) end
			local ok , ack = doline ( line , skt )
			if ok then
				ok = ok .. "OK\n"
			elseif ok == false then
				ok = makeackmsg ( ack [ 1 ] , 0 , ack [ 2 ] , ack [ 3 ] )
			--else -- nil.... bad commands array entry
			end
			updatelog ( "MPD Replying: \n" .. ( ok or "NOT OK" ) , 5 , _G )
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
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			r = r .. ok
		elseif ok == false then
			-- RAISE ERROR?
			--r = r .. a
			return r
		else
		end
	end
	return r
end

commands.command_list_ok_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
	end
	--Do all functions and concatenate
	local j = 0
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			j = j + 1
			r = r .. ok .. "OK\n"
		elseif ok == false then
			-- RAISE ERROR?
			--r = r .. a
			return r
		else
		end
	end
	--r = r .. string.rep ( "\n" , j )
	return r
end

commands.commands = function ( line , skt )
	local r = ""
	for k in pairs ( commands ) do
		r = r .. "command: " .. k .. "\n"
	end
	return r	
end

commands.notcommands = function ( line , skt )
	local r = ""
	
	for k in pairs ( allcommands ) do
		if not commands [ k ] then
			r = r .. "command: " .. k .. "\n"
		end
	end
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
	
	local currentrev = getvar ( "{ vars.playlist [ vars.softqueuepl ].revision , vars.hardqueue.revision }" )
	if currentrev [ 1 ] ~= plrev [ #plrev ] [ 1 ] or currentrev [ 2 ] ~= plrev [ #plrev ] [ 2 ] then
		plrev [ #plrev + 1 ] = currentrev
	end
	
	local t = {	
		volume = execute ( "player.getvolume" ) ;
		["repeat"] = booleantonumber ( getvar ( "vars.rpt" ) ) ;
		random = 0 ;
		playlist = #plrev ;
		playlistlength = getvar ( "vars.hardqueue.length + vars.playlist [ vars.softqueuepl ].length" ) ;
		xfade = 0 ;
		state = state ;
	}
	if state ~= "stop" then
		t.song = getvar ( "vars.ploffset" )
		--t.songid
		local time = getvar ( "vars.queue [ 0 ].details.length" )
		t.time =  math.floor ( time/60 ) .. ":" .. time % 60
		--t.bitrate
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
	local start , finish = string.match ( line , "^playlistinfo%s+(%d*)%s*:?%s*(%d*)" )
	start = tonumber ( start )
	finish = tonumber ( finish )
	local pl , err = execute ( "core.info.getplaylist" , { getvar ("vars.softqueuepl" ) } )
	local queue = execute ( "core.info.getplaylist" )

	if start then
		if not finish then
			finish = start 
		end
	else
		start = 1
		finish = #pl
	end
	
	function tag ( item , tag )
		local tag = item.details.tags [ tag ]
		if not tag or not tag [ 1 ] then return
		else
			local r = tag [ 1 ]
			for i = 2, #tag do
				r = r .. "; " .. tag [ i ]
			end
			return r
		end
	end
	
	local d = { }
	for i = start , finish do
		local t = pl [ i ]
		d [ #d + 1 ] = {
			file = t.source ;
			Time = t.details.length ;
			Artist = tag ( t , "artist" ) ;
			Album = tag ( t , "album" ) ;
			Title = tag ( t , "title" ) ;
			Track = tag ( t , "tracknumber" ) ;
			Genre = tag ( t , "genre" ) ;
			Disc = tag ( t , "discnumber" ) ;
			Pos = i - 1 ;
			Id = i - 1 ;
		}
	end
	
	local r = ""
	for i , v in ipairs ( d ) do
		for k , v in pairs ( v ) do
			r = r .. k .. ": " .. tostring ( v ) .. "\n"
		end
	end
	
	return r
end
commands.pause = function ( line , skt )
	local pause = tonumber ( string.match ( line , "pause%s+([01])" ) )
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

run ( address , port )
