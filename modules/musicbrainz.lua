--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local require = require
local tblconcat = table.concat
local print = print
module ( "lomp.musicbrainz" , package.see ( lomp ) )

local http = require "socket.http"
local ltn12 = require "ltn12"
local urlescape = require "socket.url".escape

local lxp = require "lxp"

function lookuptrack ( mbid , inc )
	local url = { "http://musicbrainz.org/ws/1/track/" , mbid , "?type=xml&inc=tags" }
	for i , v in ipairs ( inc or { } ) do
		url [ i*2 + 2 ] = "+"
		url [ i*2 + 3 ] = v
	end
	
	local stack = { { } }
	local parser = lxp.new ( {
		StartElement = function ( parser , elementName , attributes )
			stack [ #stack + 1 ] = { tag = elementName , attributes = attributes }
		end ;
		EndElement = function ( parser , elementName )
			local top = #stack
			local parent = stack [ top - 1 ]
			parent [ #parent + 1 ] = stack [ top ]
			stack [ top ] = nil
		end ;
		CharacterData = function ( parser , str )
			local parent = stack [ #stack ]
			if type ( parent [ #parent ] ) == "str" then
				parent [ #parent ] = parent [ #parent ] .. str
			else	
				parent [ #parent + 1 ] = str
			end
		end ;
	} )
	
	local b, c, h = http.request { 
		url = tblconcat ( url ) ;
		sink = function ( chunk , err )
			if chunk then
				parser:parse ( chunk )
			end
			return 1
		end ;
	}
	
	return unpack ( stack )
end

function searchtrack ( fields )
	local url = { "http://musicbrainz.org/ws/1/track/?type=xml" }
	for k , v in pairs ( fields ) do
		url [ #url + 1 ] = urlescape ( k ) .. "=" .. urlescape ( v )
	end
	
	local stack = { { } }
	local parser = lxp.new ( {
		StartElement = function ( parser , elementName , attributes )
			stack [ #stack + 1 ] = { tag = elementName , attributes = attributes }
		end ;
		EndElement = function ( parser , elementName )
			local top = #stack
			local parent = stack [ top - 1 ]
			parent [ #parent + 1 ] = stack [ top ]
			stack [ top ] = nil
		end ;
		CharacterData = function ( parser , str )
			local parent = stack [ #stack ]
			if type ( parent [ #parent ] ) == "str" then
				parent [ #parent ] = parent [ #parent ] .. str
			else	
				parent [ #parent + 1 ] = str
			end
		end ;
	} )
	
	local b, c, h = http.request { 
		url = tblconcat ( url , "&" ) ;
		sink = function ( chunk , err )
			if chunk then 
				parser:parse ( chunk )
			end
			return 1
		end ;
	}
	
	return unpack ( stack )
end
	
--print(table.serialise(lomp.musicbrainz.searchtrack({artist="Daft Punk",title="Da Funk" } )))
--"162d8cc7-6e1c-41ba-b993-d5fb5bb974ae"