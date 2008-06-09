require"general"
require"ex"

module ( "lomp" , package.seeall )

require"lomp-core"

function core.listpl ( )
	local s = "Playlists: (Last Revision: " .. vars.pl.rev .. ")\n"
	for i , v in ipairs( vars.pl ) do
		s = s .. "Playlist #" .. i .. "\t" .. v.name .. " \tRevision " .. v.rev.. "\n"
	end
	return vars.pl , s
end

function core.listentries ( pl )
	print (pl)
	if type( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	local s = "Listing Playlist #" .. pl .. " \t(Last Revision: " .. vars.pl[pl].rev .. ")\n"
	for i , v in ipairs( vars.pl[pl] ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return vars.pl[pl] , s
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
		s = s .. "Current Song: " .. " \t(" .. vars.queue[0].typ .. ") \tSource: '" .. vars.queue[0].source .. "'\n"
	end
	local n = #vars.queue + #vars.pl [ vars.softqueuepl ]
	for i=1,n do
		local v = vars.queue [ i ]
		--print( v.source )
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "' " .. "\n"
	end
	return vars.queue , s
end

--[[function core.listplayed ( )
	local s = "Listing Played Songs (most recent first) \t(Last Revision: " .. vars.played.rev .. ")\n"
	for i , v in ipairs( vars.played ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return vars.played , s
end]]

	function playsongfrompl ( pl , pos )
		core.setsoftqueueplaylist ( pl )
		core.clearhardqueue ( )
		playback.goto ( pos )
		playback.play ( )
	end
	
function demo ( )
	core.refreshlibrary ( )
	local pl = core.newplaylist ( "Flac Files" )
	core.addfile ( '/media/sdd1/Temp/Done Torrents/Daft Punk - Aerodynamic,Aerodynamite (2001) [FLAC] {CDS}/01 - Aerodynamic.flac' , pl )
	core.addfile ( '/media/sdd1/Temp/Torrents/Rage Against The Machine - Rage Against The Machine (1992) [FLAC]/02 - Killing In The Name.flac' , pl )
	core.addfile ( '/media/sdd1/Temp/Done Torrents/Daft Punk - Aerodynamic,Aerodynamite (2001) [FLAC] {CDS}/02 - Aerodynamite.flac' , pl )
	--core.addfile ( "/media/sdc1/Downloaded/Zombie Nation, Kernkraft 400 CDS/[03] Zombie Nation - Kernkraft 400.wv" , pl ) 
	core.setsoftqueueplaylist ( 1 )
	pv ( )
	

	playback.play ( )
	os.sleep ( 1 )
	--print(player.getstate ( ))
	playback.nxt ( )
	playback.play ( )
	--os.sleep ( 1 )
	--playsongfrompl ( 0 , 2 )
	--os.sleep ( 5 )
	--core.quit ( )
end
function a ( ... ) print ("testing!", ... ) return "test done" end
function pv ( )
	p ( "Current State: " .. playback.state )
	p ( select( 2 , core.listpl ( ) ) )
	p ( select( 2 , core.listentries ( 0 ) ) )
	p ( select( 2 , core.listallentries ( ) ) )
	p ( select( 2 , core.listqueue ( ) ) )
	--p ( select( 2 , core.listplayed ( ) ) )
end
--[[function p (...)
	if type ( select ( 1 , ... ) ) == "string" then 
	print ( ... )
	elseif type ( select ( 1 , ... ) ) == "table" then for k,v in pairs((...)) do p(...) end
	end
end--]] p = print
