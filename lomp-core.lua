--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"
require "player"

local ipairs , rawset , setmetatable , type , require = ipairs , rawset , setmetatable , type , require
local ostime = os.time
local strfind , strmatch , strlower = string.find , string.match , string.lower
local tblremove = table.remove

module ( "lomp" , package.seeall )

local t = ostime ( )
core = { 
	_NAME = "LOMP" , 
	_MAJ = 0 ,
	_MIN = 0 ,
	_INC = 1 ,
}

require "core.triggers"

local triggeronchange = { 
	loop = true ;
	rpt = true ;
	ploffset = true ;
	softqueueplaylist = true ;
}

local varsindex = {
	init= t ;
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
			local val = vars [ k ]
			rawset ( varsindex , k , v )
			if triggeronchange [ k ] then
				triggers.fire ( k , v )
			end
		end ;
	}
)

function core.quit ( )
	player.stop ( )
	
	triggers.fire ( "quit" , newoffset )	
	
	if metadata.savecache then
		local ok , err = metadata.savecache ( )
	end
	if core.savestate then 
		local ok , err = core.savestate ( )
	end
	
	quit = true
	return true
end

core._VERSION = core._MAJ .. "." .. core._MIN .. "." .. core._INC 
core._PROGRAM = _NAME .. " " .. core._VERSION

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
	local playlistnum = core.playlist.getnum ( vars.library )
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

core["repeat"] = function ( bool )
	if type ( bool ) ~= "boolean" then return ferror ( "Repeat called with invalid argument" ) end
	vars.rpt = bool
	return true
end

function core.checkfileaccepted ( filename )
	local extension = strmatch ( filename , "%.?([^%./]+)$" )
	extension = strlower ( extension )
	
	local accepted = false
	for i , v in ipairs ( player.extensions ) do
		if extension == v then accepted = true end
	end
	if accepted == true then 
		for i , v in ipairs ( config.banextensions ) do
			if strfind ( extension , v ) then return false , ( "Banned file extension (" .. extension .. "): " .. filename )  end
		end
	else	return false, ( "Invalid file type (" .. extension .. "): " .. filename )
	end
	return true
end

function core.setsoftqueueplaylist ( num )
	if type ( num ) ~= "number" or not vars.playlist [ num ] then 
		return ferror ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
	end
	
	vars.softqueueplaylist = num
	vars.ploffset = 0 -- Reset offset
	
	return num
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

vars.queue = setmetatable ( { } , {
	__index = function ( t , k )
		if type ( k ) ~= "number" or k < 1 then return nil end
		if k <= vars.hardqueue.length then
			return vars.hardqueue [ k ]
		else
			local softqueuelen = vars.playlist [ vars.softqueueplaylist ].length
			if softqueuelen > 0 then
				local insoft = vars.ploffset + k - vars.hardqueue.length
				if insoft > softqueuelen and vars.loop and ( insoft - softqueuelen ) < vars.ploffset then
					insoft = insoft - softqueuelen
				end
				return vars.playlist [ vars.softqueueplaylist ] [ insoft ] -- This could be an item OR nil
			end
		end
	end ;
} )
