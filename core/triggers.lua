--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pairs , pcall , setmetatable , tostring , unpack = ipairs , pairs , pcall , setmetatable , tostring , unpack
local tblremove = table.remove
local coroutinewrap , coroutineyield = coroutine.wrap , coroutine.yield
local ostime = os.time

module ( "lomp.core.triggers" , package.see ( lomp ) )

local callbacks = {
	quit = { { func = function ( ) updatelog ( "Quiting" , 4 ) end , instant = false } } ;

	loop = { { func = function ( loop ) updatelog ( "loop set to " .. tostring ( loop ) , 5 ) end } } ;
	ploffset = { { func = function ( ploffset ) updatelog ( "ploffset set to " .. ploffset , 5 ) end } } ;
	softqueueplaylist = { { func = function ( softqueueplaylist ) updatelog ( "softqueueplaylist set to playlist #" .. softqueueplaylist , 5 ) end } } ;
	rpt = { { func = function ( rpt ) updatelog ( "repeat set to " .. tostring ( rpt ) , 5 ) end } } ;
	
	playlist_create = { { func = function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Created playlist #" .. plnum .. ": '" .. pl.name .. "'" , 4 ) end } } ;
	playlist_delete = { { func = function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Deleted playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end } } ;
	playlist_clear = { { func = function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Cleared playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end } } ;
	playlist_sort = { { func = function ( plnum ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Sorted playlist #" .. plnum .. " (" .. pl.name .. ")" , 4 ) end } } ;
	playlist_newrevision = { { func = function ( plnum , revision ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Playlist #" .. plnum .. " (" .. pl.name .. ") has a new revision" , 4 ) end } ;
		{ func = function ( plnum , revision ) if plnum == vars.softqueueplaylist then core.setploffset ( 0 ) end end } } ; -- If it was the current soft queue playlist that changed, reset ploffset
	
	item_add = { { func = function ( plnum , position , numobjects ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Added " .. numobjects .. " item(s) to playlist #" .. plnum .. " (" .. pl.name .. ") at position #" .. position , 4 ) end } } ;
	item_remove = { { func = function ( plnum , position ) local pl = core.playlist.getplaylist ( plnum ); updatelog ( "Removed item from playlist #" .. plnum .. " (" .. pl.name .. ") position #" .. position --[[.. " Source: " .. pl [ position ].source]]  , 4 ) end } } ;
	
	playback_stop = { } ; -- ( type , source , offset )
	playback_pause = { } ; -- ( offset )
	playback_unpause = { } ; -- ( )
	playback_startsong = { { func = function ( typ , source ) vars.queue [ 0 ].laststarted = ostime ( ) end , instant = true } } ;
	playback_seek = { } ;
	
	player_abouttofinish = { { func = function ( ) updatelog ( "About to finish song" , 5 ) end } } ;
	player_finished = { } ;
}

function register ( callback , func , name , instant )
	local t = callbacks [ callback ]
	local pos = #t + 1
	t [ pos ] = { func = func , instant = instant , name = name }
	t [ name ] = pos
	return pos
end

function unregister ( callback , id )
	local t = callbacks [ callback ]
	if not t then return ferror ( "Deregister callback called with invalid callback" , 1 ) end
	
	local pos
	if type ( id ) == "string" then
		pos = t [ id ]
		t [ id ] = nil
	elseif type ( id ) == "number" then
		pos = id
	end
	if not pos then
		return ferror ( "Deregister callback called with invalid position/name" , 1 )
	end
	
	tblremove ( t , pos )
	
	return true
end

local queue , qn = { } , 1 -- Qn is the next empty queue slot.
local processqueue = coroutinewrap ( function ( )
	local i = 1
	while true do
		if i < qn then
			local ok , err = pcall ( unpack ( queue [ i ] ) )
			if not ok then updatelog ( err ,  2 ) end
			queue [ i ] = nil
			i = i + 1
		else
			coroutineyield ( true )
		end
	end
end )

function fire ( callback , ... )
	for i , v in ipairs ( callbacks [ callback ] ) do
		if v.instant then -- Fire instant callbacks right now
			local ok , err = pcall ( v.func , ... )
			if not ok then updatelog ( err ,  2 ) end
		else -- Otherwise add them to the trigger queue
			queue [ qn ] = { v.func , ... }
			qn = qn + 1
		end
	end
end

addstep ( processqueue )
