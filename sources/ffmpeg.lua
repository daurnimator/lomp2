-- Source using ffmpeg

-- Takes a file path

local assert , error = assert , error
local tonumber = tonumber

local ffi 		= require"ffi"
local ffmpeg 	= require"FFmpeg"

local frame_size = ffi.new ( "int[1]" )

local function ffmpeg_file ( filename )
	local formatctx = ffmpeg.openfile ( filename )
	local audioctx = assert ( ffmpeg.findaudiostreams ( formatctx ) [ 1 ] , "No Audio Stream Found" )

	--print("Bitrate:", tonumber(audioctx.bit_rate))
	--print("Sample type:", ({[0]="u8", "s16", "s32", "flt", "dbl"})[audioctx.sample_fmt])

	local channels = audioctx.channels
	local bytes_per_frame = ffmpeg.avutil.av_get_bytes_per_sample ( audioctx.sample_fmt ) * channels
	local output_type = ffmpeg.format_to_type [ audioctx.sample_fmt ]

	local format = ( ( channels == 1 and "MONO" )
					or ( channels == 2 and "STEREO" )
					or error ( ) )
				.. ( ( output_type == "int16_t" and "16" )
					or ( output_type == "int8_t" and "8" )
					or ( output_type == "float" and "_FLOAT32" )
					or error ( ) )

	--assert ( bytes_per_frame == sizeof ( output_type ) )

	local iter , const , packet = ffmpeg.read_frames ( formatctx )
	local pos

	return {
		from = 0 ;
		to = tonumber ( formatctx.duration / ffmpeg.AV_TIME_BASE * audioctx.sample_rate ) ;
		sample_rate = tonumber ( audioctx.sample_rate ) ;
		format = format ;

		reset = function ( self )
			pos = self.from
			self:seek ( pos )
		end ;

		source = function ( self , dest , len )
			--ffmpeg.avAssert ( ffmpeg.avcodec.avcodec_decode_audio3 ( audioctx , dest , frame_size , packet ) )
			local d = 0
			repeat
				packet = iter ( const , packet )
				if not packet then -- End of file
					pos = pos + d
					return false , d
				end

				frame_size[0] = len * bytes_per_frame

				ffmpeg.avAssert ( audioctx.codec.decode ( audioctx , dest+d*channels , frame_size , packet ) )
				local size = tonumber ( frame_size[0] ) / bytes_per_frame -- frame_size is in bytes

				d = d + size
			until d+size > len -- Stop if the next iteration might go over

			pos = pos + d

			return true , d
		end ;

		position = function ( self )
			return pos
		end ;

		seek = function ( self , newpos )
			local ts = newpos * ffmpeg.AV_TIME_BASE / self.sample_rate
			ffmpeg.avAssert ( ffmpeg.avformat.av_seek_frame ( formatctx , -1 , ts , 0 ) )--ffmpeg.avutil.AVSEEK_FLAG_BACKWARD +  ffmpeg.avutil.AVSEEK_FLAG_ANY + ffmpeg.avutil.AVSEEK_FLAG_FRAME ) )
			pos = newpos
		end ;
	}
end

return ffmpeg_file
