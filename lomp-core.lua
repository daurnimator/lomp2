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

vars = { 
	init= t ,
	pl = {
		[-1] = { } , -- Empty Playlist
		revision = 0 ,
	} ,
	hardqueue = { 
		revision = 0 ,
		name = "Hard Queue"
	} ,
	played = { 
		revision = 0 ,
	} ,
	loop = false , -- Loop soft playlist?
	rpt = true , -- When end of soft playlist reached, go back to start of soft playlist?
	softqueuepl = -1 , 
	ploffset = 0 ,
}

function core.quit ( )
	if tags.savecache then
		local ok , err = tags.savecache ( )
	end
	if core.savestate then 
		local ok , err = core.savestate ( )
	end
	local ok = player.stop ( )
	
	updatelog ( "Quiting by request" , 4 )
	
	os.exit ( )
end

require "core.playback"
require "core.savestate"
require "core.playlist"
require "core.item"

function core.checkfileaccepted ( filename )
	local _ , _ , extension = string.find ( filename , "%.?([^%./]+)$" )
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

--[[
function core.addstream ( url , pl , pos )
	-- Check url is valid
	-- TODO: additional testing
	if type ( url ) ~= "string" then return ferror ( "'Add stream' called with invalid url" , 1 ) end
	
	local o = { typ = "stream" , source = url }
	
	return core.item.additem ( o , pl , pos )
end--]]

-- Queue Stuff  
vars.queue = setmetatable ( vars.hardqueue , {
	__index = function ( t , k )
		if type ( k ) ~= "number" then return nil end
		local o
		if k >= 1 and k <= #vars.hardqueue then
			o = vars.hardqueue [ k ]
		elseif k >= 1 then
			local softqueuelen = #vars.pl [ vars.softqueuepl ]
			if softqueuelen <= 0 then
				--return nil
			else
				local insoft = vars.ploffset + k - #vars.hardqueue
				if insoft > softqueuelen and vars.loop and ( insoft - softqueuelen ) < vars.ploffset then
					insoft = insoft - softqueuelen
				end
				o = vars.pl [ vars.softqueuepl ] [ insoft ] -- This could be an item OR nil
			end
		end
		return o
	end,
})
function core.clearhardqueue ( )
	vars.hardqueue = { 
		revision = vars.hardqueue.revision + 1 ,
		name = "Hard Queue" 
	}
	return true
end
function core.setsoftqueueplaylist ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
		return ferror ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
	end
	
	vars.softqueuepl = pl
	
	-- Reset offset
	vars.ploffset = 0
	
	return pl
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
		core.localfileio.addfolder ( v , 0 )
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
