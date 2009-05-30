--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.info" , package.see ( lomp ) )

function getlistofplaylists ( )
	local t = { }
	print(vars.pl)
	for i = 1 , #vars.pl do
		t [ i ] = { name = vars.pl [ i ].name , revision = vars.pl [ i ].revision , index = i }
	end
	return t
end

function getplaylist ( pl )
	pl = core.playlist.okpl ( pl )
	return vars.pl [ pl ]
end
