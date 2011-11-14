-- Source raw from file descripor

-- Takes:
--  a pitch

local tonumber = tonumber
local huge , max = math.huge , math.max

local general = require"general"
local generatesinusoid = general.generatesinusoid

local openal = require"OpenAL"

local function sine ( pitch )
	local channels , scale , sample_rate
	return {
		from = 0 ;
		to = huge ;
		sample_rate = 44100 ;
		format = "STEREO16" ;

		reset = function ( self )
			self.pos = self.from
			sample_rate = self.sample_rate
			channels = openal.format_to_channels [ self.format ]
			scale = 2^( (tonumber(self.format:match("(%d+)$")) or 2) - 1 ) - 1
		end ;

		source = function ( self , dest , len )
			local sine = generatesinusoid ( pitch , sample_rate )

			if len > self.to - self.pos then
				len = max ( 0 , self.to - self.pos )
			end

			for i=0 , len-1 do
				local v = scale * sine ( self.pos ) + 0.5 --Add half so it rounds instead of truncating
				for j=0 , channels - 1 do
					dest [ i*2 + j ] = v
				end
				self.pos = self.pos + 1
			end

			return self.pos < self.to , len
		end ;

		position = function ( self )
			return self.pos
		end ;

		seek = function ( self , newpos )
			self.pos = newpos
		end ;
	}
end

return sine
