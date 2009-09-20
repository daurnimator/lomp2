--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pcall , require , type , unpack = ipairs , pcall , require , type , unpack
local tblsort , tblappend = table.sort , table.append

module ( "lomp.core.localfileio" , package.see ( lomp ) )

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

local lfs = require "lfs"

function addfile ( path , pl , pos )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add file' called with invalid path" , 1 ) end
	
	local filename = path:match ( "([^/]+)$" )
	local a , err = core.checkfileaccepted ( filename )
	if a then
		local o = core.item.create ( "file" , path )
		return core.item.additem ( o , pl , pos )
	else
		return ferror ( err , 2 )
	end
end

-- Returns an array of items
local function getdir ( path , recurse )
	local items = { }
	
	for entry in lfs.dir ( path ) do
		local fullpath = path .. "/" .. entry
		local mode = lfs.attributes ( fullpath , "mode" )
		if mode == "file" then
			local a , err = core.checkfileaccepted ( fullpath )
			if a then
				items [ #items + 1 ] = core.item.create ( "file" , fullpath )
			else -- no return - keep going (even after a failure)
				ferror ( err , 5 )
			end
		elseif mode == "directory" and entry ~= "." and entry ~= ".." then
			if recurse > 0 then 
				tblappend ( items , getdir ( fullpath , recurse - 1 ) )
			end
		end
	end
	
	return items
end

function addfolder ( path , pl , pos , recurse )
	if recurse then
		if type ( recurse ) ~= "number" then
			recurse = 500 -- Max 500 level deep recursion
		end
	else
		recurse = 0
	end
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add folder' called with invalid path" , 1 ) end
	if path:sub ( -1) == "/" then path = path:sub ( 1 , ( #path - 1 ) ) end -- Remove trailing slash if needed
	
	if type ( pl ) ~= "number" or not vars.playlist [ pl ] then return ferror ( "'Add folder' called with invalid playlist" , 1 ) end
	if type ( pos ) ~= "number" then pos = nil end
	
	updatelog ( "Adding folder '" .. path .. "' to playlist #" .. pl , 3 )
	
	local items = getdir ( path , recurse )
	
	if #items == 0 then return true end
	
	if config.sortcaseinsensitive then tblsort ( items , function ( a , b ) if a.source:lower ( ) < b.source:lower ( ) then return true end end ) end -- Put in alphabetical order of path (case insensitive) 
	
	local firstpos , err = core.item.additems ( pl , pos , items )
	if firstpos then
		return firstpos
	else
		return false , err
	end
end
