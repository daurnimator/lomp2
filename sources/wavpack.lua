-- Source using libwavpack

local wavpack 	= require"WavPack"
local ffi 		= require"ffi"

-- Shared buffer
local buff
local buff_size = 0

local source = function ( self , dest , len )
	if buff_size < len then -- Increase size of buffer
		buff = ffi.new ( "int32_t[?]" , len*self.info.channels )
		buff_size = len
	end

	local n = math.min ( len , self.to - self.wc:pos ( ) )
	if n <= 0 then return false , 0 end

	n = self.wc:unpack ( buff , n )

	local channels = self.info.channels
	for i=0 , n-1 do
		for c = 0 , channels - 1 do
			dest [ i*channels + c ] = buff [ i*channels + c ]
		end
	end

	return true , n
end

local position = function ( self )
	return self.wc:pos ( )
end

local seek = function ( self , pos )
	self.wc:seek ( pos )
end

local function wavpack_file ( filename )
	local wc = wavpack.openfile ( filename )
	local info = wc:getinfo ( )
	local format = 	( ( info.channels == 1 and "MONO" )
					or ( info.channels == 2 and "STEREO" )
					or error ( ) ) .. "16"

	return {
		from = 0 ;
		to = info.num_samples ;
		sample_rate = info.sample_rate ;
		format = format ;

		source = source ;
		position = position ;
		seek = seek ;

		wc = wc ;
		info = info ;
	}
end

return wavpack_file
