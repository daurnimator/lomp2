-- Source wav file

local strsub = string.sub

local raw_fd = require"sources.raw"

local ffi = require"ffi"

local uint32_t = ffi.new ( "uint32_t[1]" )
local function touint32 ( str , offset )
	offset = offset or 0
	ffi.copy ( uint32_t , ffi.cast ( "char*" , str ) + offset , 4 )
	return uint32_t[0]
end

local uint16_t = ffi.new ( "uint16_t[1]" )
local function touint16 ( str , offset )
	offset = offset or 0
	ffi.copy ( uint16_t , ffi.cast ( "char*" , str ) + offset , 2 )
	return uint16_t[0]
end

local function wav_fd ( fd , start )
	start = start or fd:seek ( "set" )

	local sample_rate , channels , audioformat , bitspersample , numsamples

	assert ( assert ( fd:read ( 4 ) ) == "RIFF" , "Not RIFF file" )
	local chunksize = touint32 ( assert ( fd:read ( 4 ) ) )
	assert ( assert ( fd:read ( 4 ) ) == "WAVE" , "RIFF file not WAVE format" )

	while true do
		local subchunkid = assert ( fd:read ( 4 ) )
		local subchunksize = touint32 ( assert ( fd:read ( 4 ) ) )

		if subchunkid == "fmt " then
			local subchunk = assert ( fd:read ( subchunksize ) )

			audioformat = 		touint16 ( subchunk , 0 )
			channels = 			touint16 ( subchunk , 2 )
			sample_rate = 		touint32 ( subchunk , 4 )
			local byterate = 	touint32 ( subchunk , 8 )
			local blockalign = 	touint16 ( subchunk , 12 )
			bitspersample = 	touint16 ( subchunk , 14 )
		elseif subchunkid == "data" then
			numsamples = subchunksize / channels / bitspersample * 8
			break
		else
			error ( "Unknown Subchunk ID: " .. subchunkid )
		end
	end

	assert ( audioformat == 1 , "Not PCM audio" )
	assert ( bitspersample == 8 or bitspersample == 16 , "Unknown data type" )
	-- TODO: 8 bit audio is unsigned......

	local format
	if channels == 1 then
		format = "MONO"
	elseif channels == 2 then
		format = "STEREO"
	else
		error ( "Don't support >2 channels" )
	end

	local source = raw_fd ( fd , fd:seek ( ) )
	source.from = 0
	source.to = numsamples
	source.sample_rate = sample_rate
	source.format = format .. tostring ( bitspersample )

	return source
end

return wav_fd
