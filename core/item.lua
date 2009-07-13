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

require "core.triggers"
require "core.playlist"
require "modules.metadata"

require "core.localfileio"

function create ( typ , source )
	return setmetatable ( { typ = typ , source = source , laststarted = false } , { __index = metadata.getdetails ( source ) } )
end

function copyitem ( item )
	return table.copy ( item )
end

function additem ( object , playlistnum , position )
	local pl = core.playlist.getnum ( playlistnum )
	if not pl then return ferror ( "'Add Item' called with invalid playlist" , 1 ) end
	local pllength = pl.length
	if position and type ( position ) ~= "number" then return ferror ( "'Add Item' called with invalid position" , 1 ) else position = position or ( pllength + 1 ) end

	local newrev = { length = pllength + 1 }
	
	for i = pllength , position , -1 do
		newrev [ i + 1 ] = pl [ i ]
	end
	newrev [ pllength + 1 ] = object
		
	pl.revisions [ #pl.revisions + 1 ] = newrev
	
	triggers.triggercallback ( "item_added" , playlistnum , pl , position , object )
	
	return position
end

function removeitem ( playlistnum , position )
	local pl = core.playlist.getnum ( playlistnum )
	if not pl then return ferror ( "'Remove item' called with invalid playlist" , 1 ) end
	if type ( position ) ~= "number" or not pl [ position ] then
		return ferror ( "'Remove item' called with invalid item" , 1 ) 
	end
	
	local pllength = pl.length
	local newrev = { length = pllength - 1 }
	local object = pl [ position ]
	
	for i = position + 1, pllength do
		newrev [ i - 1 ] = pl [ i ]
	end
	
	pl.revisions [ #pl.revisions + 1 ] = newrev
	
	triggers.triggercallback ( "item_removed" , playlistnum , pl , position , object )

	return true
end

function copytoplaylist ( newplnum , newpos , oldplnum , oldpos )
	local newpl = core.playlist.getnum ( newplnum )
	if not newpl then return ferror ( "'Copy to playlist' called with invalid new playlist" , 1 ) end
	local oldpl = core.playlist.getnum ( oldplnum )
	if not oldpl then return ferror ( "'Copy to playlist' called with invalid old playlist" , 1 ) end
	if not oldpl [ pos ] then
		return ferror ( "'Copy to playlist' called with invalid old item position" , 1 ) 
	end
	if newpos and type ( newpos ) ~= "number" then
		return ferror ( "'Copy to playlist' called with invalid new position" , 1 ) 
	else newpos = newpos or ( newpl.length + 1 ) -- If new position is not given, add to end of playlist.
	end

	additem ( copyitem ( oldpl [ oldpos ] ) , newpos , newplnum , newpos )
	
	return newpos
end

function movetoplaylist ( newplnum , newpos , oldplnum , oldpos )
	local newpl = core.playlist.getnum ( newplnum )
	if not newpl then return ferror ( "'Move to playlist' called with invalid new playlist" , 1 ) end
	local oldpl = core.playlist.getnum ( oldplnum )
	if not oldpl then return ferror ( "'Move to playlist' called with invalid old playlist" , 1 ) end
	
	local object = oldpl [ oldpos ]
	if type ( oldpos ) ~= "number" or not object then
		return ferror ( "'Move to playlist' called with invalid old item position" , 1 ) 
	end
	
	if newpos and type ( newpos ) ~= "number" then return ferror ( "'Move to playlist' called with invalid new position" , 1 ) else newpos = newpos or ( newpl.length + 1 ) end
	
	additem ( object , newplnum , newpos )
	removeitem ( oldplnum , oldpos )
	
	return newpos
end
