--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.localfileio" , package.see ( lomp ) )

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "lfs"

function addfile ( path , pl , pos )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add file' called with invalid path" , 1 ) end
	
	local _ , _ , filename = string.find ( path , "([^/]+)$" )
	local a , err = core.checkfileaccepted ( filename )
	if a then
		local o = core.item.create ( "file" , path )
		return core.item.additem ( o , pl , pos )
	else
		return ferror ( err , 2 )
	end
end

function addfolder ( path , pl , pos , recurse )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add folder' called with invalid path" , 1 ) end
	if string.sub ( path , -1) == "/" then path = string.sub ( path , 1 , ( string.len( path ) - 1 ) ) end -- Remove trailing slash if needed
	
	if type ( pl ) == "string" then pl = table.valuetoindex ( vars.pl , "name" , pl ) end
	if type ( pl ) ~= "number" or pl < 0 or pl > #vars.pl then return ferror ( "'Add folder' called with invalid playlist" , 1 ) end
	if type ( pos ) ~= "number" then pos = nil end
	
	updatelog ( "Adding folder '" .. path .. "' to playlist #" .. pl , 3 )
	
	local dircontents = { }
	local todo = { }
	for entry in lfs.dir ( path ) do
		local fullpath = path .. "/" .. entry
		local mode = lfs.attributes ( fullpath , "mode" )
		if mode == "file" then
			local a , err = core.checkfileaccepted ( entry )
			if a then
				dircontents [ #dircontents + 1 ] = fullpath
			else -- no return - keep going (even after a failure)
				ferror ( err , 3 )
			end
		elseif mode == "directory" and entry ~= "." and entry ~= ".." then
			if recurse then addfolder ( fullpath , pl , true , true ) end --TODO: max recursion depth?
		end
	end
	if config.sortcaseinsensitive then table.sort ( dircontents , function ( a , b ) if string.lower ( a ) < string.lower ( b ) then return true end end ) end-- Put in alphabetical order of path (case insensitive) 
	local firstpos = nil
	for i , v in ipairs ( dircontents ) do
		local o = core.item.create ( "file" , v )
		local a , b = core.item.additem ( o , pl , pos )
		
		if a then --If not failed
			pl , pos = a , ( b + 1 ) -- Increment playlist position
			firstpos = firstpos or b
		end -- keep going (even after a failure)
	end
	
	return pl , firstpos , dircontents
end
