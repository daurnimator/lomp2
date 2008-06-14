require "general"

module ( "lomp.core.playlist" , package.see ( lomp ) )

function new ( name , pl )
	if type ( name ) ~= "string" or name == "hardqueue" or ( name == "Library" and pl ~= 0 ) then name = "New Playlist" end
	if pl ~= nil and ( type ( pl ) ~= "number" or pl > #vars.pl + 1 or pl < 0 ) then 
		return ferror ( "'New playlist' called with invalid playlist number" )
	end
	
	pl = pl or #vars.pl + 1
	vars.pl [ pl ] = { name = name , revision = 0 }
	vars.pl.revision = vars.pl.revision + 1
	
	updatelog ( "Created new playlist #" .. pl .. " '" .. name .. "'" , 4 )
	return pl , name
end
function delete ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl <= 0 or pl > #vars.pl then -- Uses <= to prevent deletion of library 
		return ferror ( "'Delete playlist' called with invalid playlist" , 1 ) 
	end
	
	local name = vars.pl [ pl ].name
	table.remove ( vars.pl , pl )
	vars.pl.revision = vars.pl.revision + 1
	if pl == vars.queue.softqueuepl then vars.queue.softqueuepl = -1 end -- If deleted playlist was the soft queue
	
	updatelog ( "Deleted playlist #" .. pl .. " (" .. name .. ")" , 4 )
	return pl
end
function clear ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then 
		return ferror ( "'Clear playlist' called with invalid playlist" , 1 ) 
	end
	
	--vars.pl [ pl ] = { name = name ; revision = revision + 1 }
	
	repeat
		table.remove ( vars.pl [ pl ]  )
	until not vars.pl [ pl ] [ 1 ] 
	vars.pl [ pl ].revision = vars.pl [ pl ].revision + 1
	
	updatelog ( "Cleared playlist #" .. pl .. " (" .. vars.pl [ pl ].name .. ")" , 4 )
	return pl
end
