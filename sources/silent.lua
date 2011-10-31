-- Source raw from file descripor

local huge , min = math.huge , math.min

local openal = require"OpenAL"

local function silent_source ( )
	local i , channels

	return {
		from = 0 ;
		to = math.huge ;
		format = "STEREO16" ;
		sample_rate = 44100 ;
		source = function ( self , dest , len )
			if i == nil then
				i = self.from
				channels = openal.format_to_channels [ self.format ]
			end

			for j=0 , (len*channels)-1 do
				dest[j] = 0
			end

			i = i+len
			return i <= self.to , len + min ( 0 , self.to - i )
		end ;

		progress = function ( self )
			return i
		end ;

		seek = function ( self , pos )
			i = pos
		end ;
	}
end

return silent_source
