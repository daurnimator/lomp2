package.path = package.path .. [[;./sources/?/init.lua]]

local silent 	= require"sources.silent"
local sine 		= require"sources.sine"
local raw 		= require"sources.raw"
local wav 		= require"sources.wav"
local wavpack 	= require"sources.WavPack"
local mad 		= require"sources.MAD"
local ffmpeg 	= require"sources.FFmpeg"


return {
	silent 			= silent ;
	sinusoidal 		= sine ;
	raw_fd 			= raw ;
	wav_fd 			= wav ;
	wavpack_file 	= wavpack ;
	mad_file 		= mad ;
	ffmpeg_file 	= ffmpeg ;
}
