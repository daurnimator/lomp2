--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- Set math randomseed
math.randomseed ( os.time ( ) )

-- Explodes a string on seperator
function string.explode ( str , seperator )
	if seperator == "" then return false end
	local t = { }
	local pos = 1
	for st , sp in function ( ) return string.find ( str , seperator , pos , true ) end do
		if pos ~= st then
			t [ #t + 1 ] = string.sub ( str , pos , st - 1 ) -- Attach chars left of current divider
		end
		pos = sp + 1 -- Jump past current divider
	end
	t [ #t + 1 ] = string.sub ( str , pos ) -- Attach chars right of last divider
	return t
end


-- Finds first value in tbl that matches pattern "key"
function table.valuetoindex ( tbl , value , key )
	for i,v in ipairs ( tbl ) do
		if string.find( v[value] , '^' .. key .. '$' ) then 
			return i
		end
	end
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

-- Randomize a table
function table.randomize ( tbl , n , count )
	n = n or #tbl
	for i = 1 , count or n do
		local j = math.random ( i , n )
		tbl [ i ], tbl [ j ] = tbl [ j ] , tbl [ i ]
	end
	return true , tbl
end

-- Sort a table stabily
 -- a is table to sort
 -- func is a function to run on each element after it's sorted.
function table.stablesort ( a , equalitycheck , func )
	equalitycheck = equalitycheck or function ( e1 , e2 ) if e1 < e2 then return true else return false end end
	func = func or function ( ) end
	
	local n = #a
	local index = { }
	for i = 1 , n do index [ i ] = i end

	local function stable_lt ( i , j )
		local ai , aj = a [ i ], a [ j ]
		if equalitycheck ( ai , aj ) then return true end
		if equalitycheck ( aj , ai ) then return false end
		return i < j
	end
	table.sort ( index , stable_lt )

	for i = 1 , n do index [ i ] = a [ index [ i ] ] end
	for i = 1 , n do 
		a [ i ] = index [ i ] 
		func ( a [ i ] )
	end
end

-- Returns a copy of tbl
function table.copy ( tbl )
	local t = { }
	for k , v in pairs ( tbl ) do
		t [ k ] = v
	end
	return t
end

-- Copy tbl2's values into tbl1 where the matching tbl1 key (or index) doesn't exist
function table.inherit ( tbl1 , tbl2 , overwrite )
	if tbl1 == tbl2 then return tbl1 end
	local t
	if overwrite then t = tbl1 else t = table.copy ( tbl1 ) end
	for k , v in pairs ( tbl2 ) do
		if type ( t [ k ] ) == "table" and type ( v ) == "table" then
				t [ k ] = table.inherit ( t [ k ] , v , true )
		else t [ k ] = v 
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
	for k , v in pairs ( t ) do
		if type ( k ) == "number" then 
			k = '[' .. k .. ']'
		else -- Its a string
			k = '[' .. string.format ( '%q' , k ) .. ']'
		end
		
		if type ( v ) == "table" then
			s = s .. prefix .. k .. '= {\n'
			s = s .. table.serialise ( v , prefix .. "\t" )
			s = s .. prefix .. '};\n'
		elseif type ( v ) == "string" then
			s = s .. prefix .. k .. '= ' .. string.format ( '%q' , v ) .. ';\n'
		elseif type ( v ) == "number" then
			s = s .. prefix .. k .. '= ' .. v .. ';\n'
		elseif type ( v ) == "boolean" then
			s = s .. prefix .. k .. '= ' .. tostring ( v ) .. ';\n'
		end
	end
	return s
end
