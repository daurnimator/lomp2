require"general"
require"lfs"
require"player"

module ( "lomp" , package.seeall )
print = print
local t = os.time ( )
core = { 
	_NAME = "LOMP" , 
	_MAJ = 0 ,
	_MIN = 0 ,
	_INC = 1 ,
}

core._VERSION = core._MAJ .. "." .. core._MIN .. "." .. core._INC 

vars = { 
	init= t ,
	pl = {
		[-1] = { } , -- Empty Playlist
		revision = 0 ,
	} ,
	hardqueue = { 
		revision = 0 ,
		name = "Hard Queue"
	} ,
	played = { 
		revision = 0 ,
	} ,
	loop = false , -- Loop soft playlist?
	rpt = true , -- When end of soft playlist reached, go back to start of soft playlist?
	softqueuepl = -1 , 
	ploffset = 0 ,
}

function core.quit ( )
	if core.savestate then 
		local ok , err = core.savestate ( )
	end
	local ok = player.stop ( )
	
	os.exit ( )
end

require "core.savestate"
require "core.playlist"
if not vars.pl [ 0 ] then core.playlist.new ( "Library" , 0 ) end -- Create Library (Just playlist 0)
require "core.entries"

function core.addfile ( path , pl , pos )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add file' called with invalid path" , 1 ) end
	
	local _ , _ , extension = string.find ( path , ".+%.(.-)$" )
	extension = string.lower ( extension )
	
	local accepted = false
	for i , v in ipairs ( player.extensions ) do
		if extension == v then accepted = true end
	end
	if accepted == true then 
		for i , v in ipairs ( config.banextensions ) do
			if extension == v then return ferror ( "Banned file extension attempted to be added: " .. extension , 2 ) end
		end
	else	return ferror ( "Attempt to add invalid file type (" .. extension .. "): " .. path , 2 )
	end
	
	local o = { typ = "file" , source = path }
	
	return core.addentry ( o , pl , pos )
end
function core.addstream ( url , pl , pos )
	-- Check url is valid
	if type ( url ) ~= "string" then return ferror ( "'Add stream' called with invalid url" , 1 ) end
	
	local o = { typ = "stream" , source = url }
	
	return core.addentry ( o , pl , pos )
end
function core.addfolder ( path , pl , pos , recurse )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add folder' called with invalid path" , 1 ) end
	if string.sub ( path , -1) == "/" then path = string.sub ( path , 1 , ( string.len( path ) - 1 ) ) end -- Remove trailing slash if needed
	
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then return ferror ( "'Add folder' called with invalid playlist" , 1 ) end
	if type ( pos ) ~= "number" then pos = nil end
	
	local dircontents = { }
	for entry in lfs.dir ( path ) do
		local fullpath = path .. "/" .. entry
		local mode = lfs.attributes ( fullpath , "mode" )
		if mode == "file" then
			dircontents [ #dircontents + 1 ] = fullpath
		elseif mode == "directory" then
			if recurse then core.addfolder ( fullpath , pl , true , true ) end
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
function core.clearhardqueue ( )
	vars.hardqueue = { 
		revision = vars.hardqueue.revision + 1 ,
		name = "Hard Queue" 
	}
	return true
end
function core.setsoftqueueplaylist ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
		return ferror ( "'Set soft queue playlist' called with invalid playlist" , 1 ) 
	end
	
	vars.softqueuepl = pl
	
	-- Reset offset
	vars.ploffset = 0
	
	return pl
end

-- History Stuff
function core.clearhistory ( )
	local oldrevision = vars.played.revision or 0
	vars.played = { revision = ( oldrevision + 1 ) ; }
	return true
end
function core.removefromhistory ( pos )
	table.remove ( vars.played , pos )
	vars.played.revision = vars.played.revision + 1
	return true
end

-- Misc Helper Functions
function core.refreshlibrary ( )
	core.playlist.clear ( 0 )
	for i , v in ipairs ( config.library ) do
		core.addfolder ( v , 0 )
	end
end
function core.enablelooping ( )
	vars.loop = true
	return true
end
function core.disablelooping ( )
	vars.loop = false
	return true
end
