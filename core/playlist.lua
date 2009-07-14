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

function getnum ( playlistnum )
	if type ( playlistnum ) ~= "number" or not vars.playlist [ playlistnum ] then
		return false
	else
		return vars.playlist [ playlistnum ]
	end	
end

local function playlistrev ( revisions , latest , earliest )
	earliest = earliest or 0
	
	return setmetatable ( { } , { __index = function ( t , k )
		for i = latest , earliest , -1 do
			local v = revisions [ i ] [ k ]
			if v then return v end
		end
	end } )
end

local function collapserev ( revisions , latest , earliest )
	local proxy = playlistrev ( revisions , latest , earliest )
	local t , i = { } , 1
	while true do
		local tmp = proxy [ i ]
		if not tmp then break end
		t [ i ] = tmp
		i = i + 1
	end
	t.length = proxy.length
	t.name = proxy.name
	return t
end

function fetch ( num , latest , earliest )
	local pl = getnum ( num )
	if not pl then return false , "Invalid playlist" end
	latest = latest or pl.revision
	earliest = earliest or 0
	if type ( latest ) ~= "number" or type ( earliest ) ~= "number" then return false , "Bad Revision" end
	if latest < 0 or latest > pl.revision or earliest < 0 or earliest > latest then return false , "Invalid Revision" end
	local t = collapserev ( pl.revisions , latest , earliest )
	t.revision = latest
	return t
end

function new ( name , playlistnumber )
	if playlistnumber and type ( playlistnumber ) ~= "number" then return ferror ( "'New Playlist' called with invalid playlistnumber" , 1 ) end
	if not tostring ( name ) then return ferror ( "'New Playlist' called with invalid name" , 1 ) end
	name = name or "" -- "Untitled Playlist"
	
	playlistnumber = playlistnumber or ( #vars.playlist + 1 )
	
	local mt = { }
	local revisions = { [ 0 ] = { name = name , length = 0 } }
	local pl = setmetatable ( { revisions = revisions } , mt )
	
	mt.__index = function ( t , k ) if k == "revision" then return #pl.revisions else return playlistrev ( revisions , pl.revision , 0 ) [ k ] end end
	mt.__newindex = function ( t , k , v )
		print("PLAYLIST newindex",t,k,v )
	end
	
	vars.playlist [ playlistnumber ] = pl
	vars.playlist.revision = vars.playlist.revision + 1
	
	triggers.triggercallback ( "playlist_create" , playlistnumber , pl )
	
	return playlistnumber , name
end

function delete ( num )
	local pl = getnum ( num )
	if not pl then
		return ferror ( "'Delete playlist' called with invalid playlist" , 1 ) 
	end
	
	local name = pl.name
	vars.playlist [ num ] = nil
	vars.pl.revision = vars.pl.revision + 1
	if pl == vars.queue.softqueuepl then vars.queue.softqueuepl = -1 end -- If deleted playlist was the soft queue
	
	triggers.triggercallback ( "playlist_delete" , num , pl )
	
	return num
end

function clear ( num )
	local pl = getnum ( num )
	if not pl then
		return ferror ( "'Clear playlist' called with invalid playlist" , 1 ) 
	end
	
	pl.revisions = { [ 0 ] = { name = pl.name , length = 0 } }
	
	triggers.triggercallback ( "playlist_clear" , num , pl )
	
	return pl
end

function randomise ( num )
	local pl = getnum ( num )
	if not pl then
		return ferror ( "'Randomise playlist' called with invalid playlist" , 1 ) 
	end
	
	pl.revisions [ #pl.revisions + 1 ] = table.randomise ( collapserev ( pl.revisions , pl.revision ) , pl.length )
	
	triggers.triggercallback ( "playlist_sort" , num , pl )
	
	return true
end

function sort ( num , eq )
	local pl = getnum ( num )
	if not pl then
		return ferror ( "'Sort playlist' called with invalid playlist" , 1 )
	end

	pl.revisions [ #pl.revisions + 1 ] = table.stablesort ( collapserev ( pl.revisions , pl.revision ) , eq )
	
	triggers.triggercallback ( "playlist_sort" , num , pl )
	
	return true
end
