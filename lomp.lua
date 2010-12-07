require "general"
local doc = require "codedoc".document

local loop = require "loop"

-- Load config
config = { }
local config_env = setmetatable ( {} , { __index = function ( t , k ) return function ( tbl ) config [ k ] = tbl end end } )
loadfilein ( "config.lua" , config_env ) ( )

-- Load modules
for k , v in pairs ( config ) do
	require ( k )
end

-- Start main loop.
loop.loop:loop ( )

print("Exiting")
