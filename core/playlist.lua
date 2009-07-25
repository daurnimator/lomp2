--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.playlist" , package.see ( lomp ) )

require "core.triggers"

function getplaylist ( playlistnum )
	if type ( playlistnum ) ~= "number" or not vars.playlist [ playlistnum ] then
		return false
	else
		return vars.playlist [ playlistnum ]
	end	
end

function getnum ( playlist )
	return playlist.index
end

local function playlistval ( revisions , k , latest , earliest )
	if type ( k ) == "number" and k > playlistval ( revisions , "length" , latest , 0 ) then return nil end
	
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

function fetch ( num , latest , earliest )
	local pl = getplaylist ( num )
	if not pl then return false , "Invalid playlist" end
	latest = latest or pl.revision
	earliest = earliest or 0
	if type ( latest ) ~= "number" or type ( earliest ) ~= "number" then return false , "Bad Revision" end
	if latest < 0 or latest > pl.revision or earliest < 0 or earliest > latest then return false , "Invalid Revision" end

	return collapserev ( pl.revisions , latest , earliest ) , latest
end

function new ( name , playlistnumber )
	if playlistnumber and type ( playlistnumber ) ~= "number" then return ferror ( "'New Playlist' called with invalid playlistnumber" , 1 ) end
	if not tostring ( name ) then return ferror ( "'New Playlist' called with invalid name" , 1 ) end
	name = name or "" -- "Untitled Playlist"
	
	playlistnumber = playlistnumber or ( #vars.playlist + 1 )
	
	local pl = setmetatable ( { 
			revisions = { [ 0 ] = { name = name , length = 0 } } ;
			index = playlistnumber ;
		} , {
			__index = function ( t , k )
				if k == "revision" then 
					return #t.revisions 
				elseif type ( _M [ k ] ) == "function" and k ~= "new" then
					return function ( self , ... ) return _M [ k ] ( getnum ( self ) , ... ) end
				else 
					return playlistval ( t.revisions , k , #t.revisions , 0 )
				end 
			end ;
			__newindex = function ( t , k , v )
				print ( "PLAYLIST newindex" , t , k , v )
			end ;
			__len = function ( t ) -- FIX: Doesn't work on tables
				return t.length
			end ;
		}
	)
		
	vars.playlist [ playlistnumber ] = pl
	vars.playlist.revision = vars.playlist.revision + 1
	
	triggers.fire ( "playlist_create" , playlistnumber )
	
	return playlistnumber , name
end

function delete ( num )
	local pl = getplaylist ( num )
	if not pl then
		return ferror ( "'Delete playlist' called with invalid playlist" , 1 ) 
	end
	
	local name = pl.name
	vars.playlist [ num ] = nil
	vars.pl.revision = vars.pl.revision + 1
	if pl == vars.queue.softqueueplaylist then vars.queue.softqueueplaylist = -1 end -- If deleted playlist was the soft queue
	
	triggers.fire ( "playlist_delete" , num )
	
	return true
end

function clear ( num )
	local pl = getplaylist ( num )
	if not pl then
		return ferror ( "'Clear playlist' called with invalid playlist" , 1 ) 
	end
	
	pl.revisions [ pl.revision + 1 ] = { length = 0 }
	
	triggers.fire ( "playlist_clear" , num )
	
	return true
end

function rename ( num , newname )
	local pl = getplaylist ( num )
	if not pl then
		return ferror ( "'Rename playlist' called with invalid playlist" , 1 ) 
	end
	
	pl.revisions [ pl.revision + 1 ] = { name = newname }
	
	return true
end

function randomise ( num )
	local pl = getplaylist ( num )
	if not pl then
		return ferror ( "'Randomise playlist' called with invalid playlist" , 1 ) 
	end
	
	pl.revisions [ pl.revision + 1 ] = table.randomise ( collapserev ( pl.revisions , pl.revision ) , pl.length , true )
	
	triggers.fire ( "playlist_sort" , num )
	
	return true
end

function sort ( num , eq )
	local pl = getplaylist ( num )
	if not pl then
		return ferror ( "'Sort playlist' called with invalid playlist" , 1 )
	end

	pl.revisions [ pl.revision + 1 ] = table.stablesort ( collapserev ( pl.revisions , pl.revision ) , eq , true )
	
	triggers.fire ( "playlist_sort" , num )
	
	return true
end
