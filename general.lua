--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local assert , error , getmetatable , pairs , rawget , setmetatable , tostring , type = assert , error , getmetatable , pairs , rawget , setmetatable , tostring , type
local tblconcat = table.concat
local strformat = string.format
local random , randomseed = math.random , math.randomseed
local ostime = os.time

package.path = "./libs/?.lua;./libs/?/init.lua;" .. package.path .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/lib/lua/5.1/?.lua;/usr/lib/lua/5.1/?/init.lua"
package.cpath = "./libs/?.so;" .. package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/lib/lua/5.1/loadall.so"

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "iconv"

-- Set math randomseed
randomseed ( ostime ( ) )

do
	local rawpairs = pairs
	function pairs ( t )
		local mt = rawget ( getmetatable ( t ) or { } , "__pairs" )
		if mt then
			return mt ( t )
		else
			return rawpairs ( t )
		end
	end
	_G.pairs = pairs
	
	local rawtype = type
	function type ( t )
		local mt = rawget ( getmetatable ( t ) or { } , "__type" )
		if mt then
			return mt ( t )
		else
			return rawtype ( t )
		end
	end
	_G.type = type
end

function _G.toboolean ( o , strmode )
	if strmode and o == "false" then return false end
	return not not o
end

-- Explodes a string on seperator
function string.explode ( str , seperator , plain , fromend )
	if type ( seperator ) ~= "string" or seperator == "" then return false , "Provide a valid seperator (a string of length >= 1)" end
	local t , nexti = { } , 1
	local pos = 1
	while true do
		local st , sp = str:find ( seperator , pos , plain )
		if not st then break end -- No more seperators found
		
		if pos ~= st then
			t [ nexti ] = str:sub ( pos , st - 1 ) -- Attach chars left of current divider
			nexti = nexti + 1
		end
		pos = sp + 1 -- Jump past current divider
	end
	t [ nexti ] = str:sub ( pos ) -- Attach chars right of last divider
	return t
end

-- Trims whitespace
function string.trim ( str )
	return str:gsub( "^%s*(.-)%s*$", "%1" )
end

-- Converts string in specified encoding to utf8
function string.utf8 ( str , encoding )
	if #str == 0 then return "" end
	if not encoding then encoding = "ISO-8859-1" end
	return iconv.new ( "UTF-8" ,  encoding ):iconv ( str )
end

-- Converts string in specified encoding to utf16
function string.utf16 ( str , encoding )
	if #str == 0 then return "" end
	if not encoding then encoding = "UTF-8" end
	return iconv.new ( "UTF-16" ,  encoding ):iconv ( str )
end

-- Converts string in specified encoding to ascii (iso-8859-1)
function string.ascii ( str , encoding )
	if #str == 0 then return "" end
	if not encoding then encoding = "UTF-8" end
	return iconv.new ( "ISO-8859-1" ,  encoding ):iconv ( str )
end

-- Escapes a string so its safe in a uri... (not / though)
function string.urlescape ( str )
	return str:gsub ( "([^/A-Za-z0-9_])" ,
		function ( c ) return ("%%%02x"):format ( c:byte ( ) ) end )
end

-- Append a tbl to another
 -- newtbl is the table that will have tbl appended to it
function table.append ( newtbl , tbl )
	newtbl = newtbl or { }
	local base = #newtbl
	for i=1 , #tbl do
		newtbl [ base + i ] = tbl [ i ]
	end
	return newtbl
end

-- Discards all values after the given index
 function table.sever ( t , index )
	for i = #t, index + 1, -1 do
		t[i] = nil
	end 
	return t
end

-- Randomise a table
function table.randomise ( tbl , n , newtable )
	n = n or #tbl
	
	local new
	if newtable then new = { }
	else new = tbl end
	
	for i = 1 , n do
		local j = random ( i , n )
		new [ i ] , tbl [ j ] = tbl [ j ] , tbl [ i ]
	end
	return new
end

-- Sort a table stabily
 -- a is table to sort
 -- returns sorted table.
function table.stablesort ( a , equalitycheck , newtable )
	equalitycheck = equalitycheck or function ( e1 , e2 ) return e1 < e2 end
	
	local n = #a
	
	local index = { }
	for i = 1 , n do index [ i ] = i end

	table.sort ( index , function ( i , j )
			local ai , aj = a [ i ] , a [ j ]
			if equalitycheck ( ai , aj ) then return true end
			if equalitycheck ( aj , ai ) then return false end
			return i < j
		end
	)

	for i = 1 , n do index [ i ] = a [ index [ i ] ] end
	
	if newtable then a = { } end
	
	for i = 1 , n do
		a [ i ] = index [ i ]
	end
	
	return a
end

-- Does a shallow copy of tbl, destination table is optional
 -- returns the copy.
function table.copy ( tbl , desttbl )
	local desttbl = desttbl or { }
	for k , v in pairs ( tbl ) do
		desttbl [ k ] = v
	end
	return desttbl
end

-- Copy tbl2's values into tbl1 where the matching tbl1 key (or index) doesn't exist
 -- If overwrite is a function, on a clash, it is called with the first table, the second table and the key corresponding to the clash
function table.inherit ( tbl1 , tbl2 , overwrite )
	if type ( tbl1 ) ~= "table" or type ( tbl2 ) ~= "table" then error ( "Bad arguments to table.inherit" ) end
	if tbl1 == tbl2 then return tbl1 end
	local t
	if overwrite or type ( overwrite ) ~= "function" then
		t = tbl1 
	else
		t = table.copy ( tbl1 ) 
	end
	for k , v in pairs ( tbl2 ) do
		if type ( t [ k ] ) == "table" and type ( v ) == "table" then
			t [ k ] = table.inherit ( t [ k ] , v , overwrite or true )
		elseif type ( overwrite ) == "function" and tbl1 [ k ] then
			t [ k ] = overwrite ( tbl1 , tbl2 , k )
		else 
			t [ k ] = v 
		end
	end
	return t
end

function package.see ( env )
	env = env or _G
	return function ( module ) 
		local t = type ( module )
		assert ( t == "table" , "bad argument #1 to package.see (table expected, got " .. t .. ")" )
		local meta = getmetatable ( module )
		if not meta then
			meta = { }
			setmetatable ( module , meta )
		end
		meta.__index = env
	end
end

function table.serialise ( t , prefix )
	prefix = prefix or ""
	local s = ""
	
	if t == nil then
		return "nil"
	elseif type ( t ) == "table" then
		local tbl = { }
		for k , v in pairs ( t ) do
			tbl [ #tbl + 1 ] = prefix .. '\t[' .. table.serialise ( k ) .. '] = ' .. table.serialise ( v , prefix .. "\t" )
		end
		return '{\n' .. tblconcat ( tbl , ";\n" ) .. "\n" .. prefix .. '}'
	elseif type ( t ) == "number" then
		return t
	elseif type ( t ) == "boolean" then
		return tostring ( t )
	--elseif type ( t ) == "string" then
	else -- All other formats (including string and userdata)
		return strformat ( '%q' , tostring ( t ) )
	end
end
