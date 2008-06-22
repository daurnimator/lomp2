--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"
require "ex"

module ( "lomp" , package.seeall )

require "lomp-core"

function core.listpl ( str )
	local t = { }
	t [ 0 ] = { name = vars.pl [ 0 ].name , revision = vars.pl [ 0 ].revision }
	for i , v in ipairs ( vars.pl ) do
		t [ i ] = { name = v.name , revision = v.revision }
	end
	if str then
		str = "Playlists: (Last Revision: " .. vars.pl.revision .. ")\n"
		for i , v in ipairs( t ) do
			str = str .. "Playlist #" .. i .. "\t" .. v.name .. " \tRevision " .. v.revision.. "\n"
		end
	end
	return t , str
end

function core.listentries ( pl )
	if type( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	local s = "Listing Playlist #" .. pl .. " \t(Last Revision: " .. vars.pl[pl].revision .. ")\n"
	for i , v in ipairs( vars.pl[pl] ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return vars.pl [ pl ] , s
end

function core.listallentries ( )
	local s = ""
	for i,v in ipairs(lomp.vars.pl) do
		s = s .. select ( 2, lomp.core.listentries ( i ) )
	end
	return vars.pl , s
end

function core.listqueue ( )
	local s = "Listing Queue\nState: " .. lomp.playback.state .. "\nSoft Queue is currently: " .. vars.softqueuepl .. "\n"
	if vars.queue[0] then
		s = s .. "Current Song: " .. " \t(" .. vars.queue [ 0 ].o.typ .. ") \tSource: '" .. vars.queue [ 0 ].o.source .. "'\n"
	end
	i = 1
	while true do
		local v = vars.queue [ i ]
		if not v then break end
		s = s .. "Entry #" .. i .. " \t(" .. v.o.typ .. ") \tSource: '" .. v.o.source .. "' " .. "\n"
		i = i + 1
	end
	return vars.queue , s
end

function core.listplayed ( )
	local s = "Listing Played Songs (most recent first) \t(Last Revision: " .. vars.played.revision .. ")\n"
	for i , v in ipairs( vars.played ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.o.typ .. ") \tSource: '" .. v.o.source .. "'\n"
	end
	return vars.played , s
end

function getvar ( varstring )
	if type ( varstring ) ~= "string" then return false end
	local var = vars
	for k in string.gmatch ( varstring , "(%w+)%." ) do
		var = var [ k ]
	end
	var = var [ select ( 3 , string.find ( varstring , "([^%.]+)$" ) ) ]
	
	if type ( var ) == "function" then return false
	else return var
	end
end

function playsongfrompl ( pl , pos )
	core.setsoftqueueplaylist ( pl )
	core.clearhardqueue ( )
	playback.goto ( pos )
	playback.play ( )
	return true
end
	
function demo ( )
	core.refreshlibrary ( )
	local pl = core.playlist.new ( "Flac Files" )
	core.addfile ( '/media/sdd1/Temp/Done Torrents/Daft Punk - Aerodynamic,Aerodynamite (2001) [FLAC] {CDS}/01 - Aerodynamic.flac' , pl )
	core.addfile ( '/media/sdd1/Temp/Torrents/Rage Against The Machine - Rage Against The Machine (1992) [FLAC]/02 - Killing In The Name.flac' , pl )
	core.addfile ( '/media/sdd1/Temp/Done Torrents/Daft Punk - Aerodynamic,Aerodynamite (2001) [FLAC] {CDS}/02 - Aerodynamite.flac' , pl )
	--core.addfile ( "/media/sdc1/Downloaded/Zombie Nation, Kernkraft 400 CDS/[03] Zombie Nation - Kernkraft 400.wv" , pl ) 
	core.setsoftqueueplaylist ( 1 )
	pv ( )
	

	--playback.play ( )
	--playback.nxt ( )
	os.sleep ( 1 )
	--print(player.getstate ( ))
	playback.next ( )
	playback.play ( )
	--os.sleep ( 1 )
	--playsongfrompl ( 0 , 2 )
	--os.sleep ( 5 )
	--core.quit ( )
	return true
end
function a ( ... ) print ("testing!", ... ) return "test done" end
function pv ( )
	p ( "Current State: " .. playback.state )
	p ( select( 2 , core.listpl ( ) ) )
	p ( select( 2 , core.listentries ( 0 ) ) )
	p ( select( 2 , core.listallentries ( ) ) )
	p ( select( 2 , core.listqueue ( ) ) )
	p ( select( 2 , core.listplayed ( ) ) )
	return true
end
--[[function p (...)
	if type ( select ( 1 , ... ) ) == "string" then 
	print ( ... )
	elseif type ( select ( 1 , ... ) ) == "table" then for k,v in pairs((...)) do p(...) end
	end
end--]] p = print
