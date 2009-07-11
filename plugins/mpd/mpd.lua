--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dir = dir -- Grab vars needed
local config , updatelog , ferror = config , updatelog , ferror

-- MPD Plugin
 -- Lets you use any mpd client to control lomp!

module ( "mpd" , package.see ( lomp ) )

_NAME = "MPD Compatability layer for lomp"
_VERSION = 0.1

loadfile ( dir .. "config" ) ( ) -- Load config

require "lanes"
local func = lanes.gen ( "base table string package os math io" , { ["globals"] = { config = config , updatelog = updatelog , ferror = ferror , thread = newlinda ( ) } } , loadfile ( dir .. "lane.lua" ) )
local lane = func ( address , port )

return _NAME , _VERSION
