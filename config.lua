local function fail ( err )
	lomp.log = "Error: \t" .. lomp.log .. err .. "\n"
	error ( err )
end
local function warn ( err )
	lomp.log = "Warning: \t" .. lomp.log .. err .. "\n"
	print ( err )
end

config = {
	type = type ,
	plugins = { }
}

-- Load config
local compiledchunk = loadfile ( "config" )
setfenv ( compiledchunk , config )

module ( "config" )

-- Run config
compiledchunk ( ) 


-- Check all configuration values.

-- Core Parameters
if type ( logfile ) ~= "string" then
	warn ( 'Invalid or no logfile path defined, using "~/.lomp/lomp.log"' )
	logfile = "~/.lomp/lomp.log"
end

if type ( statefile ) ~= "string" then 
	warn ( 'Invalid or no statefile path defined, using "~/.lomp/lomp.state"' )
	statefile = "~/.lomp/lomp.state"
end

if type ( history ) ~= "number" or history <=0 then 
	warn ( 'Invalid or no history length defined, using 200' )
	history = 200
end

if type ( library ) ~= "table" then
	warn ( 'Invalid or no library paths defined' )
	library = { }
end

-- Server Parameters
if type ( address ) ~= "string" then
	warn ( 'Invalid or no server binding address defined, using "*"')
	address = "*"
end

if type ( port ) ~= "number" or port < 0 or port > 65536  then
	warn ( 'Invalid or no server port defined, using 5667' )
	port = 5667
end
if type ( authorisation ) ~= "boolean" then
	authorisation = false 
else -- If authorisation is enabled:
	if type ( username ) ~= "string" then
		warn ( 'Invalid or no server username defined, using "lompuser"' )
		username = "lompuser"
	end
	if type ( password ) ~= "string" then 
		warn ( 'Invalid or no server password defined, disabling authorisation' )
		password = nil
		authorisation = false
	end
end


-- Other/Misc Parameters

if type ( plugins ) ~= "table" then
	plugins = { }
end

if type ( banextensions ) ~= "table" then 
	banextensions = { } 
end

if type ( sortcaseinsensitive ) ~= "boolean" then 
	sortcaseinsensitive = true 
end
