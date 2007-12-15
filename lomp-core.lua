require"general"
require"ex"

module ( "lomp" , package.seeall )

local t = os.time ( )
core = { }
vars = { 
	init= t ,
	pl = {
		rev = 0 ,
	} ,
	queue = { 
		rev = 0 ,
		gap = 1 , -- Gap is first soft item
		softqueuepl = 0 , -- Default soft playlist (0 = Library)
		ploffset = 0 , -- Current play position (offset) in soft playlist. Add to gap to get playlist position overall. BUT, softplaylist should only be active when gap==1
	} ,
	played = { 
		rev = 0 ,
	} ,
	shuffle = false , -- Mix up soft playlist?
	rpt = true -- When end of soft playlist reached, go back to start of soft playlist?
}

function core.newpl ( title , pl )
	title = title or "New Playlist"
	pl = pl or #vars.pl + 1
	vars.pl[pl] = { name = title , rev = 0 }
	vars.pl.rev = vars.pl.rev + 1
	return pl
end
core.newpl ( "Library" , 0 ) -- Create Library (Just playlist 0)
function core.deletepl ( pl )
	if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , pl ) end
	assert ( ( type( pl ) == "number" and pl > 0 and pl < #vars.pl ) , "Provide a playlist" )
	table.remove ( vars.pl , pl )
	vars.pl.rev = vars.pl.rev + 1
	if pl == vars.queue.softqueuepl then core.updatesoftqueue ( ) end -- If deleted playlist was the soft queue:
	return pl
end
function core.listpl ( )
	local s = "Playlists: (Last Revision: " .. vars.pl.rev .. ")\n"
	for i , v in ipairs( vars.pl ) do
		s = s .. "Playlist #" .. i .. "\t" .. v.name .. " \tRevision " .. v.rev.. "\n"
	end
	return vars.pl , s
end
function core.addfile ( path , pl , noupdate , metadata )
	assert ( path , "No path provided" )
	local pos, place
	metadata = metadata or {}
	if not pl then --ADD TO HARD QUEUE
		place = vars.queue
		pos = 1		
	else --ADD to a playlist
		if type( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
		assert ( type ( pl ) == "number" , "Provide a playlist" )
		pos = #vars.pl[pl] + 1
		place = vars.pl[pl]
	end
	-- Read TAGS
	--metadata 
	table.insert ( place , pos , { typ = "file" , source = path , metadata = metadata , progress = 0 } )
	place.rev = place.rev + 1
	if pl then vars.pl.rev = vars.pl.rev + 1 end
	if not noupdate and ( pl == vars.queue.softqueuepl ) then core.updatesoftqueue ( ) end -- Update softqueue if appropriate
	return pos , pl
end
function core.addstream ( url , pl , noupdate )
	assert ( url , "No url provided" )
	local pos, place
	local metadata = { }
	if not pl then --ADD TO HARD QUEUE
		place = vars.queue
		pos = 1		
	else --ADD to a playlist
		if type( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
		assert ( type ( pl ) == "number" , "Provide a playlist" )
		pos = #vars.pl[pl] + 1
		place = vars.pl[pl]
	end
	-- Read TAGS
	--metadata 
	table.insert ( place , pos , { typ = "stream" , source = url , metadata = metadata , progress = 0 } )
	place.rev = place.rev + 1
	if pl then vars.pl.rev = vars.pl.rev + 1 end
	if noupdate and ( pl == vars.queue.softqueuepl ) then core.updatesoftqueue ( ) end -- Update softqueue if appropriate
	return pos , pl
end
function core.addfolder ( path , pl , recurse , noupdate ) --Path without trailing slash
	assert ( path , "No path provided" )
	if type( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	if string.sub ( path , -1) == "/" then path = string.sub ( path , 1 , ( string.len( path ) - 1 ) ) end -- Remove trailing slash if needed
	local firstpos
	local tbl = { }
	for entry in os.dir ( path ) do
		if entry.type == "file" then
			table.insert ( tbl , { p = path .. "/" .. entry.name , s = entry.size } )
		elseif entry.type == "directory" then
			if recurse then core.addfolder ( path .. entry.name .. "/" , pl , true , true ) end
		end
	end
	if config.sortcaseinsensitive ~= false then table.sort ( tbl , function (a,b) if string.lower( a.p ) < string.lower( b.p ) then return true end end) end-- Put in alphabetical order of path (case insensitive) 
	for i , v in ipairs ( tbl ) do
		local a , b = core.addfile ( v.p , pl , true , { filesize = v.s } )
		firstpost = firstpost or a
	end
	if noupdate and ( pl == vars.queue.softqueuepl ) then core.updatesoftqueue ( ) end
	return firstpos , pl , tbl
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
function core.removeplentry ( pos , pl )
	if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , pl ) end
	assert ( type( pl ) == "number" , "Provide a playlist" )
	assert ( type( entry ) == "number" , "Provide an entry" )
	local tmp = vars.pl[pl][pos]
	table.remove ( vars.pl[pl] , pos )
	vars.pl[pl].rev = vars.pl[pl].rev + 1
	vars.pl.rev = vars.pl.rev + 1
	if pl == vars.queue.softqueuepl then core.updatesoftqueue ( ) end
	return tmp
end
function core.copytoplaylist ( oldentry , oldpl , pl , pos )
	if type ( oldpl ) == "string" then oldpl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( oldpl ) == "number" , "Provide a playlist" )
	assert ( type ( oldentry ) == "number" , "Provide an entry" )
	if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	local pos = pos or #(vars.pl[pl]) + 1 -- If new position not given, add to end.
	assert ( type ( pos ) == "number" , "Provide an entry" )
	table.insert ( vars.pl[pl] , pos , vars.pl[oldpl][oldentry] )
	vars.pl[pl].rev = vars.pl[pl].rev + 1
	vars.pl.rev = vars.pl.rev + 1
	if pl == vars.queue.softqueuepl then core.updatesoftqueue ( ) end
	return pl[newpos]
end
function core.movetoplaylist ( oldentry , oldpl , pl , pos )
	if type ( oldpl ) == "string" then oldpl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( oldpl ) == "number" , "Provide a playlist" )
	assert ( type ( oldentry ) == "number" , "Provide an entry" )
	if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	local pos = pos or #(vars.pl[pl]) + 1 -- If new position not given, add to end.
	assert ( type ( pos ) == "number" , "Provide an entry" )
	local tmp = core.removeplentry ( oldentry , oldpl )
	table.insert ( vars.pl[pl] , pos , tmp )
	vars.pl[pl].rev = vars.pl[pl].rev + 1
	vars.pl.rev = vars.pl.rev + 1
	if pl == vars.queue.softqueuepl or oldpl ==  vars.queue.softqueuepl then core.updatesoftqueue ( ) end
	return pl[newpos]
end

-- Queue Stuff
 -- In the queue:
  -- 0 = currently playing
  -- played table = history
  -- postive until "gap" = next (queued)
  -- after "gap" = playlist to goto's contents
  
function core.updatesoftqueue ( pl )
	if pl then
		if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
		assert ( type ( pl ) == "number" , "Provide a playlist" )
		vars.queue.softqueuepl = pl
		-- If we change the soft playlist, reset it
		vars.queue.ploffset = 0
	end
	table.sever ( vars.queue , vars.queue.gap-1 )	
	table.append ( vars.queue , vars.pl[vars.queue.softqueuepl] )
	vars.queue.rev = vars.queue.rev + 1
	updatelog ( "Updated soft queue\n" , 1 )
	return true
end
function core.addtoqueue ( pl , entry , pos )
	assert ( type ( entry ) == "number" , "Provide an entry" )
	if type ( pl ) == "string" then pl = valuetoindex ( vars.pl , "name" , key ) end
	assert ( type ( pl ) == "number" , "Provide a playlist" )
	if type( pos ) ~= "number" then pos = nil  -- Do not throw error if pos is not a number, just add to end of set queue
	elseif pos > vars.queue.gap then local a = "Cannot add soft playlist items. Please add to playlist instead" updatelog ( a , 1 ) return false , a end
	local pos = pos or vars.queue.gap
	table.insert ( vars.queue , pos ,  vars.pl[pl][entry] )
	vars.queue.gap = vars.queue.gap + 1
	core.updatesoftqueue ( )
	vars.queue.rev = vars.queue.rev + 1
	return pos
end
function core.removefromqueue ( pos )
	assert ( type ( pos ) == "number" , "Provide an entry" )
	if type( pos ) ~= "number" then pos = nil
	elseif pos > vars.queue.gap then local a = "Cannot remove soft playlist items. Please remove from playlist instead" updatelog ( a , 1 ) return false , a end
	local pos = pos or vars.queue.gap
	table.remove (  vars.queue , pos )
	vars.queue.gap = vars.queue.gap - 1
	core.updatesoftqueue ( )
	vars.queue.rev = vars.queue.rev + 1
	return pos
end
function core.moveinqueue ( oldpos , newpos )
	local tmp = vars.queue[oldpos]
	table.remove ( vars.queue , vars.queue[oldpos] )
	table.insert ( vars.queue , newpos , tmp )
	core.updatesoftqueue ( )
	return true
end
function core.listqueue ( )
	local s = "Listing Queue \t(Last Revision: " .. vars.queue.rev .. ")\nState: " .. lomp.playback.state .. "\n"
	if vars.queue[0] then
		s = s .. "Current Song: " .. " \t(" .. vars.queue[0].typ .. ") \tSource: '" .. vars.queue[0].source .. "'\n"
	end
	for i , v in ipairs( vars.queue ) do
		if i == vars.queue.gap then s = s .. "Soft Playlist Begin (Playlist " .. vars.queue.softqueuepl .. ")\n" end
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "' "
		if i == vars.queue.gap+vars.queue.ploffset then s = s .. "<==" end
		s = s .. "\n"
	end
	return vars.queue , s
end
function core.listplayed ( )
	local s = "Listing Played Songs (most recent first) \t(Last Revision: " .. vars.played.rev .. ")\n"
	for i , v in ipairs( vars.played ) do
		s = s .. "Entry #" .. i .. " \t(" .. v.typ .. ") \tSource: '" .. v.source .. "'\n"
	end
	return vars.played , s
end

math.randomseed (os.time()) -- For good measure