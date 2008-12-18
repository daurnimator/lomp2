--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp" , package.seeall )

function core.savestate ( )
	local s = core._NAME .. "\t" .. core._VERSION .. " State File.\tCreated: " .. os.date ( ) .. "\n"
	s = s .. "vars = {\n"
	s = s .. table.recurseserialise ( vars , "\t" )
	s = s .. "};\n"
	
	local file, err = io.open( config.statefile , "w+" )
	if err then 
		return ferror ( "Could not open state file: '" .. err , 2 ) 
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
			local t = { core = core } -- To make functions available - security issues?
			setfenv ( f , t )
			f ( )
			table.inherit ( _M , t , true )
		else
			file:close ( )
			return ferror ( "Invalid state file" , 1 )
		end
	else
		return ferror ( "Could not find state file: '" .. err .. "'" , 2 )
	end
	return true
end
	