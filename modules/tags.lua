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
??item.length
??: size, format, bitrate
--]]

require "modules.fileinfo.APE"
require "modules.fileinfo.id3v2"
require "modules.fileinfo.id3v1"
require "modules.fileinfo.flac"

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
	local item = { 
		path = path ,
		filename = string.match ( path , "([^/]+)$" )
	}
	item.extension = string.match ( item.filename , "%.([^%./]+)$" )

	do
		local fd = io.open ( path , "rb" )
		do 
			do -- flac (vorbis comment)
				local offset = fileinfo.flac.find ( fd )
				if offset then -- Is flac file
					fileinfo.flac.info ( fd , item )
				end
			end
			
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
		end
		
		fd:close ( )
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
			local item = gettags ( k )
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

function edittag ( path , edits )
	-- "edits" is a table of tags & their respective changes
	local t = cache [ path ].tags
	
	for k , v in pairs ( edits ) do
		t [ k ] = v -- Change in cache
	end
	if config.savetagedits then
		local tagtype
		
		-- TODO: more tag editing
		
		-- ID3v2
		if not tagtype then
			local offset = fileinfo.id3v2.find ( fd )
			if offset then
				tagtype = "id3v2"
				local lostdata = fileinfo.id3v2.edit ( path , edits , true )
			end
		end
		
		-- ID3v1 or ID3v1.1 tag
		if not tagtype then
			local offset = fileinfo.id3v1.find ( fd )
			if offset then
				tagtype = "id3v1"
				local lostdata = fileinfo.id3v1.edit ( path , edits , true )
			end
		end
		
		if not tagtype then -- File has no tag
			-- Figure out what sort of tag to add to file
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
