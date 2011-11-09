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
	local NUM_BUFFERS = 3
	local buffers = openal.newbuffers ( NUM_BUFFERS )
	local buffer = ffi.new ( "ALuint[1]" )
	local source_data = ffi.new ( "char[?]" , BUFF_SIZE )
	local buff_to_index = { }

	local time_in_buffers = { }
	local time_buffered = 0 -- Keep as total of the above table

	local sourcequeue = setmetatable ( { } , { __index = function ( t , k )
			local v = {
				item = queue:pop ( ) ;
				alsource = openal.newsource ( ) ;
			}
			t [ k ] = v
			return v
		end } )
	local source_from , source_to


	local function init_buffers ( item )
		-- Queue 0 length data in all buffers
		-- do it from the first item so we don't waste a random source
		-- then play; so that all buffers have been processed
		-- also make a reverse index of buffers
		for i = 0 , NUM_BUFFERS - 1 do
			time_in_buffers [ buffers[i] ] = 0
			buff_to_index [ buffers[i] ] = i
			openal.alBufferData ( buffers[i] , openal.format [ item.format ] , source_data , 0 , item.sample_rate )
		end
		sourcequeue [ source_from ].alsource:queue ( NUM_BUFFERS , buffers )
		sourcequeue [ source_from ].alsource:play ( )
	end

	local function add_to_buffer ( item , buff )
		local format = item.format
		local ci_type = openal.format_to_type [ format ]
		local ci_bytes_per_frame = openal.format_to_channels [ format ] * ffi.sizeof ( ci_type )
		local ci_fit_samples_in_buff = floor ( BUFF_SIZE / ci_bytes_per_frame )
		local hasmore , done = item:source ( ffi.cast ( ci_type .. "*" , source_data ) , ci_fit_samples_in_buff )

		openal.alBufferData ( buff , openal.format [ format ] , source_data , done * ci_bytes_per_frame , item.sample_rate )

		local duration = done / item.sample_rate
		time_buffered = time_buffered + duration - time_in_buffers [ buff ]
		time_in_buffers [ buff ] = duration

		return hasmore , duration
	end

	local function requeue ( )
		-- Get our buffer back
		sourcequeue [ source_from ].alsource:unqueue ( 1 , buffer )

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
			end
		until time > 0

		-- Add buffer to queue
		sourcequeue [ source_to - (hasmore and 1 or 0) ].alsource:queue ( 1 , buffer )
	end

	local step = coroutine.wrap ( function ( )
		source_from = 1 -- Source to unqueue from
		source_to = 1 -- Source to queue to

		init_buffers ( sourcequeue [ source_from ].item )

		while true do
			local processed = sourcequeue [ source_from ].alsource:buffers_processed ( )
			if processed > 0 then
				repeat
					requeue ( )
					processed = sourcequeue [ source_from ].alsource:buffers_processed ( )
				until processed == 0

				-- Did all buffers run out and hence cause state to stop playing?
				if sourcequeue [ source_from ].alsource:state ( ) ~= openal.AL_PLAYING then
					sourcequeue [ source_from ].alsource:play ( )
				end
			end

			-- Wait the amount of time in the currently playing buffer
			local current_buffer = buffers [ ( buff_to_index [ buffer[0] ] + 1 ) % NUM_BUFFERS ]
			local comeback = time_in_buffers [ current_buffer ]

			-- If this is the last buffer on a source; take off the current progress in the buffer
			if sourcequeue [ source_from ].alsource:buffers_queued ( ) == 1 then
				comeback = comeback - sourcequeue [ source_from ].alsource:position_seconds ( )
			end

			coroutine.yield ( comeback )
		end
	end )

	local seek = function ( self , newpos )
		local np = self:nowplaying ( )
		np:seek ( newpos )

		-- Clear all sources
		sourcequeue [ source_from ].alsource:rewind ( )
		for i = source_from , source_to do
			sourcequeue [ i ].alsource:clear ( )
		end

		-- Put all the buffers back in the queue
		init_buffers ( sourcequeue [ source_from ].item )

		repeat
			requeue ( )
		until sourcequeue [ source_from ].alsource:buffers_processed ( ) == 0

		sourcequeue [ source_from ].alsource:play ( )
	end

	local position = function ( self )
		local np = self:nowplaying ( )
		local r = np:position ( )

		---------------------- TODO: This is incorrect -------------------------------
		local frames_queued = 0
		for i = 1 , sourcequeue [ source_from ].alsource:buffers_queued ( ) do
			local buff = buffers [ ( buff_to_index [ buffer[0] ] + i ) % NUM_BUFFERS ]
			local info = openal.buffer_info ( buff )
			frames_queued = frames_queued + info.frames
		end
		------------------------------------------------------------------------------

		local openal_played = sourcequeue [ source_from ].alsource:position ( )

		return r - frames_queued + openal_played
	end

	return {
		queue = queue ;
		step = step ;
		nowplaying = function ( self ) return sourcequeue [ source_from ].item end ;

		seek = seek ;
		position = position ;

		buffers = buffers ;
		setvolume = openal.setvolume ;
		getvolume = openal.getvolume ;
	}
end

return setup
