--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dir = dir -- Grab vars needed
local updatelog , ferror = updatelog , ferror
local newlinda = newlinda

-- MPD Plugin
 -- Lets you use any mpd client to control lomp!

module ( "mpd" , package.seeall )

_NAME = "MPD Compatability layer for lomp"
_VERSION = 0.1

loadfile ( dir .. "config" ) ( ) -- Load config

if type ( address ) ~= "string" then address = "*" end
if type ( port ) ~= "number" or port > 65535 or port <= 0 then port = 6600 end

func = lanes.gen ( "base,package,math,table,string,io,os" , { globals = { linda = newlinda ( ) , updatelog = updatelog , ferror = ferror , config = config } } , function ( ... ) package.path = package.path .. ";./libs/?.lua;./libs/?/init.lua" loadfile ( dir .. "lane.lua" ) ( ) lane ( ... ) end )
mpdserverlane = func ( address , port )

--print(mpdserverlane:join())

return _NAME , _VERSION
