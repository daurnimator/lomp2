#! /usr/local/bin/lua
-- Change the above as appropriate

if _VERSION ~= "Lua 5.1" then
	error ( "This program needs lua 5.1 or work." )
end

module ( "lomp" , package.seeall )

log = ""

require("config")

-- Log File Stuff
local file , err = io.open ( config.log_file , "w+" )
if err then error ( "Could not open log file: '" .. err .. "'\n" ) end
file:write ( "LMP Started " .. os.date ( "%c" ) .. "\n\n" .. log )
file:flush ( )
file:close ( )
function updatelog ( data , level )
	if level == 0 then data = "Fatal error: " .. data
	elseif level == 1 and not config.logall then return 
	end
	
	data = os.time ( ) .. " : \t" .. data .. "\n"
	local file , err = io.open ( config.log_file , "a+" )
	if err then error ( data .. "Could not open log file: '" .. err .. "'\n" ) end
	file:seek ( "end" )
	file:write ( data )
	file:flush ( )
	file:close ( )
	if level == 0 then error ( data ) end
	return data
end
log = nil

require("general")
require("lomp-core")
require("playback")
require("server")

-- Restore State
do
	local file, err = io.open( config.state_file )
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
	local file, err = io.open( config.state_file , "w+" )
	file:flush ( )
	file:close ( )
end
function exit ( )
	savestate ( )
	os.exit ( )
end

for i , v in ipairs ( config.plugins ) do
	dofile ( v )
	
end




--[[function p (...)
	if type ( select ( 1 , ... ) ) == "string" then 
	print ( ... )
	elseif type ( select ( 1 , ... ) ) == "table" then for k,v in pairs((...)) do p(...) end
	end
end--]] p = print
function demo ( )
	core.newpl ( math.random(100) )
	core.addfile ( "/media/sdc1/Downloaded/Zombie Nation, Kernkraft 400 CDS/[03] Zombie Nation - Kernkraft 400.wv" , 1 ) 
	core.addfile ( "/media/sdc1/Random Downloaded/Requiem for a Tower.mp3" , 1 )
	core.addfile ( "/path/file." .. math.random(100) , 1 )
end
function pv ( )
	p ( "Current State: " .. playback.state )
	p ( select( 2 , core.listpl ( ) ) )
	p ( select( 2 , core.listallentries ( 1 ) ) )
	p ( select( 2 , core.listqueue ( ) ) )
	p ( select( 2 , core.listplayed ( ) ) )
end
--demo ( )
--demo ( )
core.addfolder ( config.library [1] , 1 )
core.addtoqueue ( 1 , 16 , 1 )
pv ( )


server.inititate ( config.address , config.port )
steps = {}

table.insert ( steps , server.step )

local s = 1
while true do
	steps[s] ( )
	s = s + 1
	if s > #steps then s = 1 end
end
