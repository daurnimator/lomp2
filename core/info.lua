--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local pairs , require, type = pairs , require , type

module ( "lomp.core.info" , package.see ( lomp ) )

require "core.playlist"

function getplaylistinfo ( id )
	local pl , num = core.playlist.getpl ( id )
	if not pl then return ferror ( "getplaylistinfo called with invalid playlistt" ) end
	return { revision = pl.revision , items = pl.length , index = num , name = pl.name }
end

function getlistofplaylists ( )
	local t = { }
	for i , v in pairs ( vars.playlist ) do if type ( i ) == "number" then
		t [ #t + 1 ] = getplaylistinfo ( i )
	end end
	return t
end

getplaylist = core.playlist.fetch
