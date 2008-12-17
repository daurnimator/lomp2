--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "socket"
require "copas"

local mpdversion = "0.13.0"

commands = { }

commands.command_list_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , line )
		end
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		r = r .. doline ( v , skt )
	end
	r = r .. "OK\n"
	return r
end

commands.command_list_ok_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , line )
		end
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		r = r .. doline ( v , skt ) .. "OK\n"
	end
	return r
end

commands.commands = function ( line , skt )
	local r = ""
	for k , v in pairs ( commands ) do
		r = r .. "command: " .. v .. "\n"
	end
	r = r .. "OK\n"
	return r	
end

commands.commands = function ( line , skt )
	local r = ""
	for k , v in pairs ( commands ) do
		r = r .. "command: " .. v .. "\n"
	end
	r = r .. "OK\n"
	return r	
end

function doline ( line , skt )
		local i , j , cmd = string.find ( line , "([^ \t]+)" )
		local r = ""
		if i then
			commands [ cmd ] ( line , skt )
			--print (cmd,j)
			--copas.send(skt, data .. "\r\n")
		end
		return r
end

local function mpdserver ( skt )
	print( "MPD Client connected" )
	copas.send ( skt , "OK MPD " .. mpdversion .. "\n")
	while true do
		local line = copas.receive( skt )
		if line then 
			print(line)
			local r = doline ( line , skt )
			
		end
	end
end

function initiate ( host , port )
	local srv, err
	srv , err = socket.bind ( host , port , 100 )
	if srv then 
		copas.addserver ( srv , mpdserver )
		return updatelog ( "MPD server started; bound to '" .. host .. "', port #" .. port , 4 , _G ) 
	else
		return ferror ( "MPD server could not be started: " .. err , 1 , _G )
	end
end
function step ( )
	copas.step ( )
end

function lane ( address , port )
	initiate ( address ,  port )
	while true do
		step ( )
	end
end
