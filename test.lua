local FILE = arg[1]

local general = require"general"
local sleep = general.sleep
local play = require"play"()

local sources 			= require"sources"
local raw_fd 			= sources.raw_fd
local sine_source 		= sources.sinusoidal
local wavpack_source 	= sources.wavpack_file
local ffmpeg_source 	= sources.ffmpeg_file

print("START")
local wv = wavpack_source ( FILE )
wv.to = 44100
play.queue:push ( wv )
--play.queue:push ( ffmpeg_source ( FILE ) )

---[[
local item = raw_fd ( io.open("samples.raw","rb") )
--play.queue:push ( item )
--]]

local item = sine_source ( 800 )
item.format = "STEREO8"
item.to = 90000
play.queue:push ( item )

local item = sine_source ( 1000 )
item.from = 30000
item.to = 40000
play.queue:push ( item )

local item = sine_source ( 440 )
item.from = 30000
item.to = 70000
item.sample_rate = 48000
play.queue:push ( item )

local item = sine_source ( 440 )
item.from = 30000
item.to = 70000
play.queue:push ( item )

--play.queue:foreach(print)

local time = os.time()
--play.setvolume (1.414)
local i = 0
while true do -- for i=1,50000
	local wait = play.step()
	if wait > 0.05 then
		sleep(wait-0.05)
	end
	local np = play.nowplaying ( )
	io.write(string.format(
		"Loop #%04d  Wait: %0.3f  Format: %s  At: %d From: %d To: %d\n" ,
		i ,	wait ,
		np.format ,
		np:position ( ) ,
		np.from ,
		np.to
	))
	if i ==  50 then play.nowplaying():seek ( 149000 ) end
	if i == 60 then play.nowplaying():seek ( 149000 ) end
	if i == 100 then play.nowplaying():seek ( 3000000 ) end
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
