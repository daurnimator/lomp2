package.path = package.path .. ";./?/init.lua"

local assert , error , print = assert , error , print
local type , tostring , tonumber = type , tostring , tonumber
local ipairs , pairs = ipairs , pairs
local rawset = rawset
local getmetatable , setmetatable = getmetatable , setmetatable
local loadfile = loadfile


local setfenv , loadin = setfenv , loadin

local ioopen = io.open
local osclock , osexecute = os.clock , os.execute

local tblconcat = table.concat

local ceil , log , max , pi , sin = math.ceil , math.log , math.max , math.pi , math.sin

local registry = debug.getregistry ( )


local doc = require "codedoc".doc

local loadfilein
if loadin then
	loadfilein = function ( file , env )
		return loadin ( env , ioopen ( file ):read ( "*a" ) )
	end
else
	loadfilein = function ( file , env )
		assert ( type ( env ) == "table" , "invalid environment" )
		return setfenv ( loadfile ( file ) , env )
	end
end
doc {
	desc = [[loads ^file^ in given ^env^]] ;
	params = {
		{ "file" , "path to file" } ;
		{ "env" , "environment" } ;
	} ;
	returns = { { "chunk" , "function representing file" } } ;
} ( loadfilein )

local len
do
	--Test for native __len support:
	local x = setmetatable ( { } , { __len = function() return 5 end } )
	if #x == 5 then
		len = function ( o ) return #o end
	else
		len = function ( o )
			local mt = getmetatable(o)
			if mt then
				local mmt = mt.__len
				if mmt then return mmt(o) end
			end
			return #o
		end
	end
end

local deps = setmetatable ( { } , { __mode = "" } )
registry.deps = deps
local function add_dependancy ( ob , dep )
	local t = deps[dep]
	if not t then
		t = setmetatable ( { } , { __mode = "" } )
		deps[dep] = t
	end
	t[ob] = true
end

local function current_script_dir ( )
	return debug.getinfo ( 2 , S ).source:match ( [=[^@(.-)[^/\]*$]=] )
end


local function pretty ( t , prefix )
	prefix = prefix or ""

	if type ( t ) == "table" then
		local tbl , nexti = { "{" } , 2
		for k , v in pairs ( t ) do
			tbl [ nexti ] = prefix .. "\t[" .. pretty ( k ) .. "] = " .. pretty ( v , prefix .. "\t" )
			nexti = nexti + 1
		end
		tbl [ nexti ] = prefix .. "}"
		return tblconcat ( tbl , ";\n" )
	elseif t == nil  or type ( t ) == "number" or type ( t ) == "boolean" then
		return tostring ( t )
	else -- All other formats (string and userdata)
		return ( "%q" ):format ( tostring ( t ) )
	end
end
local pretty_print = function ( ... ) for i , v in ipairs ( { ... } ) do print ( pretty ( v ) ) end end

--- Table-y functions

-- Makes a reverse table for the given table
-- Second argument can be table to place reverse lookup into
local reverse_lookup = function ( in_t , out_t )
	out_t = out_t or { }
	for k,v in pairs ( in_t ) do
		out_t[v] = k
	end
	return out_t
end

-- Creates wrapper for an __index function that saves the result in the table
local save__index = function ( func )
	return function ( t , k  )
		local v = func ( t , k )
		rawset ( t , k ,  v )
		return v
	end
end


--- String related functions

-- Escapes a string so its safe in a uri... (not / though)
local byte_tbl = setmetatable ( { } , { __index = save__index ( function ( t , c ) return ("%%%02x"):format ( c:byte ( ) ) end ) } )
local urlescape = function ( str )
	return str:gsub ( "([^/A-Za-z0-9_])" , byte_tbl )
end

--- Math-sy functions
local nearestpow2 = function ( x )
	return 2^(ceil(log(0.1*x)/log(2)))
end

local generatesinusoid = function ( pitch , frequency )
	--Generate sinusoidal test signal
	local m = 2*pi/frequency*pitch
	return function ( i )
			return sin(m*(i))
		end
end


-- Sleeps for the specified amount of time;
--  if no argument given, sleeps for smallest amount of time possible (gives up timeslice)
local sleep
do
	local ok , ffi = pcall ( require , "ffi" )
	if jit and ok then
		if jit.os == "Windows" then
			ffi.cdef[[void Sleep(int);]]
			sleep = function ( x )
				x = max ( 0 , x or 0 ) -- Prevent overflows
				ffi.C.Sleep(x*1000)
			end
		else --Assume posix
			ffi.cdef[[void usleep(unsigned long usec);]]
			sleep = function ( x )
				x = max ( 0 , x or 1e-6 )
				ffi.C.usleep( x * 1e6 )
			end
		end
	else
		local ok , socket = pcall ( require , "socket" )
		if ok then
			sleep = socket.sleep
		elseif osexecute ( "sleep" ) == 0 then
			sleep = function ( x )
				if ( x or 0 ) > 0 then
					osexecute ( ("sleep %f"):format ( x ) )
				end
			end
		else -- Oh well, busy-wait it is
			sleep = function ( x )  -- seconds
				x = x or 0
				local t0 = osclock ( )
				while osclock ( ) - t0 <= x do end
			end
		end
	end
end

return {
	loadfilein  = loadfilein ;
	len = len ;

	reverse_lookup = reverse_lookup ;
	save__index = save__index ;
	add_dependancy = add_dependancy ;
	current_script_dir = current_script_dir ;
	pretty_print = pretty_print ;

	urlescape = urlescape ;

	nearestpow2 = nearestpow2 ;
	generatesinusoid = generatesinusoid ;

	sleep = sleep ;
}
