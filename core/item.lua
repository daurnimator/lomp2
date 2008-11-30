--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.item" , package.see ( lomp ) )

--[[
item = {}
item.typ = "file" or "stream"
item.source = source path
--]]

require "core.localfileio"

function create ( typ , source )
	local item = { typ = typ , source = source , laststarted = false }
	item.details = tags.getdetails ( source )
	return item
end

function additem ( object , pl , pos )
	local place
	if pl == nil or pl == "hardqueue" then -- If no playlist given, or expressly stated: add to hard queue
		pl = "hardqueue"
		place = vars.hardqueue
	else	
		if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
		if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
			return ferror ( "'Add item' called with invalid playlist" , 1 )
		end
		place = vars.pl [ pl ]
	end
	if type ( pos ) ~= "number" then
		if pos == nil or pos > #place then pos = #place + 1 -- Add to end of playlist/queue
		elseif pos < 1 then pos = 1
		else	return ferror ( "'Add item' called with invalid position" , 1 )
		end
	end
	
	table.insert ( place , pos , object )
	place.revision = place.revision + 1
	
	updatelog ( "Added item to playlist " .. pl .. " (" .. place.name .. ") position #" .. pos .. " Source: " .. object.source  , 4 )
	return pl , pos , object
end
function removeitem ( pl , pos )
	local place
	if pl == "hardqueue" then
		pl = "hardqueue"
		place = vars.hardqueue
	else
		if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
		if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
			return ferror ( "'Remove item' called with invalid playlist" , 1 ) 
		end
		place = vars.pl [ pl ]
	end
	if type ( pos ) ~= "number" or pos < 1 or pos > #vars.pl [ pl ] then
		return ferror ( "'Remove item' called with invalid item" , 1 ) 
	end
	
	removeditem = table.remove ( place , pos )
	place.revision = place.revision + 1
	
	updatelog ( "Removed item from playlist " .. pl .. " (" .. place.name .. ") position #" .. pos .. " Source: " .. object.source  , 4 )
	return pl , pos , removeditem
end
function copytoplaylist ( newpl , newpos , oldpl , oldpos )
	local oldplace
	if oldpl == nil or oldpl == "hardqueue" then
		oldplace = vars.hardqueue
	else
		if type ( oldpl ) == "string" then oldpl = table.valuetoindex ( vars.pl , "name" , oldpl ) end
		if type ( oldpl ) ~= "number" or oldpl < 0 or oldpl > #vars.pl then 
			return ferror ( "'Copy to playlist' called with invalid old playlist" , 1 ) 
		end
		oldplace = vars.pl [ oldpl ]
	end
	if type ( oldpos ) ~= "number" or oldpos < 1 or oldpos > #vars.pl [ pl ] then
		return ferror ( "'Copy to playlist' called with invalid old item" , 1 ) 
	end
	local newplace
	if newpl == nil or newpl == "hardqueue" then
		newplace = vars.hardqueue
	else
		if type ( newpl ) == "string" then newpl = table.valuetoindex ( vars.pl , "name" , newpl ) end
		if type ( newpl ) ~= "number" or newpl < 0 or newpl > #vars.pl then 
			return ferror ( "'Copy to playlist' called with invalid new playlist" , 1 ) 
		end
		newplace = vars.pl [ newpl ]
	end
	if type ( newpos ) ~= "number" or newpos < 1 or newpos > #vars.pl [ pl ] then
		if newpos == nil then
			newpos = #newplace + 1 -- If new position is not given, add to end of playlist.
		else	return ferror ( "'Copy to playlist' called with invalid new item" , 1 ) 
		end
	end
	
	--table.insert ( newplace , newpos , oldplace [ oldpos ] )
	newplace [ newpos ] = table.copy ( oldplace [ oldpos ] )
	
	if oldpl == newpl then
		-- Copy within a playlist
		vars.pl [ oldpl ].revision = vars.pl [ oldpl ].revision + 1
	else
		-- Copy between playlists
		vars.pl [ oldpl ].revision = vars.pl [ oldpl ].revision + 1
		vars.pl [ newpl ].revision = vars.pl [ newpl ].revision + 1
	end
	
	return newpl , newpos , oldpl , oldpos , newplace [ newpos ]
end
function movetoplaylist ( newpl , newpos , oldpl , oldpos )
	local newpl , newpos , oldpl , oldpos = copytoplaylist ( newpl , newpos , oldpl , oldpos )
	if not newpl then -- Copy error'd
		return newpl , newpos
	end
	local pl , pos , tmp = removeitem ( oldpl , oldpos )
	if not pl then
		return pl , pos
	end
	return newpl , newpos , oldpl , oldpos , tmp
end
