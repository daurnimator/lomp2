local source = ...

local alsa = require"alsa"
local dsp = require"dsp"

local ffi = require"ffi"
local asound = ffi.load ( "asound" )

local handle = alsa.init("default")
local options = {
	channels = 2 ;
	sample_rate = 44100 ;
	source = source ;
	format = alsa.formats[16] ;
	--samples =  ;
}
alsa.set_params ( handle )
alsa.write_loop ( handle , options , alsa.file_source , dsp{
		dsp.multiply(2^-15);
		dsp.balance(.5);
		dsp.attenuate(.2);
		--dsp.channel(0,dsp.delay(100000)); -- Delay left channel by 100000 samples
	})
