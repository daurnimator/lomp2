local FILE = arg[1]

local format , rep = string.format , string.rep
local floor = math.floor

local general = require"general"
local sleep = general.sleep
local time = general.time

local play = require"play"()

local sources 			= require"sources"
local raw_fd 			= sources.raw_fd
local wav_fd 			= sources.wav_fd
local sine_source 		= sources.sinusoidal
local wavpack_source 	= sources.wavpack_file
local mad_file 			= sources.mad_file
local ffmpeg_source 	= sources.ffmpeg_file
local libsndfile_path 	= sources.libsndfile_path


local function pretty_time ( x )
	local sec = x % 60
	local min = floor ( x / 60 )
	return format ( "%02d:%05.2f" , min , sec )
end

io.stderr:setvbuf ( "no" )

play:set_new_song ( function ( play , item )
	local line = "Now Playing:    " ..
		pretty_time ( item.from / item.sample_rate ) ..
		"                       -                       " ..
		pretty_time ( item.to / item.sample_rate )

	io.stderr:write ( "\r" , line , rep ( " " , 80 - 1 - #line ) , "\n" )
end )

print("START")

--[[
play:push ( wavpack_source ( FILE ) )
play:push ( wavpack_source ( FILE ) )
--]]
--[[
local ff = ffmpeg_source ( FILE )
play:push ( ff )
--]]
--[[
local m = mad_file ( FILE )
m.from = m.to*9/10
play:push ( m )
play:push ( m )
--]]
--[[
local item = raw_fd ( io.open("samples.raw","rb") )
play:push ( item )
--]]
--[[
local w = wav_fd ( io.open ( FILE ,"rb" ) )
play:push ( w )
--]]
--[[
play:push ( libsndfile_path ( FILE ) )
--]]

local item = sine_source ( 800 )
item.format = "STEREO8"
item.to = 90000
play:push ( item )

local item = sine_source ( 1000 )
item.from = 30000
item.to = 40000
play:push ( item )

local item = sine_source ( 440 )
item.from = 30000
item.to = 70000
item.sample_rate = 48000
play:push ( item )

local item = sine_source ( 440 )
item.from = 20000
item.to = 60000
play:push ( item )

--play:foreach(print)

local i = 0
while true do
	local time_of_step = time ( )

	local wait = play:step ( )
	if not wait then break end

	local np = play:nowplaying ( )

	while time_of_step + wait > time ( ) do
		local pos = play:position ( )
		if not pos then break end

		local pre = format ( "%04d W=%.5f  |" , i , wait )
		local mid = pretty_time ( pos / np.sample_rate )
		local post = "|"

		local percent = pos/(np.to - np.from)
		local size = 80 - 1 - #pre - #mid - #post
		local sizepre = floor ( size*percent + 0.5 )
		local sizepost = size - sizepre

		local line = pre .. rep ( "=" , sizepre ) .. mid .. rep ( "=" , sizepost ) .. post
		io.stderr:write ( "\r" , line )

		sleep ( 0.03 )
	end

	i = i + 1
end


play = nil

collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
collectgarbage("step")
print("\nDONE")
