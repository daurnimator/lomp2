--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.triggers" , package.see ( lomp ) )

local callbacks = { 
	songplaying = { } , -- songplaying ( typ , source ) -- Triggered when song is played
	songabouttofinsh = { } , -- songabouttofinish ( )
	songfinished = { } , -- songfinished ( typ , source )
	songstopped = { } , -- songstopped ( typ , source , stopoffset )
}

function registercallback ( callback , func , name )
	local pos = #callbacks [ callback ] + 1
	callbacks [ callback ] [ pos ] = func
	callbacks [ callback ] [ name ] = pos
	return pos
end
function deregistercallback ( callback , name )
	table.remove ( callbacks [ callback ] , callbacks [ callback ] [ name ] )
	callbacks [ callback ] [ name ] = nil
end
function triggercallback ( callback , ... )
	for i , v in ipairs ( callbacks [ callback ] ) do v ( ... ) end
end

registercallback ( "songplaying" , function ( )
		vars.queue [ 0 ].played = true -- Better way to figure this out?
	end , "Set Played" )
