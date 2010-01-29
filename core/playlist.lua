--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local require , setmetatable , tostring , type = require , setmetatable , tostring , type
local tblrandomise , tblstablesort = table.randomise , table.stablesort

module ( "lomp.core.playlist" , package.see ( lomp ) )

require "core.triggers"

function getplaylist ( playlistnum )
	if type ( playlistnum ) ~= "number" or not vars.playlist [ playlistnum ] then
		return ferror ( "'getplaylist' called with invalid playlist index" , 3 )
	else
		return vars.playlist [ playlistnum ]
	end	
end

function getnum ( pl )
	if type ( pl ) == "playlist" then
		return pl.index
	else
		return ferror ( "'getnum' called with invalid playlist" , 3 )
	end
end

function getpl ( id )
	local pl , num
	if type ( id ) == "number" then
		pl = getplaylist ( id )
		num = pl and id
	elseif type ( id ) == "playlist" then
		num = getnum ( id )
		pl = num and id
	end
	return pl , num or "'getpl' called with invalid id"
end

local function playlistval ( revisions , k , latest , earliest )
	if type ( k ) == "number" and k > playlistval ( revisions , "length" , latest , 0 ) then return nil end -- If trying to index past the length of the playlist
	
	for i = latest , earliest , -1 do
		local r = revisions [ i ]
		if type ( r ) ~= "table" then return nil end
		local v = r [ k ]
		if v ~= nil then return v end
	end
	
	return nil
end

local function collapserev ( revisions , latest , earliest )
	earliest = earliest or 0
	
	local t , i = { } , 1
	while true do
		local tmp = playlistval ( revisions , i , latest , earliest )
		if tmp == nil then break end
		t [ i ] = tmp
		i = i + 1
	end
	
	return t
end

function fetch ( id , latest , earliest )
	local pl , num = getpl ( id )
	if type ( pl ) ~= "playlist" then return ferror ( "'fetch' called with invalid playlist" , 3 ) end
	latest = latest or pl.revision
	earliest = earliest or 0
	if type ( latest ) ~= "number" or type ( earliest ) ~= "number" then return ferror ( "Fetch called with bad revision" , 3 ) end
	if latest < 0 or latest > pl.revision or earliest < 0 or earliest > latest then return ferror ( "Fetch called with invalid revision" , 3 ) end

	return collapserev ( pl.revisions , latest , earliest ) , latest
end

function new ( name , playlistnumber )
	if playlistnumber and type ( playlistnumber ) ~= "number" then return ferror ( "'New Playlist' called with invalid playlistnumber" , 1 ) end
	if not tostring ( name ) then return ferror ( "'New Playlist' called with invalid name" , 1 ) end
	name = name or "" -- "Untitled Playlist"
	
	playlistnumber = playlistnumber or ( #vars.playlist + 1 )
	
	local pl = setmetatable ( {
			revisions = { [ 0 ] = { name = name , length = 0 } };
			index = playlistnumber ;
		} , {
			__index = function ( t , k )
				if k == "revision" then 
					return #t.revisions
				elseif type ( _M [ k ] ) == "function" and k ~= "new" then
					return function ( self , ... ) return _M [ k ] ( self , ... ) end
				else
					return playlistval ( t.revisions , k , t.revision , 0 )
				end 
			end ;
			__newindex = function ( playlist , k , v )
				updatelog ( "PLAYLIST newindex\t" .. k .. "\t" .. tostring ( v ) , 2 )
			end ;
			__len = function ( t ) -- FIX: Doesn't work on tables
				return t.length
			end ;
			__type = function ( t ) return "playlist" end ;
		}
	)
		
	vars.playlist [ playlistnumber ] = pl
	vars.playlist.revision = vars.playlist.revision + 1
	
	core.triggers.fire ( "playlist_create" , playlistnumber )
	
	return playlistnumber , name
end

function newrevision ( playlist , revision )
	local newrevision = playlist.revision + 1
	playlist.revisions [ newrevision ] = revision
	core.triggers.fire ( "playlist_newrevision" , getnum ( playlist ) , newrevision )
	return newrevision
end

function delete ( id )
	local pl , num = getpl ( id )
	if not pl then
		return ferror ( "'Delete playlist' called with invalid playlist" , 1 ) 
	end
	
	vars.playlist [ num ] = nil
	vars.playlist.revision = vars.playlist.revision + 1
	if pl == vars.softqueueplaylist then core.setsoftqueueplaylist ( vars.emptyplaylist ) end -- If deleted playlist was the soft queue
	
	core.triggers.fire ( "playlist_delete" , num )
	
	return true
end

function clear ( id )
	local pl , num = getpl ( id )
	if not pl then
		return ferror ( "'Clear playlist' called with invalid playlist" , 1 ) 
	end
	
	newrevision ( pl , { length = 0 } )
	
	core.triggers.fire ( "playlist_clear" , num )
	
	return true
end

function rename ( id , newname )
	local pl , num = getpl ( id )
	if not pl then
		return ferror ( "'Rename playlist' called with invalid playlist" , 1 ) 
	end
	
	newrevision ( pl , { name = newname } )
	
	return true
end

function randomise ( id )
	local pl , num = getpl ( id )
	if not pl then
		return ferror ( "'Randomise playlist' called with invalid playlist" , 1 ) 
	end
	
	newrevision ( pl , tblrandomise ( collapserev ( pl.revisions , pl.revision ) , pl.length , true ) )
	
	core.triggers.fire ( "playlist_sort" , num )
	
	return true
end

function sort ( id , eq )
	local pl , num = getpl ( id )
	if not pl then
		return ferror ( "'Sort playlist' called with invalid playlist" , 1 )
	end

	newrevision ( pl , tblstablesort ( collapserev ( pl.revisions , pl.revision ) , eq , true ) )
	
	core.triggers.fire ( "playlist_sort" , num )
	
	return true
end

core.triggers.register ( "playlist_create", function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Created playlist #" .. plnum .. ": '" .. pl.name .. "'" , 4 ) end , false , true )
core.triggers.register ( "playlist_delete", function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Deleted playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end , false , true )
core.triggers.register ( "playlist_clear", function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Cleared playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end , false , true )
core.triggers.register ( "playlist_sort", function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Sorted playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end , false , true )
core.triggers.register ( "playlist_newrevision", function ( plnum , revision ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Playlist #" .. plnum .. " (" .. pl.name .. ") has a new revision" , 4 ) end , false , true )
core.triggers.register ( "playlist_newrevision", function ( plnum , revision ) if plnum == vars.softqueueplaylist then core.setploffset ( 0 ) end end , false , true ) -- If it was the current soft queue playlist that changed, reset ploffset
