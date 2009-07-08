--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.fileinfo.flac" , package.see ( lomp ) )

require "vstruct"

_NAME = "FLAC reader"

function find ( fd )
	fd:seek ( "set" ) -- Rewind file to start
	if fd:read ( 4 ) == "fLaC" then 
		return fd:seek ( "set" )
	end
end

function info ( item )
	local fd = io.open ( item.path , "rb" )
	if not fd then return false , "Could not open file" end
	item = item or { }
	fd:seek ( "set" ) -- Rewind file to start
	-- Format info found at http://flac.sourceforge.net/format.html
	if fd:read ( 4 ) == "fLaC" then 
		item.format = "flac"
		item.extra = { } 
		
		local t
		repeat
			t = vstruct.unpack ( "< m1 > u3" , fd )
			
			local lastmetadatablock = vstruct.implode { unpack ( t [ 1 ] , 8 , 8 ) }
			local blocktype = vstruct.implode { unpack ( t [ 1 ] , 1 , 7 ) }		
			local blocklength = t [ 2 ] -- Is in bytes
			
			--print ( lastmetadatablock , blocktype , blocklength )
			
			if blocktype == 0 then -- Stream info
				t = vstruct.unpack ( "> u2 u2 u3 u3 m8 u16" , fd )
				item.extra.minblocksize = t [ 1 ]
				item.extra.maxblocksize = t [ 2 ]
				item.extra.minframesize = t [ 3 ]
				item.extra.maxframesize = t [ 4 ]
				item.extra.samplerate = vstruct.implode { unpack ( t [ 5 ] , 45 , 64 ) }
				item.extra.channels = vstruct.implode { unpack ( t [ 5 ] , 42 , 44 ) } + 1
				item.extra.bitspersample = vstruct.implode { unpack ( t [ 5 ] , 37 , 41 ) } + 1
				item.extra.totalsamples = vstruct.implode { unpack ( t [ 5 ] , 1 , 36 ) }
				item.extra.md5rawaudio = t [ 6 ]
			elseif blocktype == 1 then -- Padding
				item.extra.padding = item.extra.padding or { }
				table.insert ( item.extra.padding , { start = fd:seek ( ) , length = blocklength , } )
				t = vstruct.unpack ( "> x" .. blocklength , fd )
			elseif blocktype == 2 then -- Application
				t = vstruct.unpack ( "> u4 s" .. ( blocklength - 4 ) , fd )
				item.extra.applications = item.extra.applications or { }
				table.insert ( item.extra.applications , { appID = t [ 1 ] , appdata = t [ 2 ] } )
			elseif blocktype == 3 then -- Seektable
				t = vstruct.unpack ( "> x" .. blocklength , fd ) -- We don't deal with seektables, skip over it
			elseif blocktype == 4 then
				item.tagtype = "vorbiscomment"
				item.tags = { }
				item.extra.startvorbis = fd:seek ( ) - 4
				
				require "modules.fileinfo.vorbiscomments"
				lomp.fileinfo.vorbiscomments.info ( fd , item )
				
			elseif blocktype == 5 then -- Cuesheet
				t = vstruct.unpack ( "> s128 u8 x259 x1 x" .. ( blocklength - ( 128 + 8 + 259 + 1 ) ) , fd ) -- cbf, TODO: cuesheet reading
			elseif blocktype == 6 then -- Picture
				t = vstruct.unpack ( "> u4 u4" , fd )
				local picturetype = t [ 1 ]
				local mimelength = t [ 2 ]
				t = vstruct.unpack ( "> s" .. mimelength .. "u4" , fd )
				local mimetype = t [ 1 ]
				local descriptionlength = t [ 2 ]
				t = vstruct.unpack ( "> s" .. descriptionlength .. " u4 u4 u4 u4 u4" , fd )
				local width = t [ 1 ]
				local height = t [ 2 ]
				local colourdepth = t [ 3 ]
				local numberofcolours = t [ 4 ]
				local picturelength = t [ 5 ]
				t = vstruct.unpack ( "> s" .. picturelength , fd )
				local picturedata = t [ 1 ]
			end
		until lastmetadatablock == 1
		if not item.tags then
			-- Figure out from path
			item.tagtype = "pathderived"
			item.tags = fileinfo.tagfrompath.info ( path , config.tagpatterns.default )
		end
		item.length = item.extra.totalsamples / item.extra.samplerate
		item.channels = item.extra.channels
		item.samplerate = item.extra.samplerate
		item.bitrate = 	item.extra.samplerate*item.extra.bitspersample
		item.filesize = fd:seek ( "end" )
		
		fd:close ( )
		
		return item
	else
		-- not a flac file
		fd:close ( )
		return false , "Not a flac file"
	end
end

function write ( fd , tags )
	local item = info ( fd )
	
	local vendor_string = item.extra.vendor_string or "Xiph.Org libVorbis I 20020717"
	local vendor_length = string.len ( vendor_string )
	
	local commentcount = 0
	local s = ""
	for k , v in ipairs ( tags ) do
		for i , v in ipairs ( v ) do
			commentcount = commentcount + 1
			local comment = k .. "=" .. v
			local length = string.len ( comment )
			s = s .. vstruct.pack ( "u4 s" , length , comment )
		end
	end
	
	s = vstruct.pack ( "u4 s u4" , vendor_length , vendor_string , commentcount ) .. s
	local length = string.len ( s )
	s = vstruct.pack ( "u3" , length ) .. s
	
	local space_needed = string.len ( s )
	
	local oldblocksize = 0
	if item.extra.startvorbis then
		fd:seek ( item.extra.startvorbis + 1 )
		oldblocksize = vstruct.unpack ( "u3" , fd ) [ 1 ]
	end
	
	if space_needed ~= oldblocksize then
		-- Look for padding blocks
		if type ( item.extra.padding ) == "table" then
			
		end
		
		if space_needed < oldblocksize then
			
		else --space_needed > oldblocksize then
			
		end
	end
	
	-- Write
end

function edit ( path , tags , inherit )
	local fd = io.open ( path , "rb+" )
	if not fd then return ferror ( err , 3 ) end
	
	--write ( fd , tags )
	
	-- Flac editing not ready yet
	return false
end

return { { "flac" , "fla" } , info , edit }
