-- Source raw from file descripor

-- Takes:
--  a file descriptor

local assert = assert
local min = math.min

local ffi = require"ffi"
local openal = require"OpenAL"

local function raw_file ( fd )
	local bytes_per_frame
	local pos
	return {
		from = 0 ;
		to = fd:seek ( "end" ) / 4 ; -- Only a guess
		sample_rate = 44100 ; -- This should be changed by the calling func
		format = "STEREO16" ; -- This should be changed by the calling func

		source = function ( self , dest , len )
			if not pos then
				assert ( self.to > self.from )
				pos = self.from
				bytes_per_frame = openal.format_to_channels [ self.format ] * ffi.sizeof ( openal.format_to_type [ self.format ] )
				assert ( self.fd:seek ( "set" , pos*bytes_per_frame ) )
			end

			local frames_read = min ( self.to - pos , len )
			pos = pos + frames_read

			local data = self.fd:read ( frames_read*bytes_per_frame )
			ffi.copy ( dest , data , frames_read*bytes_per_frame )
			return pos < self.to , frames_read
		end ;

		position = function ( self )
			return pos
		end ;

		seek = function ( self , newpos )
			pos = newpos
			assert ( self.fd:seek ( "set" , pos*bytes_per_frame ) )
		end ;

		fd = fd ;
	}
end

return raw_file
