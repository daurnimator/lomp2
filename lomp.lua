#! /usr/local/bin/lua
-- Change the above as appropriate

if _VERSION ~= "Lua 5.1" then --TODO: Override?
	error ( "This program needs lua 5.1 to work." )
end

module ( "lomp" , package.seeall )

verbosity = 3

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

require("general")
require("lomp-core")
require("playback")
require("server")

--[[-- Restore State
do
	local file, err = io.open( config.statefile )
	if file then
		--RESTORE THE STATE
		core.updatesoftqueue ( )
-- New/Blank State
	else
		updatelog ( "Could not find state file: '" .. err .. "'\n\t\t Using defaults." )
		core.newpl ( "Default Playlist" )
	end
end
function savestate ( )
	local file, err = io.open( config.statefile , "w+" )
	file:flush ( )
	file:close ( )
end--]]

function quit ( )
	--savestate ( )
	player.stop ( )
	os.exit ( )
end


updatelog ( "Loading plugins." , 3 )
for i , v in ipairs ( config.plugins ) do
	local name = dofile ( v ) or v
	updatelog ( "Loaded plugin '" .. name .. "'" , 3 )
end



require"lomp-debug"

demo ( )

core.addfolder ( config.library [ 1 ] , 0 )
core.setsoftqueueplaylist ( 0 )
table.randomize ( vars.pl [ 0 ] )
core.addentry ( vars.pl[0][1] , 1 , 1 )
pv ( )


server.inititate ( config.address , config.port )
steps = {}

table.insert ( steps , server.step )

local s = 1

updatelog ( "LOMP Loaded " .. os.date ( "%c" ) , 3 )


playback.play ( )

while true do
	steps[s] ( )
	s = s + 1
	if s > #steps then s = 1 end
end
