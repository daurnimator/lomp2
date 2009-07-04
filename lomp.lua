#! /usr/bin/env lua

--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

if _VERSION ~= "Lua 5.1" then --TODO: Override?
	error ( "This program needs lua 5.1 to work." )
end

module ( "lomp" , package.seeall )

do 
	log = ""

	-- Output Loading Annoucement
	local str = "LOMP Loading " .. os.date ( "%c" ) .. "\n"
	print ( "\n" .. str )

	-- Load Configuration
	require "core.config"
	
	-- Log File Stuff
	local file , err = io.open ( config.logfile , "w+" )
	if err then error ( "Could not open/create log file: '" .. err .. "'\n" ) end
	file:write ( str .. log .. "\n")
	file:flush ( )
	file:close ( )
	
	log = nil
end
	
function updatelog ( data , level , env )
	env = env or ( getfenv and getfenv ( ) ) or _G
	data = env.tostring ( data )
	if not level then level = 2 end
	
	if level == 0 then data = "Fatal error: \t\t" .. data
	elseif level == 1 then data = "NonFatal error: \t" .. data 
	elseif level == 2 then data = "Warning: \t\t" .. data
	elseif level == 3 then data = "Message: \t\t" .. data
	elseif level == 4 then data = "Confirmation: \t\t" .. data
	elseif level == 5 then data = "Debug: \t\t\t" .. data
	end
	
	data = env.os.time ( ) .. ": \t" .. data
	if level <= env.config.verbosity then env.io.stderr:write ( data .. "\n" ) end --env.print ( data ) end
	
	data = data .. "\n"
	
	local file , err = env.io.open ( env.config.logfile , "a+" )
	if err then error ( data .. "Could not open log file: '" .. err .. "'\n" ) end
	file:seek ( "end" )
	file:write ( data )
	file:flush ( )
	file:close ( )
	if level == 0 then os.exit( 1 ) end
	return true
end
function ferror ( data , level , env )
	if not env or not env.updatelog then env = _G end
	if updatelog and not env.updatelog then env.updatelog = updatelog end
	env.updatelog ( data , level , env )
	return false , data
end

require "general"
require "lomp-core"

require "modules.metadata"
require "modules.albumart"

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

-- Get ready for multi-threading
require "lanes"
local timeout = 0.001
lindas = { }

do 
	local func = lanes.gen ( "base table string package os math io" , { ["globals"] = { config = config , updatelog = updatelog , ferror = ferror } } , loadfile ( "modules/server.lua" ) )
	local linda = lanes.linda ( )
	lindas [ #lindas + 1 ] = linda
	
	lane = func ( linda , config.address , config.port )
end

-- Plugin Time!
updatelog ( "Loading plugins." , 3 )
for i , v in ipairs ( config.plugins ) do
	dir = "plugins/" .. v .. "/"
	local plugin , err = loadfile ( dir .. v .. ".lua" )
	if not plugin then
		ferror ( err , 2 )
	else
		setfenv ( plugin , getfenv ( 1 ) )
		local name , version = v , ""
		name , version = plugin ( )
		updatelog ( "Loaded plugin: '" .. name .. "' Version " .. version , 3 )
	end
end
updatelog ( "All Plugins Loaded" , 3 )

-- Function/Variable finders.
local function buildMetatableCall ( ref )
	return { 
	__index = function ( t , k )
		if type ( ref [ k ] ) == "table" then
			local val = newproxy ( true ) -- Undocumented lua function
			for k , v in pairs ( buildMetatableCall ( ref [ k ] ) ) do
				getmetatable ( val ) [ k ] = v
			end
			return val
		elseif type ( ref [ k ] ) == "function" then
			return ref [ k ]
		else
			return nil
		end
	end , }
end
local function buildMetatableGet ( ref )
	return {
		__index = function ( t , k )
			if type ( ref [ k ] ) == "table" then
				local val = newproxy ( true ) -- Undocumented lua function
				for k , v in pairs ( buildMetatableGet ( ref [ k ] ) ) do
					getmetatable ( val ) [ k ] = v
				end
				return val
			elseif type ( ref [ k ] ) == "function" then
				return string.dump ( ref [ k ] )
			else
				return ref [ k ]
			end
		end , 
		__len = function ( )
			return #ref
		end ,
		__pairs = function ( t )
			return pairs ( ref )
		end ,
		__type = function ( t )
			return "table"
		end ,
	}
end

-- Initialisation finished.
updatelog ( "LOMP Loaded " .. os.date ( "%c" ) , 3 )

require "lomp-debug" -- TODO: remove debug

local i = 1
while true do
	-- Cmds
	local val , key = lindas [ i ]:receive ( timeout , "cmd" )
	if type ( val ) == "table" and type ( val.cmd ) == "string" and not ( val.parameters and type ( val.parameters ) ~= "table" ) then
		local fn , fail = loadstring ( "return " .. val.cmd )
		if fail then -- Check for compilation errors (eg, syntax)
			lindas [ i ]:send ( timeout , "returncmd" , { false , fail } )
		else
			setfenv ( fn , setmetatable ( { } , buildMetatableCall( _M ) ) )
			local ok , func = pcall ( fn )
			if not ok then -- Check for no errors while finding function
				lindas [ i ]:send ( timeout , "returncmd" , { false , func } )
			elseif not func then -- Make sure function was found, func already has to be a function or nil, so we only need to exclude the nil case
				lindas [ i ]:send ( timeout , "returncmd" , { false , "Not a function" } )
			else
				local function interpret ( ok , err , ... )
					if not ok then return false , err
					else return ok , { err , ... } end
				end
				lindas [ i ]:send ( timeout , "returncmd" , { interpret ( pcall ( func , unpack ( val.parameters or { } ) ) ) } )
			end			
		end
	end
	
	-- Vars
	local val , key = lindas [ i ]:receive ( timeout , "var" )
	if type ( val ) == "string" then
		local fn , fail = loadstring ( "return " .. val )
		if fail then -- Check for compilation errors
			lindas [ i ]:send ( timeout , "returnvar" , { false , fail } )
		else
			setfenv ( fn , setmetatable ( { } , buildMetatableGet ( _M ) ) )
			local ok , var = pcall ( fn )
			if not ok then -- Check for no errors while finding function
				lindas [ i ]:send ( timeout , "returnvar" , { false , var } )
			elseif type ( var ) ~= "string" and type ( var ) ~= "table" and type ( var ) ~= "number" and type ( var ) ~= "boolean" and var ~= nil then -- Make sure function was found, var already has to be a string, number or nil
				lindas [ i ]:send ( timeout , "returnvar" , { false , "Not a variable, tried to return value of: " .. type ( var ) } )
			else
				lindas [ i ]:send ( timeout , "returnvar" , { ok , var } )
			end
		end
	end
	
	if i == #lindas then i = 1 else i = i + 1 end
end
