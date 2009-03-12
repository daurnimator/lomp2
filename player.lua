--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local libvlc = require "vlc086h"

require "core.triggers"

module ( "lomp.player" , package.see ( lomp ) )

extensions = {	"ogg" ,
				"flac" ,
				"mp3" ,
				"wav" ,
}

function play ( typ , source , offset )
	if typ == "file" then
		local a = instance:playlist_add ( source )
		instance:playlist_play ( a )
		return true
	else 
		print( "TYPE IS: " .. typ )
		return false , typ
	end
end

function changesong ( newtyp , newsource , newoffset )
	stop ( )
	play ( newtyp , newsource , newoffset )
end	
		
function pause ( )
	if instance:playlist_isplaying ( ) then
		instance:playlist_pause ( )
	end
end

function unpause ( )
	if not instance:playlist_isplaying ( ) then
		instance:playlist_pause ( )
	end
end

function stop ( )
	instance:playlist_stop ( )
	return true
end

function callonend ( )
	-- When file is finished playing, call this.
end

function getstate ( )
	--[[local r = rerr:read ( 3 )  -- Junk
	local r = rerr:read ( )
	rerr:read ( ) rerr:read ( 2 )-- Blank Junk
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( 76 )
	return '"' .. r .. '"'
	--]]
end

instance = libvlc.new ( )
