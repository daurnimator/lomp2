#! /usr/bin/env lua

--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

if _VERSION ~= "Lua 5.1" then --TODO: Override?
	error ( "This program needs lua 5.1 to work." )
end

require "general"

local collectgarbage , getfenv , getmetatable , ipairs , loadstring , loadfile , newproxy , pairs , pcall , require , setmetatable , setfenv , tostring , type = collectgarbage , getfenv , getmetatable , ipairs , loadstring , loadfile , newproxy , pairs , pcall , require , setmetatable , setfenv , tostring , type
local osdate , osexit , ostime = os.date , os.exit , os.time
local iotype , ioopen , iowrite , iostderr = io.type , io.open , io.write , io.stderr
local tblconcat = table.concat

local _G = _G

require "lgob.gobject" -- glib is loaded as part of gobject
local glib = glib

module ( "lomp" )

quit = false

do 
	log = ""

	-- Output Loading Annoucement
	local str = "LOMP is loading " .. osdate ( "%c" ) .. "\n"
	iowrite ( "\n" , str , "\n" )

	-- Load Configuration
	require "core.config"
	
	-- Log File Stuff
	local file , err = ioopen ( config.logfile , "w+" )
	if err then error ( "Could not open/create log file: '" .. err .. "'\n" ) end
	file:write ( str .. log .. "\n")
	file:flush ( )
	file:close ( )
	
	log = nil
end

local function openlogfile ( )
	local logfilehandle , err = ioopen ( config.logfile , "a+" )
	if err then error ( data .. "Could not open log file: '" .. err .. "'\n" ) end
	logfilehandle:setvbuf ( "no" )
	return logfilehandle
end
local logfilehandle = openlogfile ( )

local levels = {
	[ 0 ] = "Fatal error: \t" ;
	"NonFatal error: " ;
	"Warning: \t" ;
	"Message: \t" ;
	"Confirmation: \t" ;
	"Debug: \t\t" ;
}

function updatelog ( data , level )
	if not level then level = 2 end
	
	local datatbl = { ostime ( ) .. ": " , levels [ level ] , tostring ( data ) }
	
	local msg = tblconcat ( datatbl , "\t" )
	
	if level <= config.verbosity then iostderr:write ( msg , "\n" ) end
	if not iotype ( logfilehandle ) or iotype ( logfilehandle ) == "closed" then
		logfilehandle = openlogfile ( )
	end
	
	logfilehandle:seek ( "end" )
	logfilehandle:write ( msg , "\n" )
	
	if level == 0 then osexit ( 1 ) end
	
	return true
end
-- A macro to log an error and return false and an error.
function ferror ( data , level )
	updatelog ( data , level )
	return false , data
end

-- Setup main loop:
mainloop = glib.MainLoop.new ( )
local steps = { }
-- Add a step to the main loop.
-- Duplicate steps not allowed, returns false if the step already exists.
function addstep ( func )
	for i , v in ipairs ( steps ) do
		if v == func then return false end
	end
	steps [ #steps + 1 ] = func
	
	glib.timeout_add ( glib.PRIORITY_DEFAULT , 40 , func )
	return true
end

require "lomp-debug" -- TODO: remove debug

require "lomp-core"

require "modules.metadata"
require "modules.albumart"
require "modules.eventserver"
require "modules.filter"

-- Plugin Time!
updatelog ( "Loading plugins." , 3 )
for i , v in ipairs ( config.plugins ) do
	local dir = "plugins/" .. v .. "/"
	local plugin , err = loadfile ( dir .. v .. ".lua" )
	if not plugin then
		ferror ( "Could not load plugin '" .. v .. "' : " .. err , 1 )
	else
		setfenv ( plugin , setmetatable ( { dir = dir , lomp = lomp } , { __index = _G } ) )
		
		local name , version , ok = v , ""
		ok , name , version = pcall ( plugin )
		
		if ok then
			updatelog ( "Loaded plugin: '" .. name .. "' Version " .. version , 3 )
		else
			ferror ( "Could not load plugin '" .. v .. "': " .. ( name or "" ) , 1 )
		end
	end
end
updatelog ( "Plugins Loaded" , 3 )

 -- Function/Variable finders.
local function buildMetatableCall ( ref )
	return { 
		__index = function ( t , k )
			local newref = ref [ k ]
			if type ( newref ) == "table" or type ( newref ) == "userdata" then
				local val = newproxy ( true ) -- Undocumented lua function
				local mt = getmetatable ( val )
				for k , v in pairs ( buildMetatableCall ( newref ) ) do
					mt [ k ] = v
				end
				return val
			elseif type ( newref ) == "function" then
				return newref
			else
				return nil
			end
		end , 
	}
end

local function buildMetatableGet ( ref )
	return {
		__index = function ( t , k )
			local newref = ref [ k ]
			if type ( newref ) == "table" or type ( newref ) == "userdata" then
				local val = newproxy ( true ) -- Undocumented lua function
				local mt = getmetatable ( val )
				for k , v in pairs ( buildMetatableGet ( newref ) ) do
					mt [ k ] = v
				end
				return val
			elseif type ( newref ) == "function" then
				--return string.dump ( newref )
				return nil
			else -- string, boolean, number, nil
				return newref
			end
		end ;
		__len = function ( )
			return #ref
		end ;
		__pairs = function ( t )
			return pairs ( ref )
		end ;
		__type = function ( t )
			return type ( ref )
		end ;
	}
end

function cmd ( cmd , ... )
	local fn , fail = loadstring ( "return " .. cmd )
	if fail then -- Check for compilation errors (eg, syntax)
		return false , fail
	else
		setfenv ( fn , setmetatable ( { } , buildMetatableCall ( _M ) ) )
		local ok , func = pcall ( fn )
		if not ok then -- Check for no errors while finding function
			return false , func
		elseif not func then -- Make sure function was found, func already has to be a function or nil, so we only need to exclude the nil case
			return false , "Not a function"
		else
			return pcall ( func , ... )
		end
	end
end

function var ( var )
	local fn , fail = loadstring ( "return " .. var )
	-- Check to see if bytecode contains certain opcodes?
	
	if fail then -- Check for compilation errors
		return false , fail
	else
		setfenv ( fn , setmetatable ( { } , buildMetatableGet ( _M ) ) )
		local ok , result = pcall ( fn )
		if not ok then -- Check for no errors while finding variable
			return false , result
		elseif type ( result ) == "string" or type ( result ) == "number" or type ( result ) == "boolean" or type ( result ) == "table" or result == nil then -- Make sure function was found, result already has to be a string, number or nil
			return ok , result -- Note: result could be nil
		else
			return false , "Not a valid variable, tried to return value of: " .. type ( result )
		end
	end
end

-- Turn off the garbage collector
collectgarbage ( "stop" )
glib.idle_add ( glib.PRIORITY_DEFAULT_IDLE , function ( )
		collectgarbage ( "collect" ) -- Do a garbage collection
		collectgarbage ( "stop" ) -- Doing a collect turns the gc back on.... turn it off again.
	return true end )

-- Initialisation finished.
updatelog ( "LOMP Loaded " .. osdate ( "%c" ) , 3 )

mainloop:run ( )

logfilehandle:close ( )
