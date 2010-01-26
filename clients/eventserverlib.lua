--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

package.path = package.path .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/lib/lua/5.1/?.lua;/usr/lib/lua/5.1/?/init.lua;./libs/?.lua;./libs/?/init.lua;"
package.cpath = package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/lib/lua/5.1/loadall.so;./libs/?.so"

local tonumber , getmetatable , setmetatable , select , unpack = tonumber , getmetatable , setmetatable , select , unpack
local tblconcat = table.concat
local error = error

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

local socket = require "socket"
local Json = require "Json"

module ( "lompclient" )

-- Lower Level interface
local function send ( ob , opcode , ... )
	local client = getmetatable ( ob ).client
	if not client then error ( "Client not connected" ) end
	
	client:send ( tblconcat ( { opcode , ... } , " " ) )
	client:send ( "\n" )
	
	return
end

local function rawsend ( ob , str )
	local client = getmetatable ( ob ).client
	if not client then error ( "Client not connected" ) end

	client:send ( str )
	return
end

local function receive ( ob )
	local client = getmetatable ( ob ).client
	if not client then return false , "Client not connected" end
	
	local line , err = client:receive ( "*l" )
	if not line then
		if err == "timeout" then return nil
		else return false , err end
	end
	
	local s , e , statuscode = line:find ( "^(%-?%d+)%s*" )
	statuscode = tonumber ( statuscode )
	
	local var , length , alreadyread
	if statuscode >= 0 then
		s , e , length , alreadyread = line:find ( "(%d+)%s*(.*)" , e + 1 )
	elseif statuscode < 0 then
		s , e , var , length , alreadyread = line:find ( "(%S+)%s+(%d+)%s*(.*)" , e + 1 )
	else
		return false , "Invalid Server Response"
	end
	length = tonumber ( length )
	if not length or length == 0 then return statuscode , var , { } end
	local lefttoread = length - #alreadyread	
	
	local data = { ( alreadyread or "" ) }
	repeat
		local newdata = client:receive ( lefttoread ) or ""
		data [ #data + 1 ] = newdata
		lefttoread = lefttoread - #newdata
	until lefttoread == 0
	data = tblconcat ( data , "\n" )
	data = Json.Decode ( data )
	
	return statuscode , var , data
end


-- High level interface, do not use if you're using the low level interface
local callbacks = { }
local queue = { }
local qi = 0 -- Highest index reponded to.
local qn = 0 -- Highest taken index

local function varargtojson ( ... )
	local args = { ... }
	local n = select ( "#" , ... )
	for i = 1 , n do
		local a = args [ i ]
		if a == nil then args [ i ] = Json.Null
		elseif a == "false" then args [ i ] = false
		elseif a == "true" then args [ i ] = true
		elseif tonumber ( a ) then args [ i ] = tonumber ( a )
		end
	end
	return Json.Encode ( args )
end

local function CMD ( ob , cmd , callback , ... )
	ob:send ( "CMD" , cmd , varargtojson ( ... ) )
	
	qn = qn + 1
	queue [ qn ] = callback
	return qn
end

local function SUBSCRIBE ( ob , event , callback , cb2 )
	ob:send ( "SUBSCRIBE" , event )
	local a = callbacks [ event ]
	local i
	if not a then
		callbacks [ event ] = { cb2 }
		i = 1
	else
		i = #a + 1
		a [ i ] = cb2
	end
	qn = qn + 1
	queue [ qn ] = callback
	
	return qn , i
end

local function UNSUBSCRIBE ( ob , event , index , callback )
	ob:send ( "UNSUBSCRIBE" , event )
	callbacks [ event ] [ index ] = nil
	
	qn = qn + 1
	queue [ qn ] = callback
	return qn
end

local function step ( ob )
	local code , var , data = ob:receive ( )
	if not code then return code , var end -- Will return nil if had nothing to read, false if an error
	
	if code == -1 then -- Event
		local funcs = callbacks [ var ]
		if funcs then
			for i = 1 , #funcs do
				funcs [ i ] ( unpack ( data ) )
			end
		end
		return true
	elseif code >= 0 then
		qi = qi + 1
		local cb = queue [ qi ]
		if cb then
			cb ( unpack ( data ) )
			queue [ qi ] = nil
		end
		return qi
	end
end

codes = { 
	[ -1 ] = "EVENT" ;
	[ 0 ] = "SUCCESS" ;
	"BAD_FORMAT" ;
	"INVALID_PHRASE" ;
	"ERROR" ;
	"ALREADY_SUBSCRIBED" ;
} ;
		
function connect ( address , port )
	local client , err = socket.connect ( address , port )
	if not client then return false , err end
	client:settimeout ( 0.03 )
	
	client:send ( "LOMP 1\n" )

	local ob = setmetatable ( { } , { client = client , __index = { 
		receive = receive ;
		send = send ; rawsend = rawsend ;
		close = function ( ob ) local client = getmetatable ( ob ).client return client:close ( ) end ;
		settimeout = function ( ob , timeout ) local client = getmetatable ( ob ).client return client:settimeout ( timeout ) end ;
		CMD = CMD ; SUBSCRIBE = SUBSCRIBE ; UNSUBSCRIBE = UNSUBSCRIBE ;
		step = step ;
	} } )

	local code , str
	repeat 
		code , str = receive ( ob )
		if code == false then error ( str ) end
	until code ~= nil
	if code ~= 0 then error ( "Not a lomp server" ) end
	
	return ob
end

return _M
