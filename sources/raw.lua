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
		to = fd:seek ( "end" ) ;
		sample_rate = 44100 ;
		format = "STEREO16" ;
		source = function ( self , dest , len )
			if not pos then
				assert ( self.to > self.from )
				pos = self.from
				bytes_per_frame = openal.format_to_channels [ self.format ] * ffi.sizeof ( openal.format_to_type [ self.format ] )
				assert ( fd:seek ( "set" ) )
			end

			local frames_read = min ( self.to - pos , len )
			pos = pos + frames_read

			local data = fd:read ( frames_read*bytes_per_frame )
			ffi.copy ( dest , data , frames_read*bytes_per_frame )

			return pos < self.to , frames_read
		end ;
		progress = function ( self )
			return pos
		end ;
	}
end

return raw_file
