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

			for i=0,(len*channels)-1 do
				dest[i] = 0
			end

			i = i+len
			return i <= self.to , len + min ( 0 , self.to - i )
		end ;
	}
end

return silent_source
