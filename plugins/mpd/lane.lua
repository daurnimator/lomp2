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

local commands = { }
local allcommands = { 	command_list_begin = true , command_list_ok_begin = true , 
				commands = true , notcommands = true ,
				disableoutput = false , enableoutput = false , kill = true
}

local function execute ( name , parameters )
	-- Executes a function, given a string
	-- Example of string: core.playback.play
	if type ( name ) ~= "string" then return false end
	if parameters and type ( parameters ) ~= "table" then return false end
	
	local timeout = nil
	
	linda:send ( timeout , "cmd" , { cmd = name , params = parameters } )
	
	local val , key = linda:receive ( timeout , "returnedcmd" )
	return unpack ( val )
end
local function makeackmsg ( errorid , position ,  current_command ,  message_text )
	--[[	ACK_ERROR_NOT_LIST = 1 
		ACK_ERROR_ARG = 2 
		ACK_ERROR_PASSWORD = 3 
		ACK_ERROR_PERMISSION = 4 
		ACK_ERROR_UNKNOWN = 5 
		ACK_ERROR_NO_EXIST = 50 
		ACK_ERROR_PLAYLIST_MAX = 51 
		ACK_ERROR_SYSTEM = 52 
		ACK_ERROR_PLAYLIST_LOAD = 53 
		ACK_ERROR_UPDATE_ALREADY = 54 
		ACK_ERROR_PLAYER_SYNC = 55 
		ACK_ERROR_EXIST = 56 
	--]]
	return "ACK [".. errorid .. "@".. position .. "] {" ..  ( current_command or "" ) .. "} " .. ( message_text or "" ) .. "\n"
end

local function doline ( line , skt )
		local i , j , cmd = string.find ( line , "([^ \t]+)" )
		if i then
			if commands [ cmd ] then
				return true , commands [ cmd ] ( line , skt )
			else
				return false , { 5 , nil , 'unknown command "' .. cmd .. '"' }
			end
		else
			print ( "FAILED CMD FIND" , line , i , j , cmd )
			return 
		end
end

local function mpdserver ( skt )
	copas.send ( skt , "OK MPD " .. mpdversion .. "\n")
	while true do
		local line , err = copas.receive( skt )
		if line then 
			print( line )
			local ok , r = doline ( line , skt )
			if ok then
			elseif ok == false then
				r = makeackmsg ( r [ 1 ] , 0 , r [ 2 ] , r [ 3 ] )
			else
			end
			print ( ok , r )
			local bytessent , err = copas.send ( skt , r )
			print ( bytessent , err )
		else
			if err == "closed" then
				-- "MPD Client Disconnected"
				return
			else
				return ferror ( "MPD Socket Error: " .. err , 3 , _G )
			end
		end
	end
end

commands.command_list_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	--local i , max = 0 , 100
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
		--[[i = i + 1
		if i >= max then 
			table.insert ( thingstodo , function return false , { 1 , max , nil , "command list too long" } )
			break 
		end--]]
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			r = r .. a
		elseif ok == false then
			r = r .. a
			return r
		else
		end
	end
	r = r .. "OK\n"
	return r
end

commands.command_list_ok_begin = function ( line , skt )
	local r = ""
	--Read all functions
	local thingstodo = { }
	--local i , max = 0 , 100
	while true do
		local line = copas.receive ( skt )
		if line == "command_list_end" then
			break
		else
			table.insert ( thingstodo , function ( ) return doline ( line , skt ) end )
		end
		--[[i = i + 1
		if i >= max then 
			table.insert ( thingstodo , function return false , { 1 , max , nil , "command list too long" } )
			break 
		end--]]
	end
	--Do all functions and concatenate
	for i , v in ipairs ( thingstodo ) do
		local ok , a = v ( )
		if ok then
			r = r .. a .. "OK\n"
		elseif ok == false then
			r = r .. a
			return r
		else
		end
	end
	return r
end

commands.commands = function ( line , skt )
	local r = ""
	for k in pairs ( commands ) do
		r = r .. "command: " .. k .. "\n"
	end
	r = r .. "OK\n"
	return r	
end

commands.notcommands = function ( line , skt )
	local r = ""
	
	for k in pairs ( allcommands ) do
		if not commands [ k ] then
			r = r .. "command: " .. k .. "\n"
		end
	end
	r = r .. "OK\n"
	return r	
end

commands.kill = function ( line , skt )
	local r = ""
	execute ( "core.quit" )
	r = r .. "OK\n"
	return r	
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

function lane ( address , port )
	initiate ( address ,  port )
	copas.loop ( )
end
