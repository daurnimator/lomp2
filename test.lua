local FILE = arg[1]

local general = require"general"
local sleep = general.sleep
local play = require"play"()

local sources 			= require"sources"
local raw_fd 			= sources.raw_fd
local wav_fd 			= sources.wav_fd
local sine_source 		= sources.sinusoidal
local wavpack_source 	= sources.wavpack_file
local mad_file 			= sources.mad_file
local ffmpeg_source 	= sources.ffmpeg_file


local function pretty_time ( x )
	local sec = x % 60
	local min = math.floor ( x / 60 )
	return string.format ( "%02d:%05.2f" , min , sec )
end

io.stderr:setvbuf ( "no" )

play:set_new_song ( function ( item )
	local line = "Now Playing: " ..
		pretty_time ( item.from / item.sample_rate ) ..
		" - " ..
		pretty_time ( item.to / item.sample_rate )

	io.stderr:write ( "\r" , line , string.rep ( " " , 80 - 1 - #line ) , "\n" )
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
play:push ( wav_fd ( io.open ( FILE ,"rb" ) ) )
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

local time = os.time()
--play.setvolume (1.414)

local i = 0
while true do
	local wait = play:step ( )
	if not wait then break end

	if wait >= 0 then
		local w = os.clock ( )
		repeat
			local np = play:nowplaying ( )
			local pos = play:position ( )
			local percent = (pos - np.from)/(np.to - np.from)

			if not ( pos >= np.from and pos <= np.to ) then
				error ( "Position out of range: " .. np.from .. "/" .. pos .. "/" .. np.to )
			end

			local pre = string.format ( "%04d W=%.5f  |" , i , wait )
			local mid = pretty_time ( pos / np.sample_rate )
			local post = "|"

			local size = 80 - 1 - #pre - #mid - #post

			local line = pre .. string.rep ( "=" , size*percent ) .. mid .. string.rep ( "=" , size*(1-percent) ) .. post
			io.stderr:write ( "\r" , line )

			sleep ( 0.03 )
		until os.clock ( ) > w + wait
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
