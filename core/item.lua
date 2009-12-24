--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local require , select , setmetatable , type = require , select , setmetatable , type
local tblcopy = table.copy
local ostime = os.time

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

function create ( typ , source , createdtime )
	return setmetatable ( 
		{ typ = typ , source = source , laststarted = false , created = createdtime or ostime ( ) } ,
		{ __index = function ( t , k ) return metadata.getdetails ( t.source ) [ k ] end }
	)
end

function copyitem ( item )
	return tblcopy ( item )
end

function additems ( plid , position , objects )
	local pl , playlistnum = core.playlist.getpl ( plid )
	if not pl then return ferror ( "'Add Item' called with invalid playlist" , 1 ) end
	local pllength = pl.length
	
	if position and ( type ( position ) ~= "number" or position > ( pl.length + 1 ) ) then
		return ferror ( "'Add Item' called with invalid position" , 1 ) 
	else
		position = position or ( pllength + 1 )
	end

	local objectn = #objects
	local newrev = { length = pllength + objectn }
	
	for i = pllength , position , -1 do
		newrev [ i + objectn ] = pl [ i ]
	end
	for i = 1 , objectn do
		newrev [ position + i - 1 ] = objects [ i ]
	end
	core.playlist.newrevision ( pl , newrev )
	
	core.triggers.fire ( "item_add" , playlistnum , position , objectn )
	
	return position
end

function additem ( playlistnum , position , object )
	return additems ( playlistnum , position , { object } )
end

function removeitem ( plid , position )
	local pl , playlistnum = core.playlist.getpl ( plid )
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
	
	core.playlist.newrevision ( pl , newrev )
	
	core.triggers.fire ( "item_remove" , playlistnum , position , object )

	return true
end

function copytoplaylist ( oldplid , oldpos , newplid , newpos )
	local newpl , newplnum = core.playlist.getpl ( newplid )
	if not newpl then return ferror ( "'Copy to playlist' called with invalid new playlist" , 1 ) end
	local oldpl , oldplnum = core.playlist.getpl ( oldplid )
	if not oldpl then return ferror ( "'Copy to playlist' called with invalid old playlist" , 1 ) end
	if not oldpl [ pos ] then
		return ferror ( "'Copy to playlist' called with invalid old item position" , 1 ) 
	end
	if newpos and ( type ( newpos ) ~= "number" or newpos > ( newpl.length + 1 ) ) then
		return ferror ( "'Copy to playlist' called with invalid new position" , 1 ) 
	else 
		newpos = newpos or ( newpl.length + 1 ) -- If new position is not given, add to end of playlist.
	end

	additem ( newplnum , newpos , copyitem ( oldpl [ oldpos ] ) )
	
	return newpos
end

function movetoplaylist ( oldplid , oldpos , newplid , newpos )
	local newpl , newplnum = core.playlist.getpl ( newplid )
	if not newpl then return ferror ( "'Move to playlist' called with invalid new playlist" , 1 ) end
	local oldpl , oldplnum = core.playlist.getpl ( oldplid )
	if not oldpl then return ferror ( "'Move to playlist' called with invalid old playlist" , 1 ) end
	
	local object = oldpl [ oldpos ]
	if type ( oldpos ) ~= "number" or not object then
		return ferror ( "'Move to playlist' called with invalid old item position" , 1 ) 
	end
	
	if newpos and ( type ( newpos ) ~= "number" or newpos > ( newpl.length + 1 ) or ( newpl == oldpl and newpos > newpl.length ) ) then 
		return ferror ( "'Move to playlist' called with invalid new position" , 1 ) 
	else 
		newpos = newpos or ( newpl.length + 1 ) -- If new position is not given, add to end of playlist.
	end
	
	removeitem ( oldplnum , oldpos )
	additem ( newplnum , newpos , object )
	
	return newpos
end
