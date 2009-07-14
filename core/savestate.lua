--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp" , package.seeall )

-- Safe string
local function ss ( s )
	return string.format ( '%q' , s )
end

function core.savestate ( )
	local s = core._NAME .. "\t" .. core._VERSION .. " State File.\tCreated: " .. os.date ( ) .. "\n"
		.. "vars.rpt = " .. tostring ( vars.rpt ) .. ";\n"
		.. "vars.loop = " .. tostring ( vars.loop ) .. ";\n"
		.. "vars.softqueuepl = " .. vars.softqueuepl .. ";\n"
		.. "vars.ploffset = " .. vars.ploffset .. ";\n"
	
	local current = vars.queue [ 0 ]
	if current then core.item.additem ( current , -2 , 1 ) end -- If currently playing a song, add to start of hardqueue so its first up
	
	-- Playlists
	local i = -2
	while true do
		local pl = vars.playlist [ i ]
		if not pl then break end
		s = s .. "core.playlist.new(" .. ss ( pl.name ) .. "," .. i .. ")\n" -- Name in this line does nothing
			.. "vars.playlist[" .. i .. "].revisions[1]={length=" .. pl.length .. ";\n"
		local j = 1
		while true do
			local item = pl [ j ]
			if not item then break end
			s = s .. "\tcore.item.create(" .. ss ( item.typ ) .. "," .. ss ( item.source ) .. ");\n"
			j = j + 1
		end
		i = i + 1
		s = s .. '}\n'
	end
	
	-- History (played)
	s = s .. "vars.played = {revision=0;\n"
	local n
	if #vars.played > config.history then n = config.history else n = #vars.played end
	for i = 1 , n do
		s = s .. '\tcore.item.create(' .. string.format ( '%q' , vars.played [ i ].typ ) .. ',' .. string.format ( '%q' , vars.played [ i ].source ) .. ') ;\n'
	end
	s = s .. "};\n"
	
	-- Player
	local volume , mute = player.getvolume ( )
	s = s .. "player.setvolume(" .. volume .. "); player." .. ( ( mute and "" ) or "un" ) .. "mute();\n"
	
	-- Plugin specified things??
	
	local file, err = io.open ( config.statefile , "w+" )
	if err then 
		return ferror ( "Could not open state file: " .. err , 2 ) 
	end
	file:write ( s )
	file:flush ( )
	file:close ( )
	
	updatelog ( "State sucessfully saved" , 4 )
	
	return s , err
end

function core.restorestate ( )
	local file, err = io.open ( config.statefile )
	if file then -- Restoring State.
		local v = file:read ( )
		if not v then
			return ferror ( "Invalid state file" , 1 )
		end 
		local _ , _ , program , major , minor , inc = string.find ( v , "^([^%s]+)%s+(%d+)%.(%d+)%.(%d+)" )
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
		return ferror ( "Could not find state file: '" .. err .. "'" , 2 )
	end
	return true
end
	