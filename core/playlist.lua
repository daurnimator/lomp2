--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.playlist" , package.see ( lomp ) )

function okpl ( pl )
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then
		return false
	end	
end

function new ( name , pl )
	if type ( name ) ~= "string" or name == "hardqueue" or ( name == "Library" and pl ~= 0 ) then name = "New Playlist" end
	if pl ~= nil and ( type ( pl ) ~= "number" or pl > #vars.pl + 1 or pl < -1 ) then 
		return ferror ( "'New playlist' called with invalid playlist number" , 2 )
	end
	
	pl = pl or #vars.pl + 1
	vars.pl [ pl ] = { name = name , revision = 0 }
	vars.pl.revision = vars.pl.revision + 1
	
	updatelog ( "Created new playlist #" .. pl .. " '" .. name .. "'" , 4 )
	return pl , name
end
function delete ( pl )
	pl = okpl ( pl )
	if not pl then
		return ferror ( "'Delete playlist' called with invalid playlist" , 2 ) 
	end
	
	local name = vars.pl [ pl ].name
	table.remove ( vars.pl , pl )
	vars.pl.revision = vars.pl.revision + 1
	if pl == vars.queue.softqueuepl then vars.queue.softqueuepl = -1 end -- If deleted playlist was the soft queue
	
	updatelog ( "Deleted playlist #" .. pl .. " (" .. name .. ")" , 4 )
	return pl
end
function clear ( pl )
	pl = okpl ( pl )
	if not pl then
		return ferror ( "'Clear playlist' called with invalid playlist" , 2 ) 
	end
	
	--vars.pl [ pl ] = { name = name ; revision = revision + 1 }
	
	repeat
		table.remove ( vars.pl [ pl ]  )
	until not vars.pl [ pl ] [ 1 ] 
	
	vars.pl [ pl ].revision = vars.pl [ pl ].revision + 1
	
	updatelog ( "Cleared playlist #" .. pl .. " (" .. vars.pl [ pl ].name .. ")" , 4 )
	return pl
end
function randomise ( pl )
	pl = okpl ( pl )
	if not pl then
		return ferror ( "'Randomise playlist' called with invalid playlist" , 2 ) 
	end
	
	table.randomize ( vars.pl [ pl ] )
	vars.pl [ pl ].revision = vars.pl [ pl ].revision + 1
	
	updatelog ( "Randomised playlist #" .. pl .. " (" .. vars.pl [ pl ].name .. ")" , 4 )
	return pl
end
function sort ( pl , reverse , field , subfield )
	pl = okpl ( pl )
	if not pl then
		return ferror ( "'Sort playlist' called with invalid playlist" , 2 ) 
	end

	if type ( field ) ~= "string" then return ferror ( "'Sort playlist' called with invalid field" , 2 ) end
	if subfield and type ( subfield ) ~= "string" then return ferror ( "'Sort playlist' called with invalid subfield" , 2 ) end
	
	local function eq ( e1 , e2 )
		e1 = e1.details [ field ]
		e2 = e2.details [ field ]
		if subfield then
			e1 = e1 [ subfield ]
			e2 = e2 [ subfield ]
		end
		
		if not reverse then
			if e1 < e2 then return true else return false end
		else
			if e1 > e2 then return true else return false end
		end
	end
	table.stablesort ( vars.pl [ pl ] , eq )
	vars.pl [ pl ].revision = vars.pl [ pl ].revision + 1
	
	updatelog ( "Sorted playlist #" .. pl .. " (" .. vars.pl [ pl ].name .. ")" , 4 )
	return pl
end
