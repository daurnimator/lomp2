local source = ...

local alsa = require"alsa"
local dsp = require"dsp"

local ffi = require"ffi"
local asound = ffi.load ( "asound" )

local handle = alsa.init("default")
local audio = alsa.load_interleaved(source)
alsa.set_params ( handle , audio )
i=0
alsa.write_loop ( handle , audio , dsp{
		dsp.balance(.5) ;
		dsp.volume(.9) ;
		--dsp.channel(0,dsp.delay(100000)); -- Delay left channel by 100000 samples
--[[		function(...)
			i=i+1 
			if i==44100*10 then
				print("swapped")
				--audio.format=asound.SND_PCM_FORMAT_S16_BE ;
				audio.sampling_rate = 44100/2
				alsa.set_params(handle,audio)
			end
			return ...
		end;
]]
	})
