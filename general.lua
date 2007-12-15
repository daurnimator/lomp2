-- Set math randomseed
math.randomseed ( os.time ( ) )

-- Make _ automatically discard it's assignments.
setmetatable(_G, { __newindex = function(this,key,value) if key == '_' then return end return rawset(this,key,value) end })

-- Finds first value in tbl that matches pattern "key"
function table.valuetoindex ( tbl , value , key )
	for i,v in ipairs ( tbl ) do
		if string.find( v[value] , key ) then 
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

-- Filter a function throught it: it will discard the first "skip" arguments
 -- Sort of like select
function packn( skip , _ , ... ) 
	if skip == 0 then
		return { _ , ... }
	else return packn ( skip - 1 , ... ) 
	end
end

-- Randomize a table
function table.randomize ( tbl , n , count )
	n = n or #tbl
	for i = 1, count or n do
		local j = math.random(i, n)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return true , tbl
end
