--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"
require "player"

module ( "lomp" , package.seeall )

local t = os.time ( )
core = { 
	_NAME = "LOMP" , 
	_MAJ = 0 ,
	_MIN = 0 ,
	_INC = 1 ,
}

core._VERSION = core._MAJ .. "." .. core._MIN .. "." .. core._INC 
core._PROGRAM = _NAME .. " " .. core._VERSION

vars = { 
	init= t ,
	playlist = setmetatable ( {
		revision = 0 ,
	} , { __newindex = function ( t , k , v ) if type ( k ) == "number" then rawset ( t , k , v ) elseif k == "revision" then rawset ( t , k , v ) end end } ) ,
	played = { 
		revision = 0 ,
	} ,
	loop = false , -- Loop soft playlist?
	rpt = true , -- When end of soft playlist reached, go back to start of soft playlist?
	ploffset = 0 ,
}

function core.quit ( )
	if metadata.savecache then
		local ok , err = metadata.savecache ( )
	end
	if core.savestate then 
		local ok , err = core.savestate ( )
	end
	local ok = player.stop ( )
	
	updatelog ( "Quiting by request" , 4 )
	
	os.exit ( )
end

require "core.triggers"
require "core.playback"
require "core.playlist"
require "core.item"
require "core.info"

vars.emptyplaylist = vars.playlist [ core.playlist.new ( "Empty Playlist" , -1 ) ]
vars.softqueuepl = -1
vars.hardqueue = vars.playlist [ core.playlist.new ( "Hard Queue" , -2 ) ]

require "core.savestate"

function core.checkfileaccepted ( filename )
	local extension = string.match ( filename , "%.?([^%./]+)$" )
	extension = string.lower ( extension )
	
	local accepted = false
	for i , v in ipairs ( player.extensions ) do
		if extension == v then accepted = true end
	end
	if accepted == true then 
		for i , v in ipairs ( config.banextensions ) do
			local found = string.find ( extension , v )
			if found then return false , ( "Banned file extension (" .. extension .. "): " .. filename )  end
		end
	else	return false, ( "Invalid file type (" .. extension .. "): " .. filename )
	end
	return true
end

-- Queue Stuff

vars.queue = setmetatable ( { } , {
	__index = function ( t , k )
		if type ( k ) ~= "number" or k < 1 then return nil end
		if k <= vars.hardqueue.length then
			return vars.hardqueue [ k ]
		else
			local softqueuelen = vars.playlist [ vars.softqueuepl ].length
			if softqueuelen <= 0 then
				--return nil
			else
				local insoft = vars.ploffset + k - vars.hardqueue.length
				if insoft > softqueuelen and vars.loop and ( insoft - softqueuelen ) < vars.ploffset then
					insoft = insoft - softqueuelen
				end
				return vars.playlist [ vars.softqueuepl ] [ insoft ] -- This could be an item OR nil
			end
		end
	end,
} )

function core.setsoftqueueplaylist ( num )
	if type ( num ) ~= "number" or not vars.playlist [ num ] then 
		return ferror ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
	end
	
	vars.softqueuepl = num
	vars.ploffset = 0 -- Reset offset
	
	return num
end

-- History Stuff

function core.clearhistory ( )
	local oldrevision = vars.played.revision or 0
	vars.played = { revision = ( oldrevision + 1 ) }
	return true
end

function core.removefromhistory ( pos )
	if pos > #vars.played then return ferror ( "Invalid history item." , 1 ) end
	
	table.remove ( vars.played , pos )
	
	vars.played.revision = vars.played.revision + 1
	return true
end

-- Misc Helper Functions

function core.reloadlibrary ( )
	core.playlist.clear ( 0 )
	for i , v in ipairs ( config.library ) do
		core.localfileio.addfolder ( v , 0 , nil , true )
	end
end

function core.enablelooping ( )
	vars.loop = true
	return true , vars.loop
end

function core.disablelooping ( )
	vars.loop = false
	return true , vars.loop
end
