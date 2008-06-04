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
	local s = "Listing Queue\nState: " .. lomp.playback.state .. "\n"
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


function demo ( )
	core.newplaylist ( )
	core.addfile ( "/media/sdc1/Downloaded/Zombie Nation, Kernkraft 400 CDS/[03] Zombie Nation - Kernkraft 400.wv" , 1 ) 
	core.addfile ( "/media/sdc1/Random Downloaded/Requiem for a Tower.mp3" , 1 )
end
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
