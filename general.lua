package.path = package.path .. ";./modules/?/init.lua"
local require = require

local assert , error , print , pcall , xpcall = assert , error , print , pcall , xpcall
local type , tostring , tonumber = type , tostring , tonumber
local ipairs , pairs = ipairs , pairs
local rawset = rawset
local getmetatable , setmetatable = getmetatable , setmetatable
local setfenv , load , loadfile = setfenv , load , loadfile
local select = select

local ioopen = io.open
local ostime , osexecute = os.time , os.execute
local getinfo = debug.getinfo
local tblconcat = table.concat

local ceil , log , max , pi , sin = math.ceil , math.log , math.max , math.pi , math.sin

-- Add some functions differences between 5.1 and 5.2
local pack = table.pack or function ( ... ) return { n = select("#",...) , ... } end
local unpack = unpack or table.unpack

-- For checking if we're in luajit
local jit = jit
local gotffi , ffi = pcall ( require , "ffi" )

local gotsocket , socket = pcall ( require , "socket" )


-- Let xpcall take arguments
do
	-- Test for native support
	local ok , result = xpcall ( function ( ... ) return ... end , function ( ) end, "a" )
	if result ~= "a" then
		local old_xpcall = xpcall

		xpcall = function ( func , handler , ... )
			local args = pack ( ... )
			return old_xpcall ( function ( ) return func ( unpack ( args , 1 , args.n ) ) end , handler )
		end
	end
end

-- Loads the given file in the given environment. mode is as load is in 5.2
local loadfilein
if not setfenv then
	loadfilein = function ( file , env , mode )
		local fd = ioopen ( file , "r" )
		local source = assert ( fd:read ( "*a" ) )
		return load ( source , file , mode , env )
	end
else
	loadfilein = function ( file , env , mode )
		local fd = ioopen ( file , "r" )
		local source = assert ( fd:read ( "*a" ) )
		local isbinary = source:byte ( 1 , 1 ) == 27

		if isbinary and not mode:match ( "b" ) then
			error ( "Loading binary code not allowed" )
		elseif not isbinary and not mode:match ( "t") then
			error ( "Loading text source not allowed" )
		end
		return setfenv ( loadfile ( file ) , env )
	end
end

local len
do
	--Test for native __len support:
	local x = setmetatable ( { } , { __len = function() return 5 end } )
	if #x == 5 then
		len = function ( o ) return #o end
	else
		len = function ( o )
			local mt = getmetatable ( o )
			if mt then
				local mmt = mt.__len
				if mmt then return mmt(o) end
			end
			return #o
		end
	end
end

local function current_script_dir ( )
	local dir = getinfo ( 2 , "S" ).source:match ( [=[^@(.-)[^/\]*$]=] )
	if dir == "" then dir = "." end
	dir = dir .. "/"
	return dir
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

-- Gets the current time in as accurate way as possible
local time
do
	if jit and gotffi then
		local ffi_util = require"ffi_util"

		if jit.os == "Windows" then
			ffi.cdef [[
				typedef unsigned long DWORD, *PDWORD, *LPDWORD;
				typedef struct _FILETIME {
				  DWORD dwLowDateTime;
				  DWORD dwHighDateTime;
				} FILETIME, *PFILETIME;

				void GetSystemTimeAsFileTime ( FILETIME* );
			]]
			local ft = ffi.new ( "FILETIME[1]" )
			time = function ( ) -- As found in luasocket's timeout.c
				ffi.C.GetSystemTimeAsFileTime ( ft )
				local t = tonumber ( ft[0].dwLowDateTime ) / 1e7 + tonumber ( ft[0].dwHighDateTime ) * ( 2^32 / 1e7 )
				-- Convert to Unix Epoch time (time since January 1, 1970 (UTC))
				t = t - 11644473600
				return t
			end
		else -- Assume posix
			ffi.cdef ( ffi_util.ffi_process_headers { "<sys/time.h>" } )
			ffi.cdef [[int gettimeofday ( struct timeval * , void * );]]
			local tp = ffi.new ( "struct timeval[1]" )
			time = function ( )
				ffi.C.gettimeofday ( tp , nil )
				return tonumber ( tp[0].tv_sec ) + tonumber ( tp[0].tv_usec ) / 1e6
			end
		end
	elseif gotsocket then
		time = socket.gettime
	else
		time = ostime
	end
end

-- Sleeps for the specified amount of time;
--  if no argument given, sleeps for smallest amount of time possible (gives up timeslice)
local sleep
do
	if jit and gotffi then
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
		if gotsocket then
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
				local t0 = time ( )
				while time ( ) - t0 <= x do end
			end
		end
	end
end


return {
	pack = pack ;
	unpack = unpack ;
	xpcall = xpcall ;
	loadfilein  = loadfilein ;
	len = len ;

	reverse_lookup = reverse_lookup ;
	save__index = save__index ;
	current_script_dir = current_script_dir ;
	pretty_print = pretty_print ;

	urlescape = urlescape ;

	nearestpow2 = nearestpow2 ;
	generatesinusoid = generatesinusoid ;

	time = time ;
	sleep = sleep ;
}
