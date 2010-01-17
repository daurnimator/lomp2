--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , rawset , setmetatable , type , require = ipairs , rawset , setmetatable , type , require
local ostime = os.time
local strfind = string.find
local tblremove = table.remove

module ( "lomp" )

core = { 
	_NAME = "LOMP" , 
	_MAJ = 0 ,
	_MIN = 0 ,
	_INC = 1 ,
}

core._VERSION = core._MAJ .. "." .. core._MIN .. "." .. core._INC 
core._PROGRAM = _NAME .. " " .. core._VERSION

require "core.triggers"

local triggeronchange = { 
	loop = true ;
	rpt = true ;
	ploffset = true ;
	softqueueplaylist = true ;
}

local time = ostime ( )
local varsindex = {
	init= time ;
	playlist = setmetatable ( {
			revision = 0 ;
		} , { __newindex = function ( t , k , v ) if type ( k ) == "number" then rawset ( t , k , v ) elseif k == "revision" then rawset ( t , k , v ) end end } ) ;
	played = { 
		revision = 0
	} ;
	loop = false ; -- Loop soft playlist?
	rpt = true ; -- When end of soft playlist reached, go back to start of soft playlist?
	ploffset = 0 ;
}
vars = setmetatable ( { } , {
		__index = varsindex ;
		__newindex = function ( t , k , v )
			rawset ( varsindex , k , v )
			if triggeronchange [ k ] then
				core.triggers.fire ( k , v )
			end
		end ;
	}
)

function core.quit ( )
	player.stop ( )
	
	core.triggers.fire ( "quit" , newoffset )
	
	if metadata.savecache then
		local ok , err = metadata.savecache ( )
	end
	if core.savestate then 
		local ok , err = core.savestate ( )
	end
	
	addstep ( function ( ) mainloop:quit ( ) return false end )
	return true
end

require "player"
require "core.playback"
require "core.playlist"
require "core.item"
require "core.info"

require "core.savestate"

-- History Stuff

function core.clearhistory ( )
	local oldrevision = vars.played.revision or 0
	vars.played = { revision = ( oldrevision + 1 ) }
	return true
end

function core.removefromhistory ( pos )
	if pos > #vars.played then return ferror ( "Invalid history item." , 1 ) end
	
	tblremove ( vars.played , pos )
	
	vars.played.revision = vars.played.revision + 1
	return true
end

-- Misc Helper Functions

function core.reloadlibrary ( )
	local pl , playlistnum = core.playlist.getpl ( vars.library )
	core.playlist.clear ( playlistnum )
	for i , v in ipairs ( config.library ) do
		core.localfileio.addfolder ( v , playlistnum , nil , true )
	end
	return true
end

function core.loop ( bool )
	if type ( bool ) ~= "boolean" then return ferror ( "Loop called with invalid argument" ) end
	vars.loop = bool
	return true
end

core [ "repeat" ] = function ( bool ) -- repeat is a keyword
	if type ( bool ) ~= "boolean" then return ferror ( "Repeat called with invalid argument" ) end
	vars.rpt = bool
	return true
end

function core.setploffset ( num )
	if num == nil then
		num = 0
	elseif type ( num ) ~= "number" or num < 0 or num >= core.playlist.getpl ( vars.softqueueplaylist ).length then
		return ferror ( "'Set playlist offset' called with invalid offset" )
	end
	
	vars.ploffset = num
	
	return num
end

-- Returns the playlist's index, and the new playlist's length
function core.setsoftqueueplaylist ( id )
	local pl , num = core.playlist.getpl ( id )
	
	if type ( pl ) ~= "playlist" then 
		return ferror ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
	end
	
	if vars.softqueueplaylist ~= num then
		vars.softqueueplaylist = num
		core.setploffset ( 0 )
	end
	
	return num , pl.length
end

do -- Restore State
	local ok , err = core.restorestate ( )
	if not ok then
		core.playlist.new ( "Library" , 0 ) -- Create Library (Just playlist 0)
		vars.softqueueplaylist = core.playlist.new ( "Empty Playlist" , -1 ) 
		core.playlist.new ( "Hard Queue" , -2 ) 
	end
	vars.library = vars.playlist [ 0 ]
	vars.emptyplaylist = vars.playlist [ -1 ]
	vars.hardqueue = vars.playlist [ -2 ]
	if not ok then core.reloadlibrary ( ) end
end

-- Queue Stuff
vars.currentsong = false
vars.queue = setmetatable ( { } , {
	__index = function ( t , k )
		if k == "length" then 
			return vars.hardqueue.length + core.playlist.getpl ( vars.softqueueplaylist ).length
		elseif type ( k ) ~= "number" or k < 0 then
			return nil
		elseif k == 0 then
			return vars.currentsong
		end
		
		local hardqueue = vars.hardqueue
		local hardqueuelen = hardqueue.length
		if k <= hardqueuelen then
			return hardqueue [ k ]
		else
			k = k - hardqueuelen
			
			local sqpl = core.playlist.getpl ( vars.softqueueplaylist )
			local ploffset = vars.ploffset
			if vars.loop then
				ploffset = ploffset % sqpl.length -- Enables looping behaviour
			end
			
			return sqpl [ ploffset + k ] -- This could be an item OR nil
		end
	end ;
	__newindex = function ( t , k , v )
		updatelog ( "Attempted newindex assignment on queue: " .. k , 1 )
	end ;
	__len = function ( t )
		return t.length
	end ;
} )
