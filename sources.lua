package.path = package.path .. [[;./sources/?/init.lua]]

local silent 	= require"sources.silent"
local sine 		= require"sources.sine"
local raw 		= require"sources.raw"
local wavpack 	= require"sources.wavpack"
local mad 		= require"sources.mad"
local ffmpeg 	= require"sources.ffmpeg"


return {
	silent 			= silent ;
	sinusoidal 		= sine ;
	raw_fd 			= raw ;
	wavpack_file 	= wavpack ;
	mad_file 		= mad ;
	ffmpeg_file 	= ffmpeg ;
}
