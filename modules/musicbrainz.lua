--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pairs , require , type = ipairs , pairs , require , type
local tblconcat = table.concat

module ( "lomp.musicbrainz" , package.see ( lomp ) )

local prefix = "musicbrainz.org/ws"
local version = 1

local baseurl = "http://" .. prefix .. "/" .. version .. "/"

local http = require "socket.http"
local ltn12 = require "ltn12"
local urlescape = require "socket.url".escape

local lxp = require "lxp"

local function lookup ( ft , mbid , inc )
	local typ = ft.typ
 	local url = { baseurl , typ , "/" , mbid , "?type=xml&inc=tags" }
	for i , v in ipairs ( inc or { } ) do
		url [ i*2 + 4 ] = "+"
		url [ i*2 + 5 ] = v
	end
	
	local result = { }
	local stack = { result }
	local parser = lxp.new ( {
		StartElement = function ( parser , elementName , attributes )
			local t = { elementName = elementName }
			for k , v in ipairs ( attributes ) do
				t [ v ] = attributes [ v ]
			end
			stack [ #stack + 1 ] = t
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
	
	if c == 200 then
		return result [ 1 ] [ 1 ]
	else
		return false , c
	end
end

local function search ( ft , fields )
	local typ = ft.typ
	local url = { baseurl .. typ .. "/?type=xml" }
	for k , v in pairs ( fields ) do
		url [ #url + 1 ] = urlescape ( k ) .. "=" .. urlescape ( v )
	end
	
	local result = { }
	local stack = { result }
	local parser = lxp.new ( {
		StartElement = function ( parser , elementName , attributes )
			local t = { elementName = elementName }
			for k , v in ipairs ( attributes ) do
				t [ v ] = attributes [ v ]
			end
			stack [ #stack + 1 ] = t
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
	
	if c == 200 then
		return result [ 1 ] [ 1 ]
	else
		return false , c
	end
end

local function reg ( t )
	_M [ t.typ ] = t
end
reg { search = search , lookup = lookup , typ = "artist" }
reg { search = search , lookup = lookup , typ = "release-group" }
reg { search = search , lookup = lookup , typ = "release" }
reg { search = search , lookup = lookup , typ = "track" }
reg { search = search , lookup = lookup , typ = "label" }
reg { search = search , submision = nil , typ = "tag" } -- folksonomy

--print(table.serialise(lomp.musicbrainz.search( "track" , {artist="Daft Punk",title="Da Funk" } )))
--"162d8cc7-6e1c-41ba-b993-d5fb5bb974ae"