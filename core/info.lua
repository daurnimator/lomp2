--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.info" , package.see ( lomp ) )

function getplaylistinfo ( num )
	local pl = core.playlist.getnum ( num )
	if not pl then return false end
	return { revision = pl.revision , items = pl.length , index = num , name = pl.name }
end

function getlistofplaylists ( )
	local t = { }
	for i , v in pairs ( vars.playlist ) do if type ( i ) == "number" then
		t [ #t + 1 ] = getplaylistinfo ( i )
	end end
	return t
end

function getplaylist ( pl , revision , backto )
	return core.playlist.fetch ( pl , revision , backto )
end

function gethardqueue ( revision , backto )
	return core.playlist.fetch ( -2 , revision , backto )
end

--[[local lookup = {
	loop = function ( ) return vars.loop end ;
	["repeat"] = function ( ) return vars.rpt end ;
	softqueuepl = function ( ) return vars.softqueuepl end ;
	playlist = function ( ) return setmetatable ( { } , { __index = function ( t , k ) return getplaylist ( k ) end } ) end ;
	playlistrev = function ( ) return setmetatable ( { } , { __index = function ( t , k ) return setmetatable ( { } , { __index = function ( t , j ) return getplaylist ( k , j , j ) end } ) end } ) end ; -- playlistrev [ pl ] [ revision ]
	playlistdiff = function ( ) return setmetatable ( { } , { __index = function ( t , k ) return setmetatable ( { } , { __index = function ( t , j ) return setmetatable ( { } , { __index = function ( t , l ) return getplaylist ( k , l , j ) end } ) end } ) end } ) end ; -- playlistdiff [ pl ] [ early ] [ later ]
}

setmetatable ( core.info , { __index = function ( t , k )
	local f = lookup [ k ]
	if f then return f ( ) end
end } )--]]
