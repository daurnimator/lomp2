local ffi = require "ffi"
ffi.cdef[[
	unsigned int sleep(unsigned int);
	int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]
local constants = assert(loadfile("errnos.lua"))()
ffi.cdef(assert(io.open("alsa.h")):read("*a"))
local asound = ffi.load ( "asound" )

local function new_buffer ( len )
	local buffer = ffi.gc ( ffi.C.malloc ( len) , ffi.C.free )
	return buffer
end

--[[local function process_format ( format )
	local bits_in_sample = asound.snd_pcm_format_physical_width(format)
	local phys_bps = asound.snd_pcm_format_physical_width(format) / 8
	local big_endian = asound.snd_pcm_format_big_endian(format) == 1
	local to_unsigned = asound.snd_pcm_format_unsigned(format) == 1
end]]

local function load_interleaved ( path , channels , rate )
	local data = io.open(path):read("*a")
	channels = channels or 2

	local format = asound.SND_PCM_FORMAT_S16
	local samples = new_buffer ( #data )
	ffi.copy(samples,data,#data)

	local bits_in_sample = asound.snd_pcm_format_physical_width(format)
	local numsamples = #data/(bits_in_sample/8)

	return {
		channels = channels ;
		sampling_rate = rate or 44100 ;
		format = format ;
		buffer = samples ;
		samples = numsamples ;
	}
end

local function aa ( err )
	if err < 0 then
		error(ffi.string(asound.snd_strerror(err)),2)
	end
	return err
end

local function init ( name )
	local handle = ffi.new("snd_pcm_t*[1]")
	local stream = asound.SND_PCM_STREAM_PLAYBACK
	local mode = 0
	aa( asound.snd_pcm_open ( handle , name , stream , mode ))

	return ffi.gc ( handle[0] , asound.snd_pcm_close )
end

local function set_params ( handle , options )
	local resample = 1
	local format = asound.SND_PCM_FORMAT_FLOAT
	local access = asound.SND_PCM_ACCESS_RW_INTERLEAVED 
	local buffer_time = .5*10^6 -- in us
	local period_time = .1*10^6 -- in us
	
	local rate = options.sampling_rate

	--Hardware Params
	local hw_params = ffi.new("snd_pcm_hw_params_t*[1]")
	aa( asound.snd_pcm_hw_params_malloc( hw_params ))
	hw_params = ffi.gc ( hw_params[0] , asound.snd_pcm_hw_params_free )

	aa( asound.snd_pcm_hw_params_any		 ( handle , hw_params ))
	aa( asound.snd_pcm_hw_params_set_rate_resample	 ( handle , hw_params , resample ))
	aa( asound.snd_pcm_hw_params_set_access		 ( handle , hw_params , access ))
	aa( asound.snd_pcm_hw_params_set_format		 ( handle , hw_params , format ))
	aa( asound.snd_pcm_hw_params_set_channels	 ( handle , hw_params , options.channels ))
	
	local rrate = ffi.new( "unsigned int[1]" , rate)
        aa( asound.snd_pcm_hw_params_set_rate_near 	 ( handle , hw_params , rrate , nil ))
	if rrate[0] ~= rate then
		error( "Rate doesn't match (requested " .. rate .. ", got " .. rrate[0] )
	end
	
	local dir = ffi.new ( "int[1]" )
	local size = ffi.new ( "snd_pcm_uframes_t[1]" )

	local bbuffer_time = ffi.new ( "unsigned int[1]" , buffer_time )
        aa( asound.snd_pcm_hw_params_set_buffer_time_near( handle , hw_params , bbuffer_time, dir))
        aa( asound.snd_pcm_hw_params_get_buffer_size	 ( hw_params , size))
	local buffer_size = size[0]

	local pperiod_time = ffi.new ( "unsigned int[1]" , period_time )
        aa( asound.snd_pcm_hw_params_set_period_time_near( handle , hw_params , pperiod_time, dir))
        aa( asound.snd_pcm_hw_params_get_period_size	 ( hw_params , size , dir ))
	local period_size = size[0]

	aa( asound.snd_pcm_hw_params ( handle , hw_params ))

	--Software Params
	local sw_params = ffi.new("snd_pcm_sw_params_t*[1]")
	aa( asound.snd_pcm_sw_params_malloc( sw_params ))
	sw_params = ffi.gc ( sw_params[0] , asound.snd_pcm_sw_params_free )

	aa( asound.snd_pcm_sw_params_current 		( handle , sw_params ))
	aa( asound.snd_pcm_sw_params_set_start_threshold( handle , sw_params , buffer_size+buffer_size%period_size ))
	aa( asound.snd_pcm_sw_params_set_avail_min	( handle , sw_params , period_size ))

	aa( asound.snd_pcm_sw_params ( handle , sw_params ))


	options.buffer_size = buffer_size
	options.period_size = period_size
	return options
end

local function getnext(options,maxframes)
	local src_base = options.buffer
	local src_chans = options.channels
	local src_bits_in_sample = asound.snd_pcm_format_physical_width(options.format)
	local src_framesize = src_bits_in_sample/8*src_chans
	local src_buffer_type = "int"..src_bits_in_sample.."_t*"

	local nxt = ffi.cast("intptr_t",src_base)
	local enddata = nxt+src_bits_in_sample/8*options.samples

	return function()
		local nxtbase = nxt

		local len = math.min ( maxframes , tonumber(enddata - nxtbase)/src_framesize )
		if len <= 0 then
			return nil
		end
		nxt = nxt + len*src_framesize

		return ffi.cast(src_buffer_type,nxtbase) , len
	end
end

local function xrunrecovery ( handle , err )
	print("stream recovery")
	if err == -constants.EPIPE then
		aa ( asound.snd_pcm_prepare ( handle ) )
		return true
	elseif err == -constants.ESTRPIPE then
		while true do
			err = asound.snd_pcm_resume ( handle )
			if err ~= -constants.EAGAIN then
				break
			end
			constants.sleep(1)
		end
		if err < 0 then
			aa ( asound.snd_pcm_prepare ( handle ) )
		end
	end
end

local function write_loop ( handle , options , sfx )
	local src_chans = options.channels
	
	local dst_chans = 2
	local dst_framesize = 4*dst_chans
	local dst_buffer_type = "float*"

	local buffsize = tonumber(options.buffer_size)
	local buffer = ffi.cast ( dst_buffer_type , new_buffer(buffsize*dst_framesize) )
	ffi.fill(buffer,buffsize*dst_framesize,0)

	for base , frames in getnext(options,buffsize) do
		--ffi.copy(buffer,base,len)
		local foo = 0
		for i=0,frames-1 do
			for c=0,(src_chans-1) do
				local offset = i*src_chans+c
				--Get sample
				local v = base[offset]
				v = sfx ( tonumber(v)/2^15 , c )
				-- Put into buffer
				buffer[offset]=v
			end
		end
		local ptr = buffer
		local cptr = frames
		while cptr > 0 do
			local err	
			repeat
				err = asound.snd_pcm_writei(handle , ptr , cptr )
			until err ~= -constants.EAGAIN
			if err < 0 then
				if not xrun_recovery ( handle , err ) then
					aa(err)
				end
				break
			end
			ptr = ffi.cast("void*" , ffi.cast("intptr_t",ptr) + err * dst_framesize )
			cptr = cptr - err
		end
	end
end

return {
	init = init ;
	load_interleaved = load_interleaved ;
	set_params = set_params ;
	write_loop = write_loop ;
}
