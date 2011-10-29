local general 			= require"general"
local len 				= general.len
local nearestpow2 		= general.nearestpow2
local generatesinusoid 	= general.generatesinusoid
local sleep 			= general.sleep
local sources			= require"sources"

local ffi 				= require"ffi"
local new_fifo 			= require"fifo"
local openal 			= require"OpenAL"

local int = ffi.new("ALint[1]") --temporary int to store crap in
local dev = openal.opendevice()
local ctx = openal.newcontext(dev)
openal.alcMakeContextCurrent(ctx)

openal.alcGetIntegerv(dev,openal.ALC_FREQUENCY,1,int)
local native_sample_rate = int[0]

local empty_item = sources.silent ( )
empty_item.sample_rate = native_sample_rate

local function setup ( )
	-- Create source queue
	local queue = new_fifo ( )
	queue:setempty ( function ( f ) return empty_item end )

	local BUFF_SIZE = 8192*2
	local source_data = ffi.new ( "char[?]" , BUFF_SIZE )

	local alsource
	local current_item, ci_bytes_per_frame , ci_fit_samples_in_buff , ci_format , ci_sample_rate , ci_type

	local function grab ( buff )
		local hasmore , done = current_item:source ( ffi.cast(ci_type .. "*",source_data) , ci_fit_samples_in_buff )

		local size = done*ci_bytes_per_frame -- Find out size (in bytes) of data
		openal.alBufferData( buff , ci_format , source_data , size , ci_sample_rate )
		assert(openal.checkforerror())

		if not hasmore then
			current_item = nil -- no data left in source; clear item.
			return false
		end
		return true
	end

	local NUM_BUFFERS = 3
	local buffers = openal.newbuffers ( NUM_BUFFERS )
	local buffer = ffi.new ( "ALuint[1]" )
	local function step ( )
		local guess_length
--print("PRE",current_item,alsource and alsource:buffers_queued ( ),alsource and alsource:buffers_processed())
		if current_item == nil then
			-- Make sure buffers are empty before we start a new item.
			local queued = 0
			if alsource then
				queued = alsource:buffers_queued ( )
				if queued > 1 then
					for i=1 , alsource:buffers_processed ( ) do
						alsource:unqueue ( 1 , buffer )
					end
					queued = alsource:buffers_queued ( )
					assert(openal.checkforerror())
					guess_length = ci_fit_samples_in_buff*(queued-1)
				end
			end
--print("QUEUED",queued)
			if queued <= 1 then
				current_item = queue:pop ( ) -- Get new item
--print("POP",current_item,current_item.from,current_item.to)
				local format = current_item.format
				ci_format = openal.format [ format ]
				assert ( ci_format , "Invalid format: " , format )
				local channels = openal.format_to_channels [ format ]
				ci_type = openal.format_to_type [ format ]
				local type_size = ffi.sizeof ( ci_type )
				ci_bytes_per_frame = channels*type_size
				ci_fit_samples_in_buff = math.floor ( BUFF_SIZE/ci_bytes_per_frame )
				ci_sample_rate = current_item.sample_rate

				if queued == 1 then
					--Busy wait for current buffer to finish
					while alsource:buffers_queued ( ) > 0 do
						sleep()
						for i=1 , alsource:buffers_processed ( ) do
							alsource:unqueue ( 1 , buffer )
						end
					end
					assert(openal.checkforerror())
				end

				-- Fill up buffers
				local i = 0
				while i < NUM_BUFFERS and grab ( buffers [i] ) do --Order matters
					i = i+1
				end
--print("FILLED",i)
				alsource = openal.newsource ( ) -- Make a new source TODO: use existing source if possible
				alsource:queue ( i , buffers ) -- Cue up as many buffers as we filled
				alsource:play() -- Start playback of source

				assert(openal.checkforerror())
				guess_length = ci_fit_samples_in_buff
			end
		else
			local processed = alsource:buffers_processed ( )
			if processed > 0 then
				-- Fill up processed buffers
				for i=1 , processed do
					alsource:unqueue ( 1 , buffer)
					local hasmore = grab ( buffer[0] )
					alsource:queue ( 1 , buffer )
					if not hasmore then -- No more data left in current item?
						break
					end
				end

				-- Did all buffers run out and hence cause state to stop playing?
				if alsource:state ( ) ~= openal.AL_PLAYING then
					alsource:play ( )
				end
			end
			assert(openal.checkforerror())
			guess_length = ci_fit_samples_in_buff*(NUM_BUFFERS-1)
        end
--print("POST",current_item,alsource and alsource:buffers_queued ( ),alsource and alsource:buffers_processed())
		return guess_length / ci_sample_rate
	end

	return {
		queue = queue ;
		step = step ;
		play = play ;
		nowplaying = function ( ) return current_item end ;
		buffers = buffers ;
		setvolume = openal.setvolume ;--function (v) return alsource:setvolume(v) end ;
		getvolume = openal.getvolume ;--function () return alsource:getvolume() end ;
	}
end

return setup
