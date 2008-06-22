--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core" , package.see ( lomp ) )

function core.savestate ( )
	local s = core._NAME .. "\t" .. core._VERSION .. " State File.\tCreated: " .. os.date ( ) .. "\n"
	s = s .. "rpt = " .. tostring ( vars.rpt ) .. ";\n"
	s = s .. "loop = " .. tostring ( vars.loop ) .. ";\n"
	-- Queue
	s = s .. "softqueuepl = " .. vars.softqueuepl .. ";\n"
	s = s .. "ploffset = " .. vars.ploffset .. ";\n"
	s = s .. "hardqueue = {\n"
	for i = 1 , ( #vars.hardqueue ) do -- Not current song
		s = s .. "\t{typ = '" .. vars.hardqueue [ i ].typ .. "';source = '" .. vars.hardqueue [ i ].source .. "'};\n"
	end
	s = s .. "};\n"
	
	-- Playlists
	s = s .. "pl = {\n"
	for i = 0 , #vars.pl do
		s = s .. "\t[" .. i .. "] = { revision = 0 ; name = '" .. vars.pl [ i ].name .. "';\n"
		for j , entry in ipairs ( vars.pl [ i ] ) do
			s = s .. "\t\t{typ = '" .. entry.typ .. "';source = '" .. entry.source .. "'};\n"
		end
		s = s .. "\t};\n"
	end
	s = s .. "};\n"
	
	-- History (played)
	s = s .. "played = {\n"
	local n
	if #vars.played > config.history then n = config.history else n = #vars.played end
	for i = 1 , n do
		s = s .. "\t{typ = '" .. vars.played [ i ].typ .. "';source = '" .. vars.played [ i ].source .. "'};\n"
	end
	s = s .. "};\n"
	
	--- Tag lib?
	
	-- Plugin specified things??
	
	
	local file, err = io.open( config.statefile , "w+" )
	if err then 
		updatelog ( "Could not open state file: '" .. err , 2 ) 
		return false , "Could not open state file: '" .. err
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
			updatelog ( "Invalid state file" , 1 )
			return false , "Invalid state file"
		end 
		local _ , _ , program , major , minor , inc = string.find ( v , "^([^%s]+)%s+(%d+)%.(%d+)%.(%d+)" )
		if type ( program ) == "string" and program == "LOMP" and tonumber ( major ) <= core._MAJ and tonumber ( minor ) <= core._MIN and tonumber ( inc ) <= core._INC then
			local s = file:read ( "*a" )
			file:close ( )
			local f , err = loadstring ( s , "Saved State" )
			if not f then
				updatelog ( "Could not load state file: " .. err , 1 )
				return false , "Could not load state file: " .. err
			end
			local t = { }
			setfenv ( f , t )
			f ( )
			table.inherit ( vars , t , true )
		else
			file:close ( )
			updatelog ( "Invalid state file" , 1 )
			return false , "Invalid state file"
		end
	else
		updatelog ( "Could not find state file: '" .. err .. "'" , 2 )
		return false , "Could not find state file: '" .. err .. "'"
	end
	return true
end
	