--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.tags" , package.see ( lomp ) )

require "modules.tagging.flac"

--[[
Format:
cache [ path ] = item
item.tags [ "title" ] (etc)
item.filename
item.extension
item.path
??item.length
??: size, format, bitrate
--]]

function tagfrompath ( path , format , donotescapepattern )
	local subs = {
		["album artist"] = "([^/]+)" ,
		["artist"] = "([^/]+)" ,
		["album"] = "([^/]+)" ,
		["year"] = "(%d%d%d%d)" ,
		["track"] = "(%d+)" ,
		["title"] = "([^/]+)" ,
		["release"] = "([^/]+)" ,
	}
	local a = { }	
	local pattern = format 
	if not donotescapepattern then pattern = string.gsub ( pattern , "[%%%.%^%$%+%*%[%]%-%(%)]" , function ( str ) return "%" .. str end ) end-- Escape any characters that may need it except "?"
	pattern = string.gsub ( pattern , "//_//" , "[^/]-" ) -- Junk operator
	pattern = string.gsub ( pattern , "//([^/]-)//" , function ( tag ) 
											tag = string.lower ( tag ) 
											a [ #a + 1 ] = tag 
											return subs [ tag ] 
										end )
	pattern = pattern .. "%.[^/]-$" -- extension
	local r = { string.match ( path , pattern ) }
	
	local t = { }
	for i , v in ipairs ( a ) do
		t [ v ] = r [ i ]
	end
	return t
end

local function gettags ( path )
	local item = {}
	item.path = path
	local _ , _ , filename = string.find ( path , "([^/]+)$" )
	item.filename = filename
	local _ , _ , extension = string.find ( filename , "%.([^%./]+)$" )
	item.extension = extension
	
	--item.random = math.random ( )
	-- TODO: file info reading
	item.length = 30
	-- TODO: actual tag reading
	item.tags = tagfrompath ( path , config.tagpatterns.default )
	
	setmetatable ( item.tags , { 
		__index = function ( t , k )
			return "Unknown " .. k
		end ,
	} )
	return item
end

cache = { }
cache = setmetatable ( cache, {
	__index = function ( t , k )
		local item = gettags ( k )
		t [ k ] = item
		return item
	end ,
})


-- Public functions
function getdetails ( path )
	return cache [ path ]
end
function edittag ( path , edits )
	-- "edits" is a table of tags & their respective changes
	local t = cache [ path ].tags
	
	for k , v in pairs ( edits ) do
		t [ k ] = v -- Change in cache
		if config.savetagedits then
			-- TODO: tag editing
		end
	end
end
function serialisecache ( )
	local s = ""
	s = s .. "cache = {\n"
	for k , v in pairs ( cache ) do
		s = s .. '[' .. string.format ( '%q' , k ) ..'] = {'
		for k , v in pairs ( v ) do
			if type ( v ) == "table" then
				s = s .. '\t' .. k .. ' = {\n'
				for k , v in pairs ( v ) do
					s = s .. '[' .. string.format ( '%q' , k ) .. '] = ' .. string.format ( '%q' , v ) .. ';'
				end
				s = s .. '\t};\n'
			elseif type ( v ) == "string" then
				s = s .. '\t' .. k .. ' = ' .. string.format ( '%q' , v ) .. ';\n'
			elseif type ( v ) == "number" then
				s = s .. '\t' .. k .. ' = ' .. v .. ';\n'
			elseif type ( v ) == "boolean" then
				s = s .. '\t' .. k .. ' = ' .. tostring(v) .. ';\n'
			end
		end
		s = s .. '};\n'
	end
	s = s .. '};\n'
	return s
end
function savecache ( )
	local s = core._NAME .. "\t" .. core._VERSION .. " TagCache File.\tCreated: " .. os.date ( ) .. "\n"
	s = s .. serialisecache ( )
	
	local file, err = io.open( config.tagcachefile , "w+" )
	if err then 
		return ferror ( "Could not open tag cache file: '" .. err , 2 ) 
	end
	file:write ( s )
	file:flush ( )
	file:close ( )
	
	updatelog ( "Tag cache sucessfully saved" , 4 )
	
	return s , err
end
function restorecache ( )
	local file, err = io.open ( config.tagcachefile )
	if file then -- Restoring State.
		local v = file:read ( )
		if not v then
			return ferror ( "Invalid tagcache file" , 1 )
		end 
		local _ , _ , program , major , minor , inc = string.find ( v , "^([^%s]+)%s+(%d+)%.(%d+)%.(%d+)" )
		if type ( program ) == "string" and program == "LOMP" and tonumber ( major ) <= core._MAJ and tonumber ( minor ) <= core._MIN and tonumber ( inc ) <= core._INC then
			local s = file:read ( "*a" )
			file:close ( )
			local f , err = loadstring ( s , "Saved Tag Cache" )
			if not f then
				return ferror ( "Could not load tagcache file: " .. err , 1 )
			end
			local t = { }
			setfenv ( f , t )
			f ( )
			table.inherit ( _M , t , true )
		else
			file:close ( )
			return ferror ( "Invalid tagcache file" , 1 )
		end
	else
		return ferror ( "Could not find tagcache file: '" .. err .. "'" , 2 )
	end
	return true
end
-- TODO: Add SQL in future?
restorecache ( )