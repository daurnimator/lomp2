--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , loadstring , pairs , print , require , select , setfenv , tostring , type = ipairs , loadstring , pairs , print , require , select , setfenv , tostring , type
local tblconcat , tblserialise = table.concat , table.serialise
local debugtraceback = debug.traceback

module ( "lomp" )

require "lomp-core"
require "core.info"

function core.listpl ( )
	local info = core.info.getlistofplaylists ( )
	local t = { "Listing Playlists:" } 
	for i , v in ipairs ( info ) do
		t [ #t + 1 ] = "Playlist #" .. v.index .. "\t" .. v.name .. "\trev: " .. v.revision .. " Items " .. v.items .. "\n"
	end
	return tblconcat ( t , "\n" )
end

function core.listentries ( pl )
	local info , revision = core.playlist.fetch ( pl )
	local t = { "Listing Playlist #" .. pl .. " \t(Revision: " .. revision .. ")" }
	for i , v in ipairs ( info ) do
		t [ #t + 1 ] = "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'"
	end
	return tblconcat ( t , "\n" )
end

function core.listallentries ( )
	local t = { }
	for k , v in pairs ( vars.playlist ) do if type ( k ) == "number" then
		t [ #t + 1 ] = core.listentries ( k )
	end end
	return tblconcat ( t , "\n"  )
end

function core.listqueue ( )
	local t = { "Listing Queue" , "Soft Queue is currently: " .. vars.softqueueplaylist ,
		"Currently Looping? " .. tostring ( vars.loop ) }
		
	if vars.queue[0] then
		t [ #t + 1 ] = "Current Song: " .. " \t(" .. vars.queue [ 0 ].typ .. ") \tSource: '" .. vars.queue [ 0 ].source
	end
	local i = 1
	while true do
		local v = vars.queue [ i ]
		if not v then break end
		t [ #t + 1 ] = "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "' "
		i = i + 1
	end
	return vars.queue , tblconcat ( t , "\n"  )
end

function core.listplayed ( )
	local t = { "Listing Played Songs (most recent first) \t(Last Revision: " .. vars.played.revision .. ")" }
	for i , v in ipairs ( vars.played ) do
		t [ #t + 1 ] = "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'"
	end
	return vars.played , tblconcat ( t , "\n"  )
end

function pv ( )
	p ( "=========== PRINT OUT OF STATE: \n" )
	p ( "Current State: " .. core.playback.state .. "\n")
	p ( core.listpl ( ) )
	p ( core.listallentries ( ) )
	p ( select( 2 , core.listqueue ( ) ) )
	p ( select( 2 , core.listplayed ( ) ) )
	p ( "=========== END PRINT OUT" )
	return true
end

p = print
pp = function(o) print(tblserialise(o)) end
pt = function() print(debugtraceback()) end

core.triggers.register ( "playback_startsong" , function ( )
		-- Print new song stats
		local t = vars.currentsong
		print( "--------------------Now playing file: ", t.filename )
		for k , v in pairs ( t ) do
			print ( "", k , v )
		end
		print ( "" , "length" , t.length )
		print ( "==== Tags:" )
		for tag , val in pairs ( t.tags ) do
			for i , v in ipairs ( val ) do
				print ( "" , "Tag:" , tag , " = " , v ) 
			end
		end
		print ( "----------------------------------------------------------------" )
	end , "Print song stats to screen" )
