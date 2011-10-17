local assert , error = assert , error
local tonumber = tonumber
local huge , min = math.huge , math.min

local general = require"general"
local generatesinusoid = general.generatesinusoid

local ffi 		= require"ffi"
local openal	= require"OpenAL"
local ffmpeg 	= require"FFmpeg"

local function sine ( pitch )
	local sini , sample_rate , channels , scale
	return {
		from = 0 ;
		to = huge ;
		sample_rate = 44100 ;
		format = "STEREO16" ;
		source = function ( self , dest , len )
			if sini == nil then
				assert ( self.to > self.from )
				sini = self.from
				sample_rate = self.sample_rate
				channels = openal.format_to_channels [ self.format ]
				scale = 2^( (tonumber(self.format:match("(%d+)$")) or 2) -1) - 1
			end

			local sine = generatesinusoid ( pitch , sample_rate )

			for i=0 , len-1 do
				local v = scale*sine(i+sini)+0.5 --Add half so it rounds instead of truncating
				for j=0 , channels-1 do
					dest[i*2+j] = v
				end
			end
			sini = sini+len
			return sini <= self.to , len + min ( 0 , self.to - sini )
		end ;
		progress = function ( self )
			return sini
		end ;
	}
end

local function raw_file ( fd )
	local bytes_per_frame
	local pos
	return {
		from = 0 ;
		to = fd:seek ( "end" ) ;
		sample_rate = 44100 ; -- A guess
		format = "STEREO16" ;
		source = function ( self , dest , len )
			if not pos then
				assert(self.to>self.from)
				pos = self.from
				bytes_per_frame = openal.format_to_channels [ self.format ] * ffi.sizeof ( openal.format_to_type [ self.format ] )
				assert( fd:seek ( "set" , pos*bytes_per_frame ) )
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

local function ffmpeg_file ( filename )
	local formatctx = ffmpeg.openfile ( filename )
	local audioctx = assert ( ffmpeg.findaudiostreams ( formatctx ) [ 1 ] , "No Audio Stream Found" )

	--print("Bitrate:", tonumber(audioctx.bit_rate))
	--print("Sample type:", ({[0]="u8", "s16", "s32", "flt", "dbl"})[audioctx.sample_fmt])

	local channels = audioctx.channels
	local bytes_per_frame = ffmpeg.avutil.av_get_bytes_per_sample ( audioctx.sample_fmt ) * channels
	local output_type = ffmpeg.format_to_type [ audioctx.sample_fmt ]
	local frame_size = ffi.new ( "int[1]" )

	local format = ( ( channels == 1 and "MONO" )
					or ( channels == 2 and "STEREO" )
					or error() )
				.. ( (output_type == "int16_t" and "16")
					or (output_type == "int8_t" and "8")
					or ( output_type == "float" and "_FLOAT32" )
					or error() )

	--assert ( bytes_per_frame == sizeof ( output_type ) )

	local iter , const , packet = ffmpeg.read_frames ( formatctx )

	return {
		from = 0 ;
		to = formatctx.duration ;
		sample_rate = audioctx.sample_rate ;
		format = format ;
		source = function ( self , dest , len )
			--ffmpeg.avAssert ( ffmpeg.avcodec.avcodec_decode_audio3 ( audioctx , dest , frame_size , packet ) )
			local d = 0
			repeat
				packet = iter ( const , packet )
				if not packet then return false , 0 end

				frame_size[0] = len * bytes_per_frame

				ffmpeg.avAssert ( audioctx.codec.decode(audioctx,dest+d*channels,frame_size,packet) )
				local size = tonumber ( frame_size[0] ) / bytes_per_frame -- frame_size is in bytes

				d = d + size
			until d+size > len

			return true , d
		end ;
		progress = function ( self )
			return error("NYI")
		end ;
	}
end

return {
	raw = raw_file ;
	sinusoidal = sine ;
	ffmpeg_file = ffmpeg_file ;
}
