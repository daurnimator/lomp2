local assert = assert
local floor = math.floor

local general 			= require"general"
local len 				= general.len
local nearestpow2 		= general.nearestpow2
local generatesinusoid 	= general.generatesinusoid
local sleep 			= general.sleep
local sources			= require"sources"

local ffi 				= require"ffi"
local new_fifo 			= require"fifo"
local openal 			= require"OpenAL"

local int = ffi.new ( "ALint[1]" ) --temporary int to store crap in
local dev = openal.opendevice ( )
local ctx = openal.newcontext ( dev )
openal.alcMakeContextCurrent ( ctx )

-- Get native sample rate
openal.alcGetIntegerv ( dev , openal.ALC_FREQUENCY , 1 , int )
local native_sample_rate = int[0]

local empty_item = sources.silent ( )
empty_item.sample_rate = native_sample_rate

local function setup ( )
	-- Create source queue
	local queue = new_fifo ( )
	queue:setempty ( function ( f ) return empty_item end )

	local BUFF_SIZE = 192000
	local NUM_BUFFERS = 4
	local buffers = openal.newbuffers ( NUM_BUFFERS )
	local buffer = ffi.new ( "ALuint[1]" )
	local source_data = ffi.new ( "char[?]" , BUFF_SIZE )

	local function add_to_buffer ( item , buff )
		local format = item.format
		local ci_type = openal.format_to_type [ format ]
		local ci_bytes_per_frame = openal.format_to_channels [ format ] * ffi.sizeof ( ci_type )
		local ci_fit_samples_in_buff = floor ( BUFF_SIZE / ci_bytes_per_frame )
		local hasmore , done = item:source ( ffi.cast ( ci_type .. "*" , source_data ) , ci_fit_samples_in_buff )
		openal.alBufferData ( buff , openal.format [ format ] , source_data , done * ci_bytes_per_frame , item.sample_rate )
		return hasmore , done / item.sample_rate
	end
	local sourcequeue , source_from , source_to
	local step = coroutine.wrap ( function ( )
		sourcequeue = {
			{
				item = queue:pop ( ) ;
				alsource = openal.newsource ( ) ;
			}
		}
		source_from = 1 -- Source to unqueue from
		source_to = 1 -- Source to queue to

		-- Queue 0 length data in all buffers
		-- do it from the first item so we don't waste a random source
		-- then play; so that all buffers have been processed
		-- also make a reverse index of buffers
		local buff_to_index = { }
		for i = 0 , NUM_BUFFERS - 1 do
			buff_to_index [ buffers[i] ] = i
			local item = sourcequeue [ source_from ].item
			openal.alBufferData ( buffers[i] , openal.format [ item.format ] , source_data , 0 , item.sample_rate )
		end
		sourcequeue [ source_from ].alsource:queue ( NUM_BUFFERS , buffers )
		sourcequeue [ source_from ].alsource:play ( )
		assert(openal.checkforerror())

		local time_in_buffers = { }
		local time_buffered = 0 -- Should be a total of the above table
		while true do
			local processed = sourcequeue [ source_from ].alsource:buffers_processed ( )
			if processed > 0 then
				repeat
					-- Get our buffer back
					sourcequeue [ source_from ].alsource:unqueue ( 1 , buffer)
					local time_of_last = openal.buffer_info ( buffer[0] ).duration
					time_buffered = time_buffered - time_of_last

					if sourcequeue [ source_from ].alsource:buffers_queued ( ) == 0 then
						sourcequeue [ source_from ] = nil
						source_from = source_from + 1
					end

					-- Fill up the buffer
					local hasmore , time
					repeat
						local hasmore
						hasmore , time = add_to_buffer ( sourcequeue [ source_to ].item , buffer[0] )
						if not hasmore then
							source_to = source_to + 1
							sourcequeue [ source_to ] = {
								item = queue:pop ( ) ;
								alsource = openal.newsource ( ) ;
							}
						end
					until time > 0
					time_buffered = time_buffered + time
					time_in_buffers [ buffer[0] ] = time

					-- Add buffer to queue
					sourcequeue [ source_to - (hasmore and 1 or 0) ].alsource:queue ( 1 , buffer )

				until sourcequeue [ source_from ].alsource:buffers_processed ( ) == 0

				-- Did all buffers run out and hence cause state to stop playing?
				if sourcequeue [ source_from ].alsource:state ( ) ~= openal.AL_PLAYING then
					sourcequeue [ source_from ].alsource:play ( )
				end
				assert(openal.checkforerror())
			end

			-- Wait the amount of time in the currently playing buffer
			local current_buffer = buffers [ ( buff_to_index [ buffer[0] ] + 1 ) % NUM_BUFFERS ]
			coroutine.yield ( time_in_buffers [ current_buffer ] )
		end
	end )

	return {
		queue = queue ;
		step = step ;
		play = play ;
		nowplaying = function ( ) return sourcequeue [ source_from ].item end ;
		buffers = buffers ;
		setvolume = openal.setvolume ;--function (v) return alsource:setvolume(v) end ;
		getvolume = openal.getvolume ;--function () return alsource:getvolume() end ;
	}
end

return setup
