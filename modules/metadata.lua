--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local prefix = (...):match("^(.-)[^%.]*$")

require "general"

local ipairs , pairs , require , setmetatable , type , unpack = ipairs , pairs , require , setmetatable , type , unpack
local osdate , ostime = os.date , os.time

require "SaveToTable"
local tblload , tblsave = table.load , table.save

module ( "lomp.metadata" , package.see ( lomp ) )

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

local cache

local modules = {
	"fileinfo.wavpack" ;
	"fileinfo.mpeg" ;
	"fileinfo.flac" ;
	"fileinfo.ogg" ;
}

-- Make tables that map extensions to (de|en)coders
local exttodec = { }
local exttoenc = { }
for i , v in ipairs ( modules ) do
	v = prefix .. v
	local extensions , decoder , encoder = unpack ( require ( v ) )
	for i , v in ipairs ( extensions ) do
		exttodec [ v ] = decoder
		exttoenc [ v ] = encoder
	end
end

local function getitem ( path )
	local item = { 
		path = path ;
		filename = path:match ( "([^/]+)$" ) ;
		extension = path:match ( "%.([^%./]+)$" ):lower ( ) ;
		tags = { } ;
		extra = { } ;
	}
	
	local f = exttodec [ item.extension ]
	if f then
		local ok , err = f ( item )
		if not ok then updatelog ( "Corrupt/Bad File: " .. item.path .. ":" .. ( err or "" ) , 3 ) end
	else
		updatelog ( "Unknown format: " .. item.extension , 3 )
	end
	
	--[[setmetatable ( item.tags , { 
		__index = function ( t , k )
			if k:sub ( 1 , 1 ):match ( "%w" ) then
				return { "Unknown " .. k }
			end
		end ,
	} )--]]
	
	return item
end

local function maketagcache ( tbl )
	return setmetatable ( tbl , {
		__index = function ( t , k )
			local item = getitem ( k )
			if item ~= nil then
				item.fetched = ostime ( )
				t [ k ] = item
				return item
			end
		end ,
	})
end

-- Public functions
function getdetails ( path )
	if type ( path ) ~= "string" then return ferror ( "metadata.getdetails called without valid path: " .. ( path or "" ) , 3 ) end
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
	local ok , err = tblsave ( {  lomp = core._VERSION , major = core._MAJ , minor = core._MIN , inc = core._INC , timesaved = osdate ( ) , cache = cache } , config.tagcachefile , "" , "" )
	if not ok then
		return ferror ( err , 2 )
	else
		updatelog ( "Tag cache sucessfully saved" , 4 )
		return true
	end
end

function restorecache ( )
	local tbl , err = tblload ( config.tagcachefile )
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
