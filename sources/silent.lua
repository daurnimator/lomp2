-- Source raw from file descripor

local huge , max = math.huge , math.max

local openal = require"OpenAL"

local function silent_source ( )
	local i , channels

	return {
		from = 0 ;
		to = math.huge ;
		format = "STEREO16" ;
		sample_rate = 44100 ;

		reset = function ( self )
			i = i or self.from
			channels = openal.format_to_channels [ self.format ]
		end ;

		source = function ( self , dest , len )
			if i + len > self.to then
				len = max ( 0 , self.to - i )
			end

			for j=0 , (len*channels)-1 do
				dest[j] = 0
			end

			i = i+len

			return i <= self.to , len
		end ;

		position = function ( self )
			return i
		end ;

		seek = function ( self , pos )
			i = pos + self.from
		end ;
	}
end

return silent_source
