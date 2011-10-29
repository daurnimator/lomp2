local ffi = require"ffi"
local assert , error = assert , error
local ipairs = ipairs
local tonumber = tonumber
local setmetatable = setmetatable
local tblconcat , tblinsert = table.concat , table.insert
local ioopen , popen = io.open , io.popen
local max = math.max

-- FFI utils
local escapechars = [["\]]
local preprocessor = "gcc -E -P" --"cl /EP"
local include_flag = " -I "
local include_dirs = {}
local function ffi_process_headers ( headerfiles )
	local input
	if jit.os == "Windows" then
		input = { }
		for i , v in ipairs ( headerfiles ) do
			tblinsert ( input , [[echo #include "]] .. v ..'"'		)
		end
		input = "(" .. tblconcat ( input , "&" ) .. ")"
	elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
		input = { "echo '"}
		for i , v in ipairs ( headerfiles ) do
			tblinsert ( input , [[#include "]] .. v ..'"\n' )
		end
		tblinsert ( input , "'" )
		input = tblconcat ( input )
	else
		error ( "Unknown platform" )
	end

	local cmdline = {
		input , "|";
		preprocessor ;
	}
	for i , dir in ipairs ( include_dirs ) do
		tblinsert ( cmdline , [[-I"]] .. dir:gsub ( "[" .. escapechars .. "]" , [[\%1]] ) .. [["]] )
	end
	tblinsert ( cmdline , "-" ) -- Take input from stdin

	if jit.os == "Windows" then
		tblinsert( cmdline ,  [[2>nul]] )
	elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
		tblinsert( cmdline ,  [[&2>/dev/null]] )
	else
		error ( "Unknown platform" )
	end

	cmdline = tblconcat ( cmdline , " " )
    local progfd = assert ( popen ( cmdline ) )
	local s = progfd:read ( "*a" )
	assert ( progfd:close ( ) , "Could not process header files" )
	return s
end

local function ffi_process_defines ( headerfile , defines )
	defines = defines or { }
	local fd = ioopen ( headerfile ) -- Look in current dir first
	for i , dir in ipairs ( include_dirs ) do
		if fd then break end
		fd = ioopen ( dir .. headerfile )
	end
	assert ( fd , "Can't find header: " .. headerfile )

	--TODO: unifdef
	for line in fd:lines ( ) do
		local n ,v = line:match ( "#define%s+(%S+)%s+([^/]+)" )
		if n then
			v = defines [ v ] or tonumber ( v ) or v
			defines [ n ] = v
		end
	end
	return defines
end

local function ffi_defs ( defs_file , headers )
	local fd = ioopen ( defs_file )
	local s
	if fd then
		s = fd:read ( "*a" )
	else
		s = ffi_process_headers ( headers )
		fd = assert ( ioopen ( defs_file , "w" ) )
		assert ( fd:write ( s ) )
	end
	fd:close ( )
	ffi.cdef ( s )
end

local function ffi_clear_include_dir ( dir )
	include_dirs = { }
end

local function ffi_add_include_dir ( dir )
	tblinsert ( include_dirs , dir )
end


return {
	ffi_process_headers 	= ffi_process_headers ;
	ffi_process_defines 	= ffi_process_defines ;
	ffi_defs 				= ffi_defs ;

	ffi_clear_include_dir 	= ffi_clear_include_dir ;
	ffi_add_include_dir 	= ffi_add_include_dir ;
}
