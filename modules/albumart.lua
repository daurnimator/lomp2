--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pcall , require = ipairs , pcall , require

module ( "lomp.albumart" , package.see ( lomp ) )

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
local lfs = require "lfs"

local formats = {
	jpg = true , jpeg = true , png = true , bmp = true ,
}
local subdirs = {
	"Artwork" ; "images" ; "scans" ;
}
-- First checks for folder.ext or thumb.ext in same folder
-- Then checks for Artwork and images subdirectory(s)
-- Then checks for any picture in same folder
-- TODO: Then checks for any picture in any sub folder
-- Else return nothing
function getalbumartpath ( path )
	local _ , _ , directory = path:find ( "^(.*)/[^/]*$" )
	
	for k , v in pairs ( formats ) do
		if lfs.attributes ( directory .. "/folder." .. k , "mode" ) == "file" then return directory .. "/folder." .. k 
		elseif lfs.attributes ( directory .. "/thumb." .. k , "mode" ) == "file" then return directory .. "/thumb." .. k
		elseif lfs.attributes ( directory .. "/front." .. k , "mode" ) == "file" then return directory .. "/front." .. k
		elseif lfs.attributes ( directory .. "/cover." .. k , "mode" ) == "file" then return directory .. "/cover." .. k
		end
	end
	--print ( "No folder.ext or thumb.ext in directory" )
	for i , v in ipairs ( subdirs ) do
		if lfs.attributes ( directory .. "/" .. v , "mode" ) == "directory" then
			for entry in lfs.dir ( directory .. "/" .. v) do
				local fullpath = directory .. "/" .. v .. "/" .. entry
				local mode = lfs.attributes ( fullpath , "mode" )
				if mode == "file" then
					local _ , _ , ext = entry:find ( "%.([^%./]+)$" )
					if formats [ ext ] then return fullpath end			
				end
			end
		end
	end
	--print ( "No art in subdirectory(s)" )
	for entry in lfs.dir ( directory ) do
		local fullpath = directory .. "/" .. entry
		local mode = lfs.attributes ( fullpath , "mode" )
		if mode == "file" then -- Any image in file's folder
			local _ , _ , ext = entry:find ( "%.([^%./]+)$" )
			if formats [ ext ] then return fullpath end
		end
	end
	--print ( "No art in folder" )
	return false -- No art found
end

local apictypes = {
	[ 0x00 ] = "Other" ; 
	[ 0x01 ] = "32x32 pixels 'file icon' (PNG only)" ;
	[ 0x02 ] = "Other file icon" ;
	[ 0x03 ] = "Cover (front)" ;
	[ 0x04 ] = "Cover (back)" ;
	[ 0x05 ] = "Leaflet page" ;
	[ 0x06 ] = "Media (e.g. lable side of CD)" ;
	[ 0x07 ] = "Lead artist/lead performer/soloist" ;
	[ 0x08 ] = "Artist/performer" ;
	[ 0x09 ] = "Conductor" ;
	[ 0x0A ] = "Band/Orchestra" ;
	[ 0x0B ] = "Composer" ;
	[ 0x0C ] = "Lyricist/text writer" ;
	[ 0x0D ] = "Recording Location" ;
	[ 0x0E ] = "During recording" ;
	[ 0x0F ] = "During performance" ;
	[ 0x10 ] = "Movie/video screen capture" ;
	[ 0x11 ] = "A bright coloured fish" ;
	[ 0x12 ] = "Illustration" ;
	[ 0x13 ] = "Band/artist logotype" ;
	[ 0x14 ] = "Publisher/Studio logotype" ;
}

function processapic ( picture ) -- picture is table like: { type , mimetype , description , data } optional: width , height , depth , colours
	local pictype = apictypes [ picture.type ]
	
end

function getalbumart ( path )
	-- TODO: check tag
	
	-- See if we have a local file
	local artpath = getalbumartpath ( path )
	-- TODO: load
	
	-- TODO: Check online
	-- Option to download temporarily, or save to directory or save to tag???
	
	-- No art around for the file, use default picture (should this be a local file, binary blob, or something provided by the client??)
	return false
end
