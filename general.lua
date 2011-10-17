local assert , loadfile , loadin , pairs , print , rawset , setfenv , setmetatable , tostring , type = assert , loadfile , loadin , pairs , print , rawset , setfenv , setmetatable , tostring , type
local ioopen = io.open
local table_concat = table.concat

local doc = require "codedoc".document

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
doc ( {
	desc = [[loads ^file^ in given ^env^]] ;
	params = {
		{ "file" , "path to file" } ;
		{ "env" , "environment" } ;
	} ;
	returns = { { "chunk" , "function representing file" } } ;
} , loadfilein )

local save__index = function ( func )
	return function ( t , k  )
		local v = func ( t , k )
		rawset ( t , k ,  v )
		return v
	end
end

-- Table to convert a string's locale. string.convert_locale [ from ] [ to ] [ "mystring" ]
local iconv_new = require "iconv".new
string.convert_locale = setmetatable ( { } , { __index = save__index ( function ( t , from )
		return setmetatable ( { } , { __index = save__index ( function ( tt , to )
				local convertor = assert ( iconv_new ( to , from ) )
				return setmetatable ( { } , { __index = save__index ( function ( ttt , str )
						return assert ( convertor:iconv ( str ) )
					end ) } )
			end ) } )
	end ) } )

-- Escapes a string so its safe in a uri... (not / though)
local byte_tbl = setmetatable ( { } , { __index = save__index ( function ( t , c ) return ("%%%02x"):format ( c:byte ( ) ) end ) } )
string.urlescape = function ( str )
	return str:gsub ( "([^/A-Za-z0-9_])" , byte_tbl )
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
		return table_concat ( tbl , ";\n" )
	elseif t == nil  or type ( t ) == "number" or type ( t ) == "boolean" then
		return tostring ( t )
	else -- All other formats (string and userdata)
		return ( "%q" ):format ( tostring ( t ) )
	end
end
pretty_print = function ( ... ) for i , v in ipairs ( { ... } ) do print ( pretty ( v ) ) end end

log = print
