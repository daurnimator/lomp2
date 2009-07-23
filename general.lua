--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

package.path = package.path .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/lib/lua/5.1/?.lua;/usr/lib/lua/5.1/?/init.lua;./libs/?.lua;./libs/?/init.lua;"
package.cpath = package.cpath .. ";/usr/lib/lua/5.1/?.so;/usr/lib/lua/5.1/loadall.so;./libs/?.so"

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "iconv"

-- Set math randomseed
math.randomseed ( os.time ( ) )

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
	
	local rawtype = type
	function type ( t )
		local mt = rawget ( getmetatable ( t ) or { } , "__type" )
		if mt then
			return mt ( t )
		else
			return rawtype ( t )
		end
	end
end

function toboolean ( o )
	return not not o
end

-- Explodes a string on seperator
function string.explode ( str , seperator , plain )
	if seperator == "" then return false end
	local t , nexti = { } , 1
	local pos = 1
	for st , sp in function ( ) return string.find ( str , seperator , pos , plain ) end do
		if pos ~= st then
			t [ nexti ] = string.sub ( str , pos , st - 1 ) -- Attach chars left of current divider
			nexti = nexti + 1
		end
		pos = sp + 1 -- Jump past current divider
	end
	t [ nexti ] = string.sub ( str , pos ) -- Attach chars right of last divider
	return t
end

-- Trims whitespace
function string.trim ( str )
	return str:gsub( "^%s*(.-)%s*$", "%1" )
end

-- Converts string in specified encoding to utf8
function utf8 ( str , encoding )
	if not encoding then encoding = "ISO-8859-1" end
	return iconv.new ( "UTF-8" ,  encoding ):iconv ( str )
end
-- Converts string in specified encoding to utf16
function utf16 ( str , encoding )
	if not encoding then encoding = "UTF-8" end
	return iconv.new ( "UTF-16" ,  encoding ):iconv ( str )
end
-- Converts string in specified encoding to ascii (iso-8859-1)
function ascii ( str , encoding )
	if not encoding then encoding = "UTF-8" end
	return iconv.new ( "ISO-8859-1" ,  encoding ):iconv ( str )
end

-- Append a tbl to another
 -- newtbl is the table that will have tbl appended to it
function table.append ( newtbl , tbl )
	for i , v in ipairs ( tbl ) do
		newtbl[#newtbl+1] = v
	end
end

-- Discards all values after the given index
 function table.sever ( t , index )
	for i = #t, index + 1, -1 do
		t[i] = nil
	end 
	return t
end

-- Filter a function throught it: it will discard the first "skip" number of arguments
 -- Sort of like select
function packn ( skip , _ , ... ) 
	if skip == 0 then
		return { _ , ... }
	else return packn ( skip - 1 , ... ) 
	end
end

-- Randomise a table
function table.randomise ( tbl , n , newtable )
	n = n or #tbl
	
	local new
	if newtable then new = { }
	else new = tbl end
	
	for i = 1 , n do
		local j = math.random ( i , n )
		new [ i ] , tbl [ j ] = tbl [ j ] , tbl [ i ]
	end
	return new
end

-- Sort a table stabily
 -- a is table to sort
 -- returns sorted table.
function table.stablesort ( a , equalitycheck , newtable )
	equalitycheck = equalitycheck or function ( e1 , e2 ) if e1 < e2 then return true else return false end end
	func = func or function ( ) end
	
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
end

-- Returns a shallow copy of tbl
function table.copy ( tbl )
	local t = { }
	for k , v in pairs ( tbl ) do
		t [ k ] = v
	end
	return t
end

-- Returns a non-deep copy of numerical indexed values of tbl 
function table.indexedcopy ( tbl )
	local t = { }
	for i , v in ipairs ( tbl ) do
		t [ i ] = v
	end
	return t
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
		return '{\n' .. table.concat ( tbl , ";\n" ) .. "\n" .. prefix .. '}'
	elseif type ( t ) == "number" then
		return t
	elseif type ( t ) == "boolean" then
		return tostring ( t )
	--elseif type ( t ) == "string" then
	else -- All other formats (including string and userdata)
		return string.format ( '%q' , tostring ( t ) )
	end
end
