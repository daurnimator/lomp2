--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local prefix = (...):match("^(.-)[^%.]*$")

local rawset , require , setmetatable , type , unpack = rawset , require , setmetatable , type , unpack
local osdate , ostime = os.date , os.time
local tblcopy = table.copy

require "SaveToTable"
local tblload , tblsave = table.load , table.save

module ( "lomp.metadata" , package.see ( lomp ) )

local cache
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

local modules = {
	"fileinfo.wavpack" ;
	"fileinfo.mpeg" ;
	"fileinfo.flac" ;
	"fileinfo.ogg" ;
}

-- Make tables that map extensions to (de|en)coders
local exttodec = { }
local exttoenc = { }
for i = 1 , #modules do
	local v = prefix .. modules [ i ]
	local extensions , decoder , encoder = unpack ( require ( v ) )
	for j = 1 , #extensions do
		local e = extensions [ j ]
		exttodec [ e ] = decoder
		exttoenc [ e ] = encoder
	end
end

local function getfileitem ( path )
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
	
	item.fetched = ostime ( )
	return item
end

local function editfile ( path , edits , inherit )
	local item = getitem ( path )

	local enc = exttoenc [ item.extension ]
	local lostdata , err = enc ( item , edits , inherit )
	if not err then
		return true , lostdata
	else	
		return false , err
	end
end

local function maketagcache ( )
	return { 
		file = setmetatable ( { } , {
			__index = function ( t , source )
				local item = getfileitem ( source )
				if item ~= nil then
					rawset ( t , source , item )
					return item
				end
			end ,
		} )
	}
end

-- Public functions
function getdetails ( typ , source )
	local cachet = cache [ typ ]
	if not cachet then return nil end
	return cachet [ source ] -- Can be nil
end



 -- edits is a table of tags & their respective changes
 -- inherit is a boolean that indicates if old tags should be kept or if edits should override all tags
function edittag ( typ , source , edits , inherit )
	
	tblcopy ( edits , cache [ typ ] [ source ].tags ) -- Change in cache
	
	if config.savetagedits then
		if typ == "file" then return editfile ( source , edits , inherit )
		else return ferror ( "Cannot save tags in item of type: " .. typ , 3 ) end
	else
		return true
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
