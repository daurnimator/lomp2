-- Source raw from file descripor

-- Takes:
--  a pitch

local tonumber = tonumber
local huge , min = math.huge , math.min

local general = require"general"
local generatesinusoid = general.generatesinusoid

local openal = require"OpenAL"

local function sine ( pitch )
	local sini , channels , scale
	return {
		from = 0 ;
		to = huge ;
		sample_rate = 44100 ;
		format = "STEREO16" ;
		source = function ( self , dest , len )
			if sini == nil then
				sini = self.from
				sample_rate = self.sample_rate
				channels = openal.format_to_channels [ self.format ]
				scale = 2^( (tonumber(self.format:match("(%d+)$")) or 2) -1) - 1
			end

			local sine = generatesinusoid ( pitch , sample_rate )

			if sini + len > self.to then
				len = self.to - sini
			end

			for i=0 , len-1 do
				local v = scale*sine(i+sini)+0.5 --Add half so it rounds instead of truncating
				for j=0 , channels-1 do
					dest[i*2+j] = v
				end
			end
			sini = sini + len

			return  sini ~= self.to , len
		end ;

		progress = function ( self )
			return sini
		end ;

		seek = function ( self , pos )
			sini = pos
		end ;
	}
end

return sine
