package.path = package.path .. ";./?/init.lua"

local ffi = require"ffi"
local ffmpeg = 		require"ffmpeg"
local avAssert = 	ffmpeg.avAssert
local avcodec = 	ffmpeg.avcodec
local avformat =	ffmpeg.avformat

local FILENAME = arg[1] or 'song.mp3'
local SECTION = print

SECTION "Opening file"

local formatctx = ffmpeg.openfile ( FILENAME )
local audioctx = assert ( ffmpeg.findaudiostreams ( formatctx ) [ 1 ] , "No Audio Stream Found" )

print("Bitrate:", tonumber(audioctx.bit_rate))
print("Channels:", tonumber(audioctx.channels))
print("Sample rate:", tonumber(audioctx.sample_rate))
print("Sample type:", ({[0]="u8", "s16", "s32", "flt", "dbl"})[audioctx.sample_fmt])

SECTION "Decoding"

local all_samples = {}
local total_samples = 0

local buffsize = ffmpeg.AVCODEC_MAX_AUDIO_FRAME_SIZE
local frame_size = ffi.new("int[1]")

local output_type = ffmpeg.format_to_type [ audioctx.sample_fmt ]
local output_buff = ffi.new ( output_type .. "[?]" , buffsize )
for packet in ffmpeg.read_frames ( formatctx ) do
	frame_size[0] = buffsize
	avAssert ( avcodec.avcodec_decode_audio3 ( audioctx , output_buff , frame_size , packet ) )
	local size = tonumber ( frame_size[0] ) / ffi.sizeof ( output_type ) -- frame_size is in bytes

	local frame = ffi.new("int16_t[?]", size)
	ffi.copy(frame, output_buff, size*2)
	all_samples[#all_samples + 1] = frame
	total_samples = total_samples + size
end

SECTION "Merging samples"


local samples = ffi.new("int16_t[?]", total_samples)
local offset = 0
for _,s in ipairs(all_samples) do
	local size = ffi.sizeof(s)
	ffi.copy(samples + offset, s, size)
	offset = offset + size/2
end

SECTION "Processing"

-- The `samples` array is now ready for some processing! :)

-- ... like writing it raw to a file

local out = assert(io.open('samples.raw', 'wb'))
local size = ffi.sizeof(samples)
out:write(ffi.string(samples, size))
out:close()

-- Now you can open it in any audio processing program to see that it works.
-- In Audacity: Project -> Import Raw Data (and fill out according to info)
