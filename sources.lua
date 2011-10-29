package.path = package.path .. [[;./sources/?/init.lua]]

local silent 	= require"sources.silent"
local sine 		= require"sources.sine"
local raw 		= require"sources.raw"
local ffmpeg 	= require"sources.ffmpeg"

return {
	silent 		= silent ;
	sinusoidal 	= sine ;
	raw_fd 		= raw ;
	ffmpeg_file = ffmpeg ;
}
