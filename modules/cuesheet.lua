--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local error, ipairs , pcall , require , tonumber , type = error, ipairs , pcall , require , tonumber , type
local strupper = string.upper
local iolines = io.lines

module ( "lomp.cuesheet" , package.see ( lomp ) )

require "core.item"

local sourcetype = "cue"

local lpeg = require "lpeg"

-- Docs @ http://digitalx.org/cuesheetsyntax.php

-- In cuesheets:
-- All audio files (WAVE, AIFF, and MP3) must be in 44.1KHz 16-bit stereo format
-- For AUDIO files, if the length of the data within the file is not an exact multiple of the CDROM sector size (2352 bytes), then the last sector will be padded with zeros when it is recorded to the blank disc.

local lineparser , commentparser
do
	local C , Cc , P , R , S = lpeg.C , lpeg.Cc , lpeg.P , lpeg.R , lpeg.S
	
	local eos = P ( '\r' )^-1 * -P ( 1 )
	local space = S ( ' ' )
	local digit = R ( '09' )
	local lower , upper = R ( 'az' ) , R ( 'AZ' )
	local alpha = lower + upper
	local alphanumeric = digit + alpha
	
	local str = '"' * C ( ( P ( 1 ) - '"')^0 ) * '"' -- Quoted string
		+ C ( ( 1 - space - eos )^0 ) -- normal string
	
	local timesection = ( digit * digit ) / tonumber
	local timestamp = ( timesection * ":" * timesection * ":" * timesection )
		/ function ( mins , secs , frames ) return frames / 75 + secs + 60 * mins end -- Returns number of seconds
		+ function ( _ , i ) error ( "Invalid timestamp in cuesheet" ) end
	
	local media_catalog_number = digit * digit * digit * digit * digit * digit * digit * digit * digit * digit * digit * digit * digit / tonumber -- 13 digit number
	local CATALOG = C "CATALOG" * space * media_catalog_number
	
	local CDTEXTFILE = C "CDTEXTFILE" * space * str
	
	local filetype = C ( P "BINARY" + "MOTOROLA" + "AIFF" + "WAVE" + "MP3" + "FLAC" ) -- Note: "FLAC" isn't in spec
		+ function ( _ , i ) error ( "Invalid filetype in cuesheet" ) end
	local FILE = C "FILE" * space * str * space * filetype
	
	local flag = C ( P "DCP" + "4CH" + "PRE" + "SCMS" )
		+ function ( _ , i ) error ( "Invalid flag in cuesheet" ) end
	local FLAGS = C "FLAGS" * ( space * flag )^1
	
	local indexnumber = digit * digit^1 / tonumber -- Note: max 2 digits in spec
	local INDEX = C "INDEX" * space * indexnumber * space * timestamp
	
	local isrccode = alphanumeric * alphanumeric * alphanumeric * alphanumeric * alphanumeric * digit * digit * digit * digit * digit * digit * digit / strupper
	local isrcwtf = ( P "GAPc;" + "FQ`^7" ) * digit * digit * digit * digit * digit * digit * digit * Cc ( nil ) -- Weird ISRC patterns that seems to show up...
	local ISRC = C "ISRC" * space * ( isrccode + isrcwtf )
	
	local PERFORMER = C "PERFORMER" * space * str
	
	local POSTGAP = C "POSTGAP" * space * timestamp
	
	local PREGAP = C "PREGAP" * space * timestamp
	
	local REM = C "REM" * space^-1 * C ( P ( 1 ) ^ 0 )
	
	local SONGWRITER = C "SONGWRITER" * space * str
	
	local TITLE = C "TITLE" * space * str
	
	local datatype = C ( P "AUDIO" + "CDG" + "MODE1/2048" + "MODE1/2352" + "MODE2/2336" + "MODE2/2352" + "CDI/2336" + "CDI/2352" + "MODEx/2xxx" ) -- Note: "MODEx/2xxx" isn't in spec, it sometimes comes up for CD-Extra
		+ function ( _ , i ) error ( "Invalid track datatype in cuesheet" ) end
	local TRACK = C "TRACK" * space * indexnumber * space * datatype
	
	lineparser = ( P "\239\187\191" )^-1 -- Some files get the utf BOM... wtf!
		* space^0 * ( CATALOG + CDTEXTFILE + FILE + FLAGS + INDEX + ISRC + PERFORMER + POSTGAP + PREGAP + REM + SONGWRITER + TITLE + TRACK )^-1 
		* space^0 * eos + function ( _ , i ) error ( "Invalid cuesheet" ) end
	
	commentparser = C ( upper^1 ) * space * str
end

local d = {
	CATALOG = function ( data , number )
		if data.catalog then
			error ( "CATALOG can only appear once in a cuesheet" )
		else
			data.catalog = number
		end
	end ;
	CDTEXTFILE = function ( data , path ) end ; -- NO-OP
	FILE = function ( data , path , typ )
		local files = data.files
		files [ #files + 1 ] = { path = path , type = typ , tracks = { n = 0 } }
	end ;
	FLAGS = function ( data , ... )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				local flags = tracks [ tracks.n ].flags
				for i , v in ipairs ( { ... } ) do
					flags [ v ] = true
				end
				return
			end
		end
		error ( "FLAGS can only appear after TRACK in a cuesheet" )
	end ;
	INDEX = function ( data , index , offset )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				local indexes = tracks [ tracks.n ].indexes
				if ( #indexes == 0 and ( index == 0 or index == 1 ) ) or #indexes == ( index - 1 ) then
					indexes [ index ] = offset
				else
					error ( "Invalid INDEX (" .. index .. ") in cuesheet" )
				end
				return
			elseif index == 1 then  -- Non-compliant: allow a single track distributed over multiple files; limit to EAC's non compliant only (just index 0 in the previous track)
				local lastfile = files [ #files - 1 ]
				if lastfile then
					local lasttracks = lastfile.tracks
					local lasttrack = lasttracks [ lasttracks.n ]
					if lasttrack then
						local indexes = lasttrack.indexes
						if indexes [ index - 1 ] then
							data.noncompliant = true
							
							tracks.n = 1
							tracks [ 1 ] = lasttrack
							indexes [ index ] = offset
							return
						end
					end
				end
			end
		end
		error ( "INDEX can only appear after TRACK in a cuesheet" )
	end ;
	ISRC = function ( data , isrc )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				tracks [ tracks.n ].isrc = isrc
				return
			end
		end
		error ( "ISRC can only appear after TRACK in a cuesheet" )
	end ;
	PERFORMER = function ( data , performer )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				tracks [ tracks.n ].performer = performer
				return
			end
		end
		data.performer = performer
	end ;
	POSTGAP = function ( data , offset )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				local track = tracks [ tracks.n ]
				if track.postgap then
					error ( "POSTGAP can only appear once for each TRACK" )
				else
					track.postgap = offset
					return
				end
			end
		end
		error ( "POSTGAP can only appear after TRACK in a cuesheet" )
	end ;
	PREGAP = function ( data , offset )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				local track = tracks [ tracks.n ]
				if track.pregap then
					error ( "PREGAP can only appear once for each TRACK" )
				else
					track.pregap = offset
					return
				end
			end
		end
		error ( "PREGAP can only appear after TRACK in a cuesheet" )
	end ;
	REM = function ( data , str )
		-- Comments before the first TRACK are often additional metadata
		local files = data.files
		if #files > 0 and # ( files [ #files ].tracks ) > 0 then return end
		
		local field , value = commentparser:match ( str )
		if field and value then
			data [ field ] = value -- won't clash as field is all uppercase
		end
	end ;
	SONGWRITER = function ( data , songwriter )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				tracks [ tracks.n ].songwriter = songwriter
				return
			end
		end
		data.songwriter = songwriter
	end ;
	TITLE = function ( data , title )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			if tracks.n > 0 then
				tracks [ tracks.n ].title = title
				return
			end
		end
		data.title = title
	end ;
	TRACK = function ( data , track , datatype )
		local files = data.files
		if #files > 0 then
			local tracks = files [ #files ].tracks
			tracks.n = track
			tracks [ track ] = { type = datatype , track = track , flags = { } , indexes = { } ,
				songwriter = data.songwriter , title = data.title , performer = data.performer
			}
			return
		end
		error ( "TRACK can only appear after FILE in a cuesheet" )
	end ;
}

local function doline ( data , op , ... )
	if type ( op ) ~= "number" then -- incase there were no captures (eg. blank lines)
		d [ op ] ( data , ... )
	end
end

function read ( path )
	-- "files [ fileindex ].tracks" can be a holey array. the maximum index used is stored in tracks.n
	local data = {
		files = { }
	}
	
	for line in iolines ( path ) do
		local ok , err = pcall ( doline , data , lineparser:match ( line ) )
		if not ok then return ferror ( "Cuesheet.Reader: " .. err , 2 ) end
	end
	
	return data
end

local function createitem ( data , fileindex , baseoffset )
	local file = data.files [ fileindex ]
	return core.item.create ( sourcetype , file.path , false , baseoffset )
end

function addtrack ( cuepath , track , index , pl , pos )
	index = index or 1
	
	local data , err = read ( cuepath )
	if not data then return data , err end
	local files = data.files
	
	for i = 1 , #files do
		local t = files [ i ].tracks [ track ]
		if t then
			local indexes = t.indexes
			if index == 1 and indexes [ 0 ] and indexes [ 1 ] and indexes [ 1 ] < indexes [ 0 ] then -- We have a pregap appended to the previous track (non-compliant)
				if files [ i + 1 ].tracks [ track ] == t then -- If next file has the same track, use the next file instead.
					i = i +1
				end
			end
			local offset = indexes [ index ]
			if offset then
				local item = createitem ( data , i , offset )
				return core.item.additem ( pl , pos , item )
			end
		end
	end
	return ferror ( "Unable to find track in cuesheet" , 3 )
end

function addcuesheet ( cuepath , pl , pos )
	local data , err = read ( cuepath )
	if not data then return data , err end
	local files = data.files
	
	local items = { }
	for i = 1 , #files do
		items [ i ] = createitem ( data , i , 0 )
	end
	return core.item.additems ( pl , pos , items )
end

core.item.types [ sourcetype ] = true
