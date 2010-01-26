--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pcall , require , type , unpack = ipairs , pcall , require , type , unpack
local strfind = string.find
local tblsort , tblappend = table.sort , table.append
local ioopen = io.open

module ( "lomp.core.localfileio" , package.see ( lomp ) )

require "core.item"

local lfs = require "lfs"

local function createitem ( path )
	return core.item.create ( "file" , path )
end

function checkfileaccepted ( path )
	local extension = path:match ( "%.?([^%./]+)$" )
	extension = extension:lower ( )
	
	local accepted = false
	for i , v in ipairs ( player.extensions ) do
		if extension == v then accepted = true end
	end
	if accepted == true then 
		for i , v in ipairs ( config.banextensions ) do
			if strfind ( extension , v ) then return false , ( "Banned file extension (" .. extension .. "): " .. path )  end
		end
	else	
		return false , ( "Invalid file type (" .. extension .. "): " .. path )
	end
	return true
end

function addfile ( path , pl , pos )
	-- Check path exists
	if type ( path ) ~= "string" then return ferror ( "'Add file' called with invalid path" , 1 ) end
	
	local filename = path:match ( "([^/]+)$" )
	local a , err = checkfileaccepted ( filename )
	if not a then return ferror ( err , 2 ) end
	
	local fd , err = ioopen ( path , "r" )
	if not fd then return ferror ( "Unable to add file: '" .. path .. "' : " .. err , 1 ) end
	fd:close ( )
	
	local item = createitem ( path )
	return core.item.additem ( pl , pos , item )
end

-- Returns an array of items
local function getdir ( path , recurse , hiddenfiles )
	local items = { }
	
	local ok , iter = pcall ( lfs.dir , path )
	if not ok then return ferror ( "Error reading directory: " .. iter , 2 ) end
	for entry in iter do
		if hiddenfiles or entry:sub(1,1) ~= "." then
			local fullpath = path .. "/" .. entry
			local mode = lfs.attributes ( fullpath , "mode" )
			if mode == "file" then
				local a , err = checkfileaccepted ( fullpath )
				if a then
					items [ #items + 1 ] = createitem ( fullpath )
				else -- no return - keep going (even after a failure)
					ferror ( err , 5 )
				end
			elseif mode == "directory" and entry ~= "." and entry ~= ".." then
				if recurse > 0 then 
					tblappend ( items , getdir ( fullpath , recurse - 1 , hiddenfiles ) )
				end
			end
		end
	end
	
	return items
end

function addfolder ( path , pl , pos , recurse , hiddenfiles )
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
	
	--updatelog ( "Adding folder '" .. path .. "' to playlist #" .. pl , 3 )
	
	local items , err = getdir ( path , recurse , hiddenfiles )
	if not items then return items , err
	elseif #items == 0 then return true , nil , 0 end
	
	local comparefunc
	if config.sortcaseinsensitive then
		comparefunc = function ( a , b ) if a.source:lower ( ) < b.source:lower ( ) then return true end end -- Put in alphabetical order of path (case insensitive) 
	end
	tblsort ( items , comparefunc )
	
	local firstpos , err = core.item.additems ( pl , pos , items )
	if firstpos then
		return true , firstpos , #items
	else
		return false , err
	end
end
