require"general"
require"ex"

module ( "lomp" , package.seeall )

local t = os.time ( )
core = { _NAME = "LOMP" , _VERSION = "0.0.1" }
vars = { 
	init= t ,
	pl = {
		rev = 0 ,
	} ,
	hardqueue = { 
		rev = 0 ,
	} ,
	played = { 
		rev = 0 ,
	} ,
	shuffle = false , -- Mix up soft playlist?
	rpt = true , -- When end of soft playlist reached, go back to start of soft playlist?
	softqueuepl = nil , 
	ploffset = 0 ,
}

function core.newplaylist ( name , pl )
	if type ( name ) ~= "string" or name == "hardqueue" or ( name == "Library" and pl ~= 0 ) then name = "New Playlist" end
	if pl ~= nil and ( type ( pl ) ~= "number" or pl > #vars.pl + 1 or pl < 0 ) then 
		updatelog ( "'New playlist' called with invalid playlist number" , 1 ) 
		return false , "'New playlist' called with invalid playlist number"
	else
		pl = pl or #vars.pl + 1
		vars.pl [ pl ] = { name = name , rev = 0 }
		vars.pl.rev = vars.pl.rev + 1
		updatelog ( "Created new playlist #" .. pl .. " '" .. name .. "'" , 4 )
		return pl , name
	end
end
core.newplaylist ( "Library" , 0 ) -- Create Library (Just playlist 0)
function core.deleteplaylist ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl <= 0 or pl > #vars.pl then 
		updatelog ( "'Delete playlist' called with invalid playlist" , 1 ) 
		return false , "'Delete playlist' called with invalid playlist"
	end
	table.remove ( vars.pl , pl )
	vars.pl.rev = vars.pl.rev + 1
	if pl == vars.queue.softqueuepl then vars.queue.softqueuepl = nil end -- If deleted playlist was the soft queue
	return pl
end
function core.addentry ( object , pl , pos )
	local place
	if pl == nil or pl == "hardqueue" then -- If no playlist given, or expressly stated: add to hard queue
		place = vars.hardqueue
	else	
		if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
		if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
			updatelog ( "'Add entry' called with invalid playlist" , 1 )
			return false , "'Add entry' called with invalid playlist"
		end
		place = vars.pl [ pl ]
	end
	if type ( pos ) ~= "number" then
		if pos == nil or pos > #place then pos = #place + 1 -- Add to end of playlist/queue
		elseif pos < 1 then pos = 1
		else
			updatelog ( "'Add entry' called with invalid position" , 1 )
			return false , "'Add entry' called with invalid position"
		end
	end
	
	table.insert ( place , pos , object )
	place.rev = place.rev + 1
	
	
	return ( pl or "hardqueue" ) , pos , object
end

function core.addfile ( path , pl , pos )
	-- Check path exists
	if type ( path ) ~= "string" then
		updatelog ( "'Add file' called with invalid path" , 1 ) 
		return false , "'Add file' called with invalid path"
	end
	
	local _ , _ , extension = string.find ( path , "%.(.+)$" )
	--if not config.banextensions[extension] then end
	
	local o = { typ = "file" , source = path , progress = 0 }
	
	return core.addentry ( o , pl , pos )
end
function core.addstream ( url , pl , pos )
	-- Check url is valid
	if type ( url ) ~= "string" then
		updatelog ( "'Add stream' called with invalid url" , 1 ) 
		return false , "'Add stream' called with invalid url"
	end
	
	local o = { typ = "stream" , source = url , progress = 0 }
	
	return core.addentry ( o , pl , pos )
end
function core.addfolder ( path , pl , pos , recurse )
	-- Check path exists
	if type ( path ) ~= "string" then
		updatelog ( "'Add folder' called with invalid path" , 1 ) 
		return false , "'Add folder' called with invalid path"
	end
	if string.sub ( path , -1) == "/" then path = string.sub ( path , 1 , ( string.len( path ) - 1 ) ) end -- Remove trailing slash if needed
	if type ( pos ) ~= "number" then pos = nil end
	
	local dircontents = { }
	for entry in os.dir ( path ) do
		if entry.type == "file" then
			dircontents [ #dircontents + 1 ] = path .. "/" .. entry.name
			--table.insert ( dircontents , { path = path .. "/" .. entry.name , s = entry.size , ext = extension } ) 
		elseif entry.type == "directory" then
			if recurse then core.addfolder ( path .. "/" .. entry.name , pl , true , true ) end
		end
	end
	if config.sortcaseinsensitive then table.sort ( dircontents , function ( a , b ) if string.lower ( a ) < string.lower ( b ) then return true end end ) end-- Put in alphabetical order of path (case insensitive) 
	local firstpos = nil
	for i , v in ipairs ( dircontents ) do
		local a , b = core.addfile ( v , pl , pos )
		if a then --If not failed
			pl , pos = a , ( b + 1 ) -- Increment playlist position
			firstpos = firstpos or b
		end -- keep going (even after a failure)
	end
	
	return pl , firstpos , dircontents
end
function core.removeentry ( pl , pos )
	local place
	if pl == "hardqueue" then
		place = vars.hardqueue
	else
		if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
		if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
			updatelog ( "'Remove entry' called with invalid playlist" , 1 ) 
			return false , "'Remove entry' called with invalid playlist"
		end
		place = vars.pl [ pl ]
	end
	if type ( pos ) ~= "number" or pos < 1 or pos > #vars.pl [ pl ] then
		updatelog ( "'Remove entry' called with invalid entry" , 1 ) 
		return false , "'Remove entry' called with invalid entry"
	end
	local tmp = vars.pl [ pl ] [ pos ]
	table.remove ( vars.pl [ pl ] , pos )
	vars.pl [ pl ].rev = vars.pl [ pl ].rev + 1
	return pl , pos , tmp
end
function core.copytoplaylist ( newpl , newpos , oldpl , oldpos )
	local oldplace
	if oldpl == nil or oldpl == "hardqueue" then
		oldplace = vars.hardqueue
	else
		if type ( oldpl ) == "string" then oldpl = table.valuetoindex ( vars.pl , "name" , oldpl ) end
		if type ( oldpl ) ~= "number" or oldpl < 0 or oldpl > #vars.pl then 
			updatelog ( "'Copy to playlist' called with invalid old playlist" , 1 ) 
			return false , "'Copy to playlist' called with invalid old playlist"
		end
		oldplace = vars.pl [ oldpl ]
	end
	if type ( oldpos ) ~= "number" or oldpos < 1 or oldpos > #vars.pl [ pl ] then
		updatelog ( "'Copy to playlist' called with invalid old entry" , 1 ) 
		return false , "'Copy to playlist' called with invalid old entry"
	end
	local newplace
	if newpl == nil or newpl == "hardqueue" then
		newplace = vars.hardqueue
	else
		if type ( newpl ) == "string" then newpl = table.valuetoindex ( vars.pl , "name" , newpl ) end
		if type ( newpl ) ~= "number" or newpl < 0 or newpl > #vars.pl then 
			updatelog ( "'Copy to playlist' called with invalid new playlist" , 1 ) 
			return false , "'Copy to playlist' called with invalid new playlist"
		end
		newplace = vars.pl [ newpl ]
	end
	if type ( newpos ) ~= "number" or newpos < 1 or newpos > #vars.pl [ pl ] then
		if newpos == nil then
			newpos = #newplace + 1 -- If new position is not given, add to end of playlist.
		else
			updatelog ( "'Copy to playlist' called with invalid new entry" , 1 ) 
			return false , "'Copy to playlist' called with invalid new entry"
		end
	end
	
	table.insert ( newplace , newpos , oldplace [ oldpos ] )
	
	if oldpl == newpl then
		-- Copy within a playlist
		vars.pl [ oldpl ].rev = vars.pl [ oldpl ].rev + 1
	else
		-- Copy between playlists
		vars.pl [ oldpl ].rev = vars.pl [ oldpl ].rev + 1
		vars.pl [ newpl ].rev = vars.pl [ newpl ].rev + 1
	end
	
	return newpl , newpos , oldpl , oldpos , newplace [ newpos ]
end
function core.movetoplaylist ( newpl , newpos , oldpl , oldpos )
	local newpl , newpos , oldpl , oldpos = core.copytoplaylist ( newpl , newpos , oldpl , oldpos )
	if not newpl then -- Copy error'd
		return newpl , newpos
	end
	local pl , pos , tmp = core.removeentry ( oldpl , oldpos )
	if not pl then
		return pl , pos
	end
	return newpl , newpos , oldpl , oldpos , tmp
end


-- Queue Stuff  
vars.queue = setmetatable ( vars.hardqueue , {
	__index = function(t, k)
		if type(k) ~= "number" then return nil end
		if k >= 1 and k <= #vars.hardqueue then
			return vars.hardqueue [ k ]
		elseif k >= 1 then
			return vars.pl [ vars.softqueuepl ] [ k - #vars.hardqueue ]
		end
	end,
})
function core.setsoftqueueplaylist ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
		updatelog ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
		return false , "'Set soft queue playlist' called with invalid playlist"
	end
	
	vars.softqueuepl = pl
end
