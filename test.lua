local FILE = arg[1]

local general = require"general"
local sleep = general.sleep
local play = require"play"()

local sources 			= require"sources"
local raw_fd 			= sources.raw_fd
local sine_source 		= sources.sinusoidal
local wavpack_source 	= sources.wavpack_file
local mad_file 			= sources.mad_file
local ffmpeg_source 	= sources.ffmpeg_file

print("START")
--[[
local wv = wavpack_source ( FILE )
play.queue:push ( wv )
--]]
--[[
local ff = ffmpeg_source ( FILE )
play.queue:push ( ff )
--]]
--[[
local m = mad_file ( FILE )
m.from = m.to*9/10
play.queue:push ( m )
--]]
---[[
local item = raw_fd ( io.open("samples.raw","rb") )
play.queue:push ( item )
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
item.from = 20000
item.to = 60000
play.queue:push ( item )

--play.queue:foreach(print)

local time = os.time()
--play.setvolume (1.414)

local function pretty_time ( x )
	local sec = x % 60
	local min = math.floor ( x / 60 )
	return string.format ( "%02d:%2.2f" , min , sec )
end
io.stderr:setvbuf ( "no" )
local np

local i = 0
while true do
	local wait = play:step()
	if not wait then break end

	if wait >= 0 then
		local w = os.clock ( )
		repeat
			local nnp = play:nowplaying ( )
			if nnp ~= np then io.stderr:write ( "\n" ) end
			np = nnp

			local info1 = string.format ( "%04d W=%0.2f  %s|" , i , wait , pretty_time ( np.from / np.sample_rate ) )
			local pos = play:position ( )
			local info2 = pretty_time ( pos / np.sample_rate )
			local info3= "|" .. np.to --pretty_time ( np.to / np.sample_rate )

			local percent = (pos - np.from)/(np.to - np.from)
			local size = 80 - 1 - #info1 - #info2 - #info3
			local line = "\r" .. info1 .. string.rep ( "=" , size*percent ) .. info2 .. string.rep ( "=" , size*(1-percent) ) .. info3
			io.stderr:write ( line )
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
