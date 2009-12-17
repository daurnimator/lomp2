--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- MPD Plugin
 -- Lets you use any mpd client to control lomp!

local dir = dir -- Grab vars needed
 
pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "socket"
require "copas"

local strfind = string.find
local tblconcat = function ( t , ... ) if not t then return "" end return table.concat ( t , ... ) end
local strformat = string.format

module ( "mpd" , package.see ( lomp ) )

_NAME = "MPD Compatability layer for lomp"
_VERSION = 0.1

loadfile ( dir .. "config" ) ( ) -- Load config

if type ( address ) ~= "string" then address = "*" end
if type ( port ) ~= "number" or port > 65535 or port <= 0 then port = 6600 end

local mpdversion = "0.13.0"

local plrev = { { 0 , 0 } }

local songid = setmetatable ( { } , { __index = function ( t , k ) 
	if type ( k ) ~= "number" then
		local id = #t + 1
		rawset ( t , id, k )
		rawset ( t , k , id )
		return id
	end
end ; } )

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
	playlist = false , playlistinfo = true , playlistid = false , plchanges = false , plchangesposid = false ,
	rm = false , save = false , shuffle = false , swap = false , swapid = false ,
	listplaylist = false , listplaylistinfo = false , playlistadd = false , playlistclear = false , playlistdelete = false , playlistmove = false , playlistfind = false , playlistsearch = false ,
	
	-- Playback Commands
	crossfade = false , 
	next = true , pause = true , play = true , stop = true , previous = true ,
	playid = false , 
	random = false , ["repeat"] = true ,
	seek = false , seekid = false ,
	setvol = true ,
	volume = false ,
	
	-- Misc
	clearerror = false , close = true , password = false , ping = true ,
}

local function execute ( name , parameters )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	if parameters and type ( parameters ) ~= "table" then return false end

	return cmd ( name , parameters )
end
local function getvar ( name )
	-- Executes the value of a variable
	-- Example of string: vars.playlist
	if type ( name ) ~= "string" then return false end

	local timeout = nil
	local ok , err = var ( name )
	if ok then
		return err
	else
		return nil , err
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

function hashconcat ( t , f) 
        local r = { }
        f = f or "%s: %s\n"
        for k , v in pairs ( t ) do
                r [ #r + 1 ] = strformat ( f , k , tostring ( v ) )
        end
	return tblconcat ( r )
end
  
local function doline ( line , skt )
	local i , j , cmd = strfind ( line , "([^ \t]+)" )
	if i then
		if commands [ cmd ] then
			local t , err = commands [ cmd ] ( line , skt )
			if type ( t ) == "table" then
				return hashconcat ( t )
			elseif type ( t ) == "string" then
				return t
			elseif t == nil then
				return ""
			elseif t == false then
				return false , err
			else
				error ( "Doline: Bad type" )
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
				ok = ok .. "OK\n"
			elseif ok == false then
				ok = makeackmsg ( ack [ 1 ] , 0 , ack [ 2 ] , ack [ 3 ] )
			--else -- nil.... bad commands array entry
			end
			--updatelog ( "MPD Replying: \n" .. ( ok or "NOT OK" ) , 5 )
			local bytessent , err = copas.send ( skt , ok )
		else
			if err == "closed" then
				-- "MPD Client Disconnected"
				return
			else
				return ferror ( "MPD Socket Error: " .. err , 3 )
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
	
	local currentrev = getvar ( "{ vars.playlist [ vars.softqueueplaylist ].revision , vars.hardqueue.revision }" )
	if currentrev [ 1 ] ~= plrev [ #plrev ] [ 1 ] or currentrev [ 2 ] ~= plrev [ #plrev ] [ 2 ] then
		plrev [ #plrev + 1 ] = currentrev
	end
	
	local t = {	
		volume = execute ( "player.getvolume" ) ;
		["repeat"] = booleantonumber ( getvar ( "vars.rpt" ) ) ;
		random = 0 ;
		playlist = #plrev ;
		playlistlength = getvar ( "vars.hardqueue.length + vars.playlist [ vars.softqueueplaylist ].length" ) ;
		xfade = 0 ;
		state = state ;
	}
	if state ~= "stop" then
		t.song = getvar ( "vars.ploffset" )
		t.songid = songid [ getvar ( "vars.queue [ 0 ].source" ) ]
		local time = getvar ( "vars.queue [ 0 ].length" )
		t.time = math.floor ( time/60 ) .. ":" .. time % 60
		--t.bitrate
		t.audio = getvar ( [[vars.queue [ 0 ].samplerate .. ":" .. vars.queue [ 0 ].bitrate .. ":" .. vars.queue [ 0 ].channels]] )
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
	execute ( "core.playlist.clear" , { getvar ( "vars.softqueueplaylist" ) } )
	return
end
commands.playlistid = function ( line , skt )
	local songid = string.match ( line , "^playlistid%s+\"?(%d+)" )
	if not songid then return commands.playlistinfo ( "playlistinfo" , skt ) end
	
end
commands.playlistinfo = function ( line , skt )
	local start , finish = string.match ( line , "^playlistinfo%s+\"?(%d*)%s*:?%s*(%d*)" )
	start = tonumber ( start )
	finish = tonumber ( finish )
	local pl , err = execute ( "core.playlist.fetch" , { getvar ("vars.softqueueplaylist" ) } )
	--local queue = execute ( "core.playlist.fetch" )

	if start then
		if not finish then
			finish = start 
		end
	else
		start = 1
		finish = #pl
	end
		
	local d = { }
	for i = start , finish do
		local item = pl [ i ]
		if item then
			local tags = item.tags
			local id = songid [ item.source ]
			d [ i ] = hashconcat {
				file = item.source ;
				Time = item.length ;
				Artist = tblconcat ( tags.artist , "; " ) ;
				Album = tblconcat ( tags.album , "; " )  ;
				Title = tblconcat ( tags.title , "; " ) ;
				Track = tblconcat ( tags.tracknumber , "; " ) ;
				Genre = tblconcat ( tags.genre , "; " ) ;
				Disc = tblconcat ( tags.discnumber , "; " ) ;
				Pos = i - 1 ;
				Id = id ;
			}
		else
			d [ i ] = ""
		end
	end
	
	return tblconcat ( d , nil , start , finish )
end
commands.pause = function ( line , skt )
	local pause = tonumber ( string.match ( line , "pause%s+\"?([01])" ) )
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
	local song = tonumber ( string.match ( line , "play%s+\"?(%d+)" ) )
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
commands.setvol = function ( line , skt )
	local vol = tonumber ( string.match ( line , "setvol%s+\"?(%d+)" ) )
	if vol >= 0 and vol <= 100 then
		execute ( "player.setvolume"  , { vol } )
	else
		return false , { 2 , nil , "bad or no argument" }
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
		return updatelog ( "MPD server started; bound to '" .. host .. "', port #" .. port , 4 ) 
	else
		return ferror ( "MPD server could not be started: " .. err , 1 )
	end
end

initiate ( address ,  port )
addstep ( function ( ) copas.step ( 0 ) return true end ) -- 0 timeout

return _NAME , _VERSION
