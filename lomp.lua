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
package.path = package.path .. ";./libs/?.lua;./libs/?/init.lua"

module ( "lomp" , package.seeall )

local verbosity = 4

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
	env = env or _G
	
	if not level then level = 2 end
	
	if level == 0 then data = "Fatal error: \t\t" .. data
	elseif level == 1 then data = "NonFatal error: \t" .. data 
	elseif level == 2 then data = "Warning: \t\t" .. data
	elseif level == 3 then data = "Message: \t\t" .. data
	elseif level == 4 then data = "Confirmation: \t\t" .. data
	end
	
	data = env.os.time ( ) .. ": \t" .. data
	if level <= verbosity then env.print ( data ) end
	
	data = data .. "\n"
	
	local file , err = env.io.open ( env.config.logfile , "a+" )
	if err then error ( data .. "Could not open log file: '" .. err .. "'\n" ) end
	file:seek ( "end" )
	file:write ( data )
	file:flush ( )
	file:close ( )
	if level == 0 then error ( data ) end
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

require "modules.tags"
--require "modules.server" -- Now a lane
require "modules.albumart"

do -- Restore State
	local ok , err = core.restorestate ( )
	if not ok then
		core.playlist.new ( "Library" , 0 ) -- Create Library (Just playlist 0)
	end
end

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "lanes" -- Loads up lanes (multithreading)
local lindas = { }
function newlinda ( )
	local pos = #lindas + 1
	lindas [ pos ] = lanes.linda ( )
	return lindas [ pos ] , pos
end

updatelog ( "Loading plugins." , 3 )
for i , v in ipairs ( config.plugins ) do
	dir = "plugins/" .. v .. "/"
	local plugin = loadfile ( dir .. v .. ".lua" )
	setfenv ( plugin , getfenv ( 1 ) )
	local name , version = v , ""
	name , version = plugin ( )
	updatelog ( "Loaded plugin: '" .. name .. "' Version " .. version , 3 )
end
updatelog ( "All Plugins Loaded" , 3 )

updatelog ( "LOMP Loaded " .. os.date ( "%c" ) , 3 )

require "lomp-debug"

-- Server
func = lanes.gen ( "base,package,math,table,string,io,os" , { globals = { linda = newlinda ( ) , updatelog = updatelog , ferror = ferror , config = config } } , function ( ... ) package.path = package.path .. ";./libs/?.lua;./libs/?/init.lua" require "modules.server" lane ( ... ) end )
serverlane = func ( config.address , config.port )

local i = 1
local timeout = 0.005
while true do
	do -- Check for cmds to run
		local val , key = lindas [ i ]:receive ( timeout , "cmd" )		
		if type ( val ) == "table" and type ( val.cmd ) == "string" and not ( val.params and type ( val.params ) ~= "table" ) then
			local function buildMetatable ( ref )
				return { __index = function ( t , k )
					if type ( ref [ k ] ) == "function" then
						return ref [ k ]
					elseif type ( ref [ k ] ) == "table" then
						local val = newproxy ( true ) -- Undocumented lua function
						for k , v in pairs ( buildMetatable ( ref [ k ] ) ) do
						     getmetatable ( val ) [ k ] = v
						end
						return val
					else
						return nil
					end
				end , }
			end
			
			local fn , fail = loadstring ( "return " .. val.cmd )
			
			if fail then -- Check for compilation errors (eg, syntax)
				lindas [ i ]:send ( timeout , "returnedcmd" , { false , fail } )
			else
				setfenv ( fn , setmetatable ( { } , buildMetatable ( _M ) ) )
				local ok , func = pcall ( fn )
				if not ok then -- Check for no errors while finding function
					lindas [ i ]:send ( timeout , "returnedcmd" , { false , func } )
				elseif not func then -- Make sure function was found, func already has to be a function or nil, so we only need to exclude the nil case
					lindas [ i ]:send ( timeout , "returnedcmd" , { false , "Not a function" } )
				else
					local function interpret ( ok , err , ... )
						if not ok then return ok , err
						else return ok , { err , ... } end
					end
					lindas [ i ]:send ( timeout , "returnedcmd" , { interpret ( pcall ( func , unpack ( val.params or { } ) ) ) } )
				end
			end
		end
	end
	do -- Check for var gets.
		local val , key = lindas [ i ]:receive ( timeout , "var" )		
		if type ( val ) == "string" then
			local function buildMetatable ( ref )
				return { __index = function ( t , k )
					if type ( ref [ k ] ) == "table" then
						local val = newproxy ( true ) -- Undocumented lua function
						for k , v in pairs ( buildMetatable ( ref [ k ] ) ) do
						     getmetatable ( val ) [ k ] = v
						end
						return val
					else
						return ref [ k ]
					end
				end , 
				__len = function ()
					return #ref
				end , }
			end
			local fn , fail = loadstring ( "return " .. val )
			if fail then -- Check for compilation errors
				lindas [ i ]:send ( timeout , "returnedvar" , { false , fail } )
			else
				setfenv ( fn , setmetatable ( { } , buildMetatable ( _M ) ) )
				local ok , var = pcall ( fn )
				if not ok then -- Check for no errors while finding function
					lindas [ i ]:send ( timeout , "returnedvar" , { false , var } )
				elseif type ( var ) ~= "string" and type ( var ) ~= "number" and type ( var ) ~= "boolean" and var ~= nil then -- Make sure function was found, var already has to be a string, number or nil
					lindas [ i ]:send ( timeout , "returnedvar" , { false , "Not a variable, tried to return value of: " .. type ( var ) } )
				else
					lindas [ i ]:send ( timeout , "returnedvar" , { ok , var } )
				end
			end
		end
	end
	i = i + 1 
	if i > #lindas then i = 1 end
end
