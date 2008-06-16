#! /usr/local/bin/lua
-- Change the above as appropriate

if _VERSION ~= "Lua 5.1" then --TODO: Override?
	error ( "This program needs lua 5.1 to work." )
end
package.path = package.path .. ";./libs/?.lua"

module ( "lomp" , package.seeall )

local verbosity = 3

do 
	log = ""

	-- Output Loading Annoucement
	print ( " " )
	local str = "LOMP Loading " .. os.date ( "%c" ) .. "\n"
	print ( str )

	-- Load Configuration
	require("config")

	-- Log File Stuff
	local file , err = io.open ( config.logfile , "w+" )
	if err then error ( "Could not open/create log file: '" .. err .. "'\n" ) end
	file:write ( str .. "\n" .. log .. "\n")
	file:flush ( )
	file:close ( )
	
	log = nil
end
	
function updatelog ( data , level )
	if not level then level = 2 end
	
	if level == 0 then data = "Fatal error: \t" .. data
	elseif level == 1 then data = "NonFatal error: \t" .. data 
	elseif level == 2 then data = "Warning: \t\t" .. data
	elseif level == 3 then data = "Message: \t\t" .. data
	elseif level == 4 then data = "Confirmation: \t\t" .. data
	end
	
	data = os.time ( ) .. ": \t" .. data
	if level <= verbosity then print ( data ) end
	
	data = data .. "\n"
	
	local file , err = io.open ( config.logfile , "a+" )
	if err then error ( data .. "Could not open log file: '" .. err .. "'\n" ) end
	file:seek ( "end" )
	file:write ( data )
	file:flush ( )
	file:close ( )
	if level == 0 then error ( data ) end
	return true
end
function ferror ( data , level )
	updatelog ( data , level )
	return false , data
end

require("general")
require("lomp-core")
require("playback")
require("server")

steps = { }
function addstep ( func )
	for i , v in ipairs ( steps ) do 
		if v == func then return false end
	end
	table.insert ( steps , func )
	return true
end

addstep ( server.step )

updatelog ( "Loading plugins." , 3 )
for i , v in ipairs ( config.plugins ) do
	local name = dofile ( v ) or v
	updatelog ( "Loaded plugin '" .. name .. "'" , 3 )
end
updatelog ( "All Plugins Loaded" , 3 )

do -- Restore State
	local ok , err = core.restorestate ( )
end

server.initiate ( config.address , config.port )

updatelog ( "LOMP Loaded " .. os.date ( "%c" ) , 3 )

require"lomp-debug"

local s = 1
while true do
	steps [ s ] ( )
	s = s + 1
	if s > #steps then s = 1 end
end
