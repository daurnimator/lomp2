--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.triggers" , package.see ( lomp ) )

local callbacks = { songchanged = { } , songfinished = { } , }
-- songchanged ( newsource )

function registercallback ( callback , func , name )
	local pos = #callbacks [ callback ] + 1
	callbacks [ callback ] [ pos ] = func
	callbacks [ callback ] [ name ] = pos
	return pos
end
function triggercallback ( callback , ... )
	for i , v in ipairs ( callbacks [ callback ] ) do v ( ... ) end
end

registercallback ( "songchanged" , function ( )
		-- Print new song stats
		local t = vars.queue [ 0 ].details
		print( "--------------------Now playing file: ", t.filename )
		for k , v in pairs ( t ) do
			print ( k , v )
			if k == "tags" then
				print ( "==== Tags:" )
				for tag , val in pairs ( v ) do
					print ( "Tag:" , tag , " = " , val ) 
				end
			end
		end
		print ( "----------------------------------------------------------------" )
	end , "Print to screen" )
