--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

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
local compiledchunk = loadfile ( "config" ) -- path from pwd
if not compiledchunk then fail ( "Could not find config file" ) end
setfenv ( compiledchunk , config )

module ( "config" )

-- Run config
compiledchunk ( ) 


-- Check all configuration values.

-- Core Parameters
if type ( verbosity ) ~= "number" or verbosity < 0 or verbosity > 5 then
	warn ( 'Invalid or verbosity not defined, using log level 2' )
	verbosity = 2
end
if type ( logfile ) ~= "string" then
	warn ( 'Invalid or no logfile path defined, using "~/.lomp/lomp.log"' )
	logfile = "~/.lomp/lomp.log"
end

if type ( statefile ) ~= "string" then 
	warn ( 'Invalid or no statefile path defined, using "~/.lomp/lomp.state"' )
	statefile = "~/.lomp/lomp.state"
end

if type ( tagcachefile ) ~= "string" then 
	warn ( 'Invalid or no tagcachefile path defined, using "~/.lomp/lomp.tagcache"' )
	tagcachefile = "~/.lomp/lomp.tagcache"
end

if type ( history ) ~= "number" or history <=0 then 
	warn ( 'Invalid or no history length defined, using 200' )
	history = 200
end

if type ( library ) ~= "table" then
	warn ( 'Invalid or no library paths defined' )
	library = { }
end

-- Other/Misc Parameters

if type ( plugins ) ~= "table" then
	plugins = { }
end

if type ( savetagedits ) ~= "boolean" then
	warn ( 'savetagedits not a valid boolean value, defaulting to false' )
	savetagedits = false
end

if type ( tagpatterns ) ~= "table" then
	warn ( 'tagpatterns is not a valid table, no patterns found' )
	tagpatterns = { }
else
	tagpatterns.default = tagpatterns [ tagpatterndefault ]
end


if type ( banextensions ) ~= "table" then 
	banextensions = { } 
end

if type ( sortcaseinsensitive ) ~= "boolean" then 
	warn ( 'sortcaseinsensitive not a valid boolean value, defaulting to true' )
	sortcaseinsensitive = true 
end
