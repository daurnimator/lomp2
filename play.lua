local assert , error = assert , error
local next , pairs = next , pairs
local setmetatable , tonumber = setmetatable , tonumber
local floor , huge = math.floor , math.huge
local min, max = math.min , math.max
local cocreate , coresume , coyield = coroutine.create , coroutine.resume , coroutine.yield


local general 			= require"general"
local len 				= general.len
local nearestpow2 		= general.nearestpow2
local generatesinusoid 	= general.generatesinusoid
local sleep 			= general.sleep
local sources			= require"sources"

local ffi 				= require"ffi"
local new_fifo 			= require"fifo"
local openal 			= require"OpenAL"

local int = ffi.new ( "ALint[1]" )
local uint = ffi.new ( "ALuint[1]" )

local dev = openal.opendevice ( )
local ctx = openal.newcontext ( dev )
openal.alcMakeContextCurrent ( ctx )

-- Get native sample rate
openal.alcGetIntegerv ( dev , openal.ALC_FREQUENCY , 1 , int )
local native_sample_rate = int[0]

local empty_item = sources.silent ( )
empty_item.sample_rate = native_sample_rate

-- Indexed by [sample_rate][format]
local sources = setmetatable ( { } , {
	__index = function ( sources , sample_rate )
		local v = setmetatable ( { } , {
			__index = function ( t , format )
				local alsource = openal.newsource ( )
				t [ format ] = alsource
				return alsource
			end ;
		} )
		sources [ sample_rate ] = v
		return v
	end ;
} )

local function setup ( )
	local finished = false
	-- Create source queue
	local queue = new_fifo ( )
	queue:setempty ( function ( f )
		finished = true
		return empty_item
	end )

	local push = function ( self , item )
		queue:push ( item )
	end

	local source_queue_mt = {
		__index = function ( t , k )
			finished = false
			local item = queue:pop ( )
			item:reset ( )

			local v = {
				item = item ;
				alsource = sources [ item.sample_rate ] [ item.format ] ;
				buffers = { } ; -- The set of buffers attached to this source
				buffer_i = 1 ; -- Next number of buffer (this lets you know what order the buffers are in)
				played = 0 ;
			}
			t [ k ] = v
			return v
		end ;
	}

	local BUFF_SIZE = 192000
	local NUM_BUFFERS = 3
	local buffers = openal.newbuffers ( NUM_BUFFERS )
	local source_data = ffi.new ( "char[?]" , BUFF_SIZE )

	local sourcequeue , source_from , source_to

	local function new_song ( item ) end
	local function set_new_song ( self , func )
		new_song = function ( item )
			if item ~= empty_item then
				return func ( self , item )
			end
		end
	end

	local function add_empty_buff ( item , buff )
		openal.alBufferData ( buff , openal.format [ item.format ] , source_data , 0 , item.sample_rate )
		openal.assert ( )
	end

	local function init_buffers ( item )
		-- Queue 0 length data in all buffers
		-- do it from the first item so we don't waste a random source
		-- then play; so that all buffers have been processed
		-- also make a reverse index of buffers
		for i = 0 , NUM_BUFFERS - 1 do
			add_empty_buff ( item , buffers[i] )
			sourcequeue [ source_from ].buffers [ buffers[i] ] = sourcequeue [ source_from ].buffer_i
			sourcequeue [ source_from ].buffer_i = sourcequeue [ source_from ].buffer_i + 1
			sourcequeue [ source_from ].played = 0
		end
		sourcequeue [ source_from ].alsource:queue ( NUM_BUFFERS , buffers )
	end

	local function add_to_buffer ( item , buff )
		local format = item.format
		local ci_type = openal.format_to_type [ format ]
		local ci_bytes_per_frame = openal.format_to_channels [ format ] * ffi.sizeof ( ci_type )
		local ci_fit_samples_in_buff = floor ( BUFF_SIZE / ci_bytes_per_frame )

		local hasmore , done = item:source ( ffi.cast ( ci_type .. "*" , source_data ) , ci_fit_samples_in_buff )

		openal.alBufferData ( buff , openal.format [ format ] , source_data , done * ci_bytes_per_frame , item.sample_rate )
		openal.assert ( )

		local duration = done / item.sample_rate

		return hasmore , duration
	end

	local function fill_and_queue ( buff )
		local hasmore , time
		while true do
			if finished then
				add_empty_buff ( sourcequeue [ source_to ].item , buff )
				break
			else
				hasmore , time = add_to_buffer ( sourcequeue [ source_to ].item , buff )
				if time > 0 then
					uint[0] = buff
					sourcequeue [ source_to ].alsource:queue ( 1 , uint )
					sourcequeue [ source_to ].buffers [ buff ] = sourcequeue [ source_to ].buffer_i
					sourcequeue [ source_to ].buffer_i = sourcequeue [ source_to ].buffer_i + 1
				end
				if not hasmore then
					source_to = source_to + 1
				end
				if time > 0 then
					break
				end
			end
		end
	end

	local play = true

	local loop = function ( self )
		sourcequeue = setmetatable ( { } , source_queue_mt )
		source_from = 1 -- Source to unqueue from
		source_to = 1 -- Source to queue to

		init_buffers ( sourcequeue [ source_from ].item )

		new_song ( sourcequeue [ source_from ].item )

		while true do
			if play then
				sourcequeue [ source_from ].alsource:play ( )
				play = false
			end

			while true do
				local processed = sourcequeue [ source_from ].alsource:buffers_processed ( )
				if processed == 0 then break
				else
					for i = 1 , processed do
						-- Get buffer back
						sourcequeue [ source_from ].alsource:unqueue ( 1 , uint )
						sourcequeue [ source_from ].played = sourcequeue [ source_from ].played + openal.buffer_info ( uint[0] ).frames
						sourcequeue [ source_from ].buffers [ uint[0] ] = nil

						if next ( sourcequeue [ source_from ].buffers ) == nil then -- Source done; move on
							sourcequeue [ source_from ] = nil
							source_from = source_from + 1

							new_song ( sourcequeue [ source_from ].item )
						end

						-- Loop/yield until queue has something in it
						if finished and source_from == source_to then
							local newob
							repeat
								coyield ( false )
								sourcequeue [ source_from ] = nil
								newob = sourcequeue [ source_from ]
							until newob.item ~= empty_item
							new_song ( sourcequeue [ source_from ].item )
						end

						-- Fill up empty buffer
						fill_and_queue ( uint[0] )
					end
					-- Did all buffers run out and hence cause state to stop playing?
					if sourcequeue [ source_from ].alsource:state ( ) ~= "playing" then
						sourcequeue [ source_from ].alsource:play ( )
					end
				end
			end

			local current_buffer = sourcequeue [ source_from ].alsource:current_buffer ( )
			local current_progress = sourcequeue [ source_from ].alsource:position_seconds ( )
			local comeback = openal.buffer_info ( current_buffer ).duration - current_progress

			assert ( comeback >= 0 , comeback )

			coyield ( comeback )
		end
	end

	local main = cocreate ( loop )

	local step = function ( self )
		local ok , r = coresume ( main )
		if ok then
			if r then -- It is time to wait until calling again
				return r
			else -- r is false: nothing left to play
				return r
			end
		else -- Error
			main = cocreate ( loop )
			error ( r )
		end
	end

	-- Goes forward n tracks (n defaults to 1)
	local next = function ( self , n )
		n = n or 1

		-- Fill in all the sources between current item and destination item
		for i = source_from , max ( source_from , source_to - 1 ) do
			source_to = source_to + 1
			if sourcequeue [ source_to ].item == empty_item then -- Important to fire the __index
				error ( [[Not enough items to "next" through]] )
			end
		end

		-- Clear+retreive+fill buffers between current item and destination item
		sourcequeue [ source_from ].alsource:rewind ( )
		for i = 1 , n do
			sourcequeue [ source_from ].alsource:clear ( )
			for buff in pairs ( sourcequeue [ source_from ].buffers ) do
				fill_and_queue ( buff )
			end
			sourcequeue [ source_from ] = nil
			source_from = source_from + 1
		end

		if sourcequeue [ source_from ].item ~= empty_item then
			new_song ( sourcequeue [ source_from ].item )
		end
		play = true
	end

	local seek = function ( self , newpos )
		assert ( newpos % 1 == 0 , "Invalid seek destination" )

		-- Seek the current item
		sourcequeue [ source_from ].item:seek ( newpos )

		-- Seek all files buffered back to their starts...
		for i = (source_from + 1) , source_to do
			sourcequeue [ i ].item:reset ( )
		end

		-- Clear all sources
		sourcequeue [ source_from ].alsource:rewind ( )
		for i = source_from , source_to do
			sourcequeue [ i ].alsource:clear ( )
			sourcequeue [ i ].buffers = { }
		end

		source_to = source_from

		-- Put all the buffers back in the queue
		init_buffers ( sourcequeue [ source_from ].item )

		sourcequeue [ source_from ].played = newpos
		play = true
	end

	local position = function ( self )
		return sourcequeue [ source_from ].played + sourcequeue [ source_from ].alsource:position ( )
	end

	return {
		push = push ;

		step = step ;
		nowplaying = function ( self )
			return sourcequeue [ source_from ].item
		end ;

		next = next ;
		set_new_song = set_new_song ;

		seek = seek ;
		position = position ;

		buffers = buffers ;
		setvolume = openal.setvolume ;
		getvolume = openal.getvolume ;
	}
end

return setup
