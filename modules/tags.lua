--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.tags" , package.see ( lomp ) )

require "SaveToTable"

--[[
Format:
cache [ path ] = item
item.tags [ "title" ] (etc)
item.filename
item.extension
item.path

item.format
item.tagtype

item.length
item.channels
item.samplerate
item.bitrate
item.filesize
item.extra = {...}
--]]

modules = {
	"modules.fileinfo.wavpack" ,
	"modules.fileinfo.mpeg" ,
	"modules.fileinfo.flac"
}

local mpeg = require 
local flac = require 

require "modules.fileinfo.APE"
require "modules.fileinfo.id3v2"
require "modules.fileinfo.id3v1"

exttodec = { }
exttoenc = { }
for i , v in ipairs ( modules ) do
	local extensions , decoder , encoder = unpack ( require ( v ) )
	print(extensions , decoder , encoder )
	for i , v in ipairs ( extensions ) do
		exttodec [ v ] = decoder
		exttoenc [ v ] = encoder
	end
end

local function getitem ( path )
	local item = { 
		path = path ,
		filename = string.match ( path , "([^/]+)$" )
	}
	item.extension = string.lower ( string.match ( item.filename , "%.([^%./]+)$" ) )

	do
		local f = exttodec [ item.extension ]
		if f then
			local ok , err = f ( item )
		else
			return ferror ( "Unknown format: " .. item.extension , 3 )
		end
		--[=[	
			--[[ Check if vorbis (eg: ogg)
			fd:seek ( "set" , 1 )
			local s = fd:read ( 6 ) -- six octet identifier
			if s == "vorbis" then -- Flac file
				
				return 
			end--]]
			
			-- APE
			if not item.tagtype then
				local offset , header = fileinfo.APE.find ( fd )
				if offset then
					item.header = header
					item.tagtype = "APE"
					item.tags , item.extra = fileinfo.APE.info ( fd , offset , header )
				end
			end

			-- ID3v2
			if not item.tagtype then
				local offset , header = fileinfo.id3v2.find ( fd )
				if offset then
					item.header = header
					item.tagtype = "id3v2"
					item.tags , item.extra = fileinfo.id3v2.info ( fd , offset , header )
				end
			end
			
			-- ID3v1 or ID3v1.1 tag
			if not item.tagtype then
				local offset = fileinfo.id3v1.find ( fd )
				if offset then
					item.tagtype = "id3v1"
					item.tags , item.extra = fileinfo.id3v1.info ( fd , offset )
				end
			end
			
			if not item.tagtype then -- If you get to here, there is probably no tag....
				item.tagtype = "pathderived"
				item.tags = tagfrompath ( path , config.tagpatterns.default )
				item.length = 30 -- TODO: Remove
			end
		end--]=]
	end
	
	setmetatable ( item.tags , { 
		__index = function ( t , k )
			if k:sub ( 1 , 1 ):match ( "%w" ) then
				return { "Unknown " .. k }
			end
		end ,
	} )
	
	return item
end

local function maketagcache ( tbl )
	return setmetatable ( tbl, {
		__index = function ( t , k )
			local item = getitem ( k )
			t [ k ] = item
			return item
		end ,
	})
end

-- Public functions
function getdetails ( path )
	if type ( path ) ~= "string" then return ferror ( "tags.getdetails called without valid path: " .. ( path or "" ) , 3 ) end
	return cache [ path ]
end

function edittag ( path , edits , inherit )
	-- "edits" is a table of tags & their respective changes

	local item = getitem ( path )
	
	local t = cache [ path ].tags	
	for k , v in pairs ( edits ) do
		t [ k ] = v -- Change in cache
	end
	
	if config.savetagedits then
		local lostdata , err = exttoenc [ item.extension ] ( item , edits , inherit )
		if not err then
			if lostdata then
				
			else
				return true
			end
		else
			
		end
	end
end
function savecache ( )
	local ok , err = table.save ( {  lomp = core._VERSION , major = core._MAJ , minor = core._MIN , inc = core._INC , timesaved = os.date ( ) , cache = cache } , config.tagcachefile , "" , "" )
	if not ok then
		return ferror ( err , 2 )
	else
		updatelog ( "Tag cache sucessfully saved" , 4 )
		return true
	end
end
function restorecache ( )
	local tbl , err = table.load ( config.tagcachefile )
	if not tbl then
		return ferror ( err , 2 )
	-- elseif -- TODO: Version Checks
	else
		cache = maketagcache ( tbl.cache )
		return true
	end
end

restorecache ( )
cache = cache or maketagcache ( { } )
