-- Source using ffmpeg

-- Takes a file path

local assert , error = assert , error
local tonumber = tonumber

local ffi 		= require"ffi"
local ffmpeg 	= require"FFmpeg"

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

return ffmpeg_file
