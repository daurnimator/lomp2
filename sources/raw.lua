-- Source raw from file descripor

-- Takes:
--  a file descriptor

local assert = assert
local min , huge = math.min , math.huge

local ffi = require"ffi"
local openal = require"OpenAL"

local function raw_file ( fd , headersize )
	headersize = headersize or 0

	local bytes_per_frame
	local pos

	return {
		from = 0 ;
		to = huge ;
		sample_rate = 44100 ; -- This should be changed by the calling func
		format = "STEREO16" ; -- This should be changed by the calling func

		reset = function ( self )
			pos = self.from
			bytes_per_frame = openal.format_to_channels [ self.format ] * ffi.sizeof ( openal.format_to_type [ self.format ] )
			if self.to == huge then
				self.to = self.fd:seek ( "end" ) / bytes_per_frame
			end
			assert ( self.to > self.from )
			assert ( self.fd:seek ( "set" , pos*bytes_per_frame + self.headersize ) )
		end ;

		source = function ( self , dest , len )
			local frames_read = min ( self.to - pos , len )
			pos = pos + frames_read

			local data = assert ( self.fd:read ( frames_read*bytes_per_frame ) )
			ffi.copy ( dest , data , #data )

			if #data ~= frames_read*bytes_per_frame then
				return false , #data
			else
				return pos < self.to , frames_read
			end
		end ;

		position = function ( self )
			return pos
		end ;

		seek = function ( self , newpos )
			newpos = newpos + self.from
			assert ( self.fd:seek ( "set" , newpos*bytes_per_frame + self.headersize ) )
			pos = newpos
		end ;

		fd = fd ;
		headersize = headersize ;
	}
end

return raw_file
