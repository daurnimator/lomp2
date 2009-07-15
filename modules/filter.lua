--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.filter" , package.see ( lomp ) )

require "core.playlist"

function reduce ( tbl , func )
	local results , nexti = { } , 1
	for i , v in ipairs ( tbl ) do
		if func ( v , i ) then 
			results [ nexti ] = v
			nexti = nexti + 1
		end
	end
	return results
end

local playlistfilters = 0
local function makeplaylist ( filterresults )
	filterresults.length = #filterresults
	playlistfilters = playlistfilters + 1
	local playlistnum = core.playlist.new ( "Filter Results #" .. playlistfilters )
	vars.playlist [ playlistnum ].revisions [ 1 ] = filterresults
	return playlistnum
end

local inmap = {
	["playlist"] = function ( t ) return core.playlist.fetch ( t.index ) end ;
	["cache"] = function ( t ) return metadata.cache end ;
}
local outmap = {
	["playlist"] = makeplaylist ;
	["table"] = function ( t ) return t end ;
}

function filter ( int , out , func )
	if not func then return false end
	
	local infunc = inmap [ int.type ]
	if not infunc then return false end
	local intbl = infunc ( int )
	if not intbl then return false end
	
	local outfunc = outmap [ out.type ]
	if not outfunc then return false end
	
	return outfunc ( reduce ( intbl , func ) )
end

common = {
	tag = function ( int , out , field , pattern ) 
		return filter ( int , out , function ( item )
			local tagfield = item.tags [ field ]
			if not tagfield then return false end		
			
			for i , v in ipairs ( tagfield ) do
				if v:find ( pattern ) then return true end
			end
			
			return false
		end )
	end ;
}
