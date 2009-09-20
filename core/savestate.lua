--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local loadstring , setfenv , tostring , tonumber , type = loadstring , setfenv , tostring , tonumber , type
local tblconcat = table.concat
local ioopen = io.open
local osdate = os.date
local strfind , strformat = string.find , string.format

module ( "lomp" )

function core.savestate ( )
	local s = { 
		core._NAME .. "\t" .. core._VERSION .. " State File.\tCreated: " .. osdate ( ) .. "\n" ;
		"local cpn , cic = core.playlist.new , core.item.create" ;
		"vars.rpt = " .. tostring ( vars.rpt ) .. ";" ;
		"vars.loop = " .. tostring ( vars.loop ) .. ";" ;
		"vars.softqueueplaylist = " .. vars.softqueueplaylist .. ";" ;
		"vars.ploffset = " .. vars.ploffset .. ";" ;
	}
	
	local current = vars.queue [ 0 ]
	if current then core.item.additem ( core.playlist.getnum ( vars.hardqueue ) , 1 , current ) end -- If currently playing a song, add to start of hardqueue so its first up
	
	-- Playlists
	local i = -2
	while true do
		local pl = vars.playlist [ i ]
		if not pl then break end
		s [ #s + 1 ] = strformat ( 'cpn(%q,%d);' , pl.name , i )-- Name in this line does nothing
		s [ #s + 1 ] = "vars.playlist[" .. i .. "].revisions[1]={length=" .. pl.length .. ";"
		local j = 1
		while true do
			local item = pl [ j ]
			if not item then break end
			s [ #s + 1 ] = strformat ( "\tcic(%q,%q,%d);" , item.typ , item.source , item.created )
			j = j + 1
		end
		i = i + 1
		s [ #s + 1 ] = "}"
	end
	
	-- History (played)
	s [ #s + 1 ] = "vars.played = {revision=0;"
	local n
	if #vars.played > config.history then n = config.history else n = #vars.played end
	for i = 1 , n do
		local item = vars.played [ i ]
		s [ #s + 1 ] = strformat ( "\tcic(%q,%q,%q);" , item.typ , item.source , item.created )
	end
	s [ #s + 1 ] = "};"
	
	-- Player
	local volume , mute = player.getvolume ( )
	s [ #s + 1 ] = "player.setvolume(" .. volume .. "); player." .. ( ( mute and "" ) or "un" ) .. "mute();"
	
	-- Plugin specified things??
	
	local s = tblconcat ( s , "\n" )
	
	local file, err = ioopen ( config.statefile , "w+" )
	if err then 
		return ferror ( "Could not open state file: " .. err , 2 ) 
	end
	file:write ( s , "\n" )
	file:flush ( )
	file:close ( )
	
	updatelog ( "State sucessfully saved" , 4 )
	
	return s , err
end

function core.restorestate ( )
	local file, err = ioopen ( config.statefile )
	if file then -- Restoring State.
		local v = file:read ( )
		if not v then
			return ferror ( "Invalid state file" , 1 )
		end 
		local _ , _ , program , major , minor , inc = strfind ( v , "^([^%s]+)%s+(%d+)%.(%d+)%.(%d+)" )
		if type ( program ) == "string" and program == "LOMP" and tonumber ( major ) <= core._MAJ and tonumber ( minor ) <= core._MIN and tonumber ( inc ) <= core._INC then
			local s = file:read ( "*a" )
			file:close ( )
			local f , err = loadstring ( s , "Saved State" )
			if not f then
				return ferror ( "Could not load state file: " .. err , 1 )
			end
			local t = { core = core , vars = vars , player = player } -- To make functions available - security issues?
			setfenv ( f , t )
			f ( )
		else
			file:close ( )
			return ferror ( "Invalid state file" , 1 )
		end
	else
		return ferror ( "cannot open " .. err , 2 )
	end
	return true
end
	