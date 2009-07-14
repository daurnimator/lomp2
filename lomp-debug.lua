--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp" , package.seeall )

require "lomp-core"
require "core.info"

function core.listpl ( )
	local info = core.info.getlistofplaylists ( )
	local str = "Listing Playlists:\n" 
	for i , v in ipairs ( info ) do
		str = str .. "Playlist #" .. v.index .. "\t" .. v.name .. "\trev: " .. v.revision .. " Items " .. v.items .. "\n"
	end
	return str
end

function core.listentries ( pl )
	local info = core.playlist.fetch ( pl )
	local s = "Listing Playlist #" .. pl .. " \t(Revision: " .. info.revision .. ")\n"
	for i , v in ipairs ( info ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return s
end

function core.listallentries ( )
	local s = ""
	for k , v in pairs ( vars.playlist ) do if type ( k ) == "number" then
		s = s .. core.listentries ( k )
	end end
	return s
end

function core.listqueue ( )
	local s = "Listing Queue\nSoft Queue is currently: " .. vars.softqueuepl .. "\n"
	s = s .. "Currently Looping? " .. tostring ( vars.loop ) .. "\n"
	if vars.queue[0] then
		s = s .. "Current Song: " .. " \t(" .. vars.queue [ 0 ].typ .. ") \tSource: '" .. vars.queue [ 0 ].source .. "'\n"
	end
	i = 1
	while true do
		local v = vars.queue [ i ]
		if not v then break end
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "' " .. "\n"
		i = i + 1
	end
	return vars.queue , s
end

function core.listplayed ( )
	local s = "Listing Played Songs (most recent first) \t(Last Revision: " .. vars.played.revision .. ")\n"
	for i , v in ipairs ( vars.played ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return vars.played , s
end

function getvar ( varstring )
	if type ( varstring ) ~= "string" then return false end
	--[[local var = vars
	for k in string.gmatch ( varstring , "(%w+)%." ) do
		var = var [ k ]
	end
	var = var [ select ( 3 , string.find ( varstring , "([^%.]+)$" ) ) ]
	if type ( var ) == "function" then return false
	--]]
	local f = loadstring ( "return " .. varstring )
	setfenv ( f , vars )
	return f ( )
end

function playsongfrompl ( pl , pos )
	core.setsoftqueueplaylist ( pl )
	core.clearhardqueue ( )
	core.playback.goto ( pos )
	core.playback.play ( )
	return true
end
	
function demo ( )
	core.reloadlibrary ( )
	local pl = core.playlist.new ( "Flac Files" )
	core.localfileio.addfile ( '/media/sdc1/Random Downloaded/Andrew Desilva - Just Like Good Music (Quazimodo elctric disco 12.MP3' , pl )
	--core.localfileio.addfile ( '/media/windows/Documents and Settings/Daurnimator/My Documents/My Music/Destroy Rock & Roll/Mylo - 5 in My Arms.mp3' , pl )
	--core.localfileio.addfile ( '/media/windows/Documents and Settings/Daurnimator/My Documents/My Music/Destroy Rock & Roll/Mylo - Valley of the Dolls.mp3' , pl )
	core.localfileio.addfile ( "/media/sdc1/Downloaded/Zombie Nation, Kernkraft 400 CDS/[03] Zombie Nation - Kernkraft 400.wv" , pl ) 
	core.setsoftqueueplaylist ( 1 )
	pv ( )
	core.setsoftqueueplaylist ( 0 )

	--core.playback.play ( )
	core.playback.next ( )
	--os.sleep ( 1 )
	--print(player.getstate ( ))
	core.playback.next ( )
	core.playback.play ( )
	--os.sleep ( 1 )
	--playsongfrompl ( 0 , 2 )
	--os.sleep ( 5 )
	--core.quit ( )
	return true
end
function a ( ... ) print ("testing!", ... ) return "test done" end
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
function showtag ( pl , pos )
	p ( table.serialise ( vars.pl[pl][pos] ) )
end
--[[function p (...)
	if type ( select ( 1 , ... ) ) == "string" then 
	print ( ... )
	elseif type ( select ( 1 , ... ) ) == "table" then for k,v in pairs((...)) do p(...) end
	end
end--]] p = print

triggers.registercallback ( "playback_startsong" , function ( )
		-- Print new song stats
		local t = vars.queue [ 0 ]
		print( "--------------------Now playing file: ", t.filename )
		for k , v in pairs ( t ) do
			print ( "", k , v )
		end
		print ( "==== Tags:" )
		for tag , val in pairs ( t.tags ) do
			for i , v in ipairs ( val ) do
				print ( "" , "Tag:" , tag , " = " , v ) 
			end
		end
		print ( "----------------------------------------------------------------" )
	end , "Print song stats to screen" )
