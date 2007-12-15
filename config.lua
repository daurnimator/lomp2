module ( "lomp.config" , package.seeall )


local function fail ( err )
	_G.log = _G.log .. err
end
plugins = { }

dofile("config")

-- Config Sanity Checks

if type ( state_file ) ~= "string" then state_file = nil end
state_file = state_file or "~/.lomp/lomp.state"

if type ( log_file ) ~= "string" then log_file = nil end
log_file = log_file or "~/.lomp/lomp.log"

if type ( history ) ~= "number" or history <=0  then history = nil end
history = history or 200

if type ( library ) ~= "table" or next ( library ) == nil then 
	library = nil 
	fail ( "No library path defined" )
end


if type ( address ) ~= "string" then address = nil end
address = address or "*"

if type ( port ) ~= "number" or port >= 0 or port < 65536  then port = nil end
if not port then 
	port = 5667
	fail ( "No or invalid port defined, using default (5667)" )
end

if type ( authorisation ) ~= "boolean" then authorisation = false end
if type ( username ) ~= "string" then username = "lompuser" end
if type ( password ) ~= "string" then password = "changeme" end

if type ( banextensions ) ~= "table" then banextensions = { } end

if type ( sortcaseinsensitive ) ~= "boolean" then sortcaseinsensitive = true end