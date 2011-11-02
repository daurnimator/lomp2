-- Source using libmad

local assert , error = assert , error
local floor , huge , min = math.floor , math.huge , math.min
local ioopen = io.open

local mad = require"mad"
local ffi = require"ffi"

local function find_last ( tbl , n )
	local v
	while true do
		v = tbl [ n ]
		if v then return n , v end
		if n < 0 then return 0 , tbl[0] end
		n = n - 1
	end
end

local function mad_file ( filename , duration )
	local file = ioopen ( filename , "rb" )
	local m = mad.new ( )

	local lastpos = 0
	local getmore = function ( dest , len , overshoot )
		lastpos = file:seek ( ) - overshoot
		local s = file:read ( len )
		if s == nil then -- EOF
			return false
		end
			ffi.copy ( dest , s , #s )
		return #s
	end

	local iter , const , header = m:frames ( getmore )

	local frame_length = header:length ( )
	local channels = header:channels ( )

	local format = 	( ( channels == 1 and "MONO" )
					or ( channels == 2 and "STEREO" )
					or error ( ) ) .. "16"

	local pos , seektable = 0 , { }
	local skip = 0

	local seek = function ( self , newpos )
		local framenum = floor ( newpos / frame_length )
		local closestframe
		closestframe , lastpos = find_last ( seektable , framenum-2 ) -- Go back at least 2 frames before target
		assert ( file:seek ( "set" , lastpos ) )

		pos = closestframe
		m:reset ( )
		assert ( m:skipframe ( getmore , framenum - closestframe - 2 , function ( header , stream )
				seektable [ pos ] = seektable [ pos ] or lastpos + ( stream.this_frame - m.buffer )
				pos = pos + 1
			end ) , "Unexpected EOF" )
		iter , const , header = m:frames ( getmore )
		-- Need to decode one frame before to make sure all the internal structure is correct
		header = iter ( const , header )
		if not header then error ( "Unexpected EOF" ) end

		skip = newpos - framenum*frame_length
		pos = framenum
	end

	local first = true
	local source = function ( self , dest , len )
		if first then
			self:seek ( self.from )
			first = false
		end

		local i = -skip

		local frames = floor ( (len-i)/frame_length )
		for f = 0 , frames - 1 do
			local pcm , stream
			header , stream , pcm = iter ( const , header )
			if not header then return false , i end

			seektable [ pos ] = seektable [ pos ] or lastpos + ( stream.this_frame - m.buffer )
			pos = pos + 1

			for j = 0 , frame_length - 1 do
				for c = 0 , channels - 1 do
					dest [ (i + j + skip)*channels + c ] = mad.to16bit ( pcm.samples[c][j] )
				end
			end
			i = i + frame_length
		end

		skip = 0

		return true , i
	end

	if not duration then
		m:skipframe ( getmore , huge , function ( header , stream )
				seektable [ pos ] = seektable [ pos ] or lastpos + ( stream.this_frame - m.buffer )
				pos = pos + 1
			end )
		duration = pos * frame_length

		-- Go back to start
		seek ( nil , 0 )
	end

	return {
		from = 0 ;
		to = duration ;
		sample_rate = header.samplerate ;
		format = format ;

		source = source ;
		position = function ( self )
			return pos * frame_length-skip
		end ;
		seek = seek ;
	}
end

return mad_file
