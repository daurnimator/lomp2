local rel_dir = ...

-- FFI binding to OpenAL
local path_to_include = rel_dir .. "/" --[[C:\Program Files (x86)\OpenAL 1.1 SDK\include\]]
local dynlibname
if jit.os == "Windows" then
	dynlibname = [[OpenAL32.dll]]
elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
	dynlibname = "libopenal.so"
end

local general 				= require"general"
local reverse_lookup		= general.reverse_lookup
local add_dep 				= general.add_dependancy

local ffi = require"ffi"
local ffi_util = require"ffi_util"
local ffi_add_include_dir 	= ffi_util.ffi_add_include_dir
local ffi_defs 				= ffi_util.ffi_defs
local ffi_process_defines 	= ffi_util.ffi_process_defines

ffi_add_include_dir ( path_to_include )
ffi_add_include_dir [[/usr/include/AL/]]

ffi_defs ( rel_dir..[[/defs.h]] , { --TODO: remove rel_dir
		[[al.h]] ;
		[[alc.h]] ;
	} )
local openal_defs = {}
ffi_process_defines( [[al.h]] , openal_defs )
ffi_process_defines( [[alc.h]], openal_defs )

local openal_lib = ffi.load ( dynlibname )

local openal = setmetatable({},{__index = function (t,k) return openal_defs[k] or openal_lib[k] end;})

local int = ffi.new("ALint[1]")
local uint = ffi.new("ALuint[1]")
local float = ffi.new("ALfloat[1]")

openal.sourcetypes = {
	[openal_defs.AL_STATIC] 		= "static" ;
	[openal_defs.AL_STREAMING] 		= "streaming" ;
	[openal_defs.AL_UNDETERMINED] 	= "undetermined" ;
}
openal.format = {
	MONO8 			= openal_defs.AL_FORMAT_MONO8 ;
	MONO16 			= openal_defs.AL_FORMAT_MONO16 ;
	STEREO8 		= openal_defs.AL_FORMAT_STEREO8 ;
	STEREO16 		= openal_defs.AL_FORMAT_STEREO16 ;
	MONO_FLOAT32 	= openal.alGetEnumValue("AL_FORMAT_MONO_FLOAT32") ;
    STEREO_FLOAT32 	= openal.alGetEnumValue("AL_FORMAT_STEREO_FLOAT32") ;
	["QUAD16"] 		= openal.alGetEnumValue("AL_FORMAT_QUAD16") ;
	["51CHN16"] 	= openal.alGetEnumValue("AL_FORMAT_51CHN16") ;
	["61CHN16"] 	= openal.alGetEnumValue("AL_FORMAT_61CHN16") ;
	["71CHN16"] 	= openal.alGetEnumValue("AL_FORMAT_71CHN16") ;
}
reverse_lookup ( openal.format , openal.format )

openal.format_to_channels = {
	MONO8 			= 1 ;
	MONO16 			= 1 ;
	STEREO8 		= 2 ;
	STEREO16 		= 2 ;
	MONO_FLOAT32 	= 1 ;
	STEREO_FLOAT32 	= 2 ;
	["QUAD16"] 		= 4 ;
	["51CHN16"] 	= 6 ;
	["61CHN16"] 	= 7 ;
	["71CHN16"] 	= 8 ;
}
openal.format_to_type = {
	MONO8 			= "int8_t" ;
	MONO16 			= "int16_t" ;
	STEREO8 		= "int8_t" ;
	STEREO16 		= "int16_t" ;
	MONO_FLOAT32 	= "float" ;
	STEREO_FLOAT32 	= "float" ;
	["QUAD16"] 		= "int16_t" ;
	["51CHN16"] 	= "int16_t" ;
	["61CHN16"] 	= "int16_t" ;
	["71CHN16"] 	= "int16_t" ;
}
--[[openal.type_to_scale = {
	["int8_t"] = 		2^(8-1)-1 ;
	["int16_t"] = 		2^(16-1)-1 ;
	["float"] = 		1 ;
}--]]
openal.error = {
	[openal_defs.AL_NO_ERROR] 			= "No Error." ;
	[openal_defs.AL_INVALID_NAME] 		= "Invalid Name paramater passed to AL call." ;
	[openal_defs.AL_ILLEGAL_ENUM] 		= "Invalid parameter passed to AL call." ;
	[openal_defs.AL_INVALID_VALUE] 		= "Invalid enum parameter value." ;
	[openal_defs.AL_INVALID_OPERATION] 	= "Illegal call." ;
	[openal_defs.AL_OUT_OF_MEMORY] 		= "Out of memory." ;
}
local function checkforerror ( )
	local e = openal.alGetError ( )
	return e == openal_defs.AL_NO_ERROR , openal.error[e]
end
openal.checkforerror = checkforerror

function openal.opendevice ( name )
	local dev = assert ( openal.alcOpenDevice ( name ) , "Can't Open Device" )
	ffi.gc ( dev , function ( dev ) print("GC DEVICE") return openal.alcCloseDevice(dev) end )
	return dev
end

--Wrappers around current context functions as in ffi, equivalent pointers...aren't.
local current_context = openal.alcGetCurrentContext ( )
function openal.alcMakeContextCurrent ( ctx )
	current_context = ctx
	openal_lib.alcMakeContextCurrent ( ctx )
end

function openal.alcGetCurrentContext ( ctx )
	return current_context
end

function openal.newcontext(dev)
	local ctx = assert ( openal.alcCreateContext ( dev , nil ) , "Can't create context" )

	add_dep ( ctx , dev )

	ffi.gc ( ctx , function ( ctx )
			print("GC CONTEXT")
			if ctx == current_context then
				openal_lib.alcMakeContextCurrent ( nil )
			end
			openal.alcDestroyContext ( ctx )
		end )

	return ctx
end

function openal.getvolume ( )
	openal.alGetListenerf ( openal_defs.AL_GAIN , float )
	return float[0]
end

function openal.setvolume ( v )
	openal.alListenerf ( openal_defs.AL_GAIN , v )
end

--- OpenAL Source
local source_methods = { }
local source_mt = { __index = source_methods }
function openal.newsource()
	openal.alGenSources ( 1 , uint )
	local s = setmetatable ( { id = uint[0] } , source_mt )
	add_dep ( s , current_context )
	return s
end

source_methods.delete = function ( s )
	print("GC SOURCE")
	uint[0] = s.id
	openal.alDeleteSources ( 1 , uint )
end

source_methods.isvalid = function ( s )
	local r = openal.alIsSource ( s.id )
	if r == 1 then return true
	elseif r == 0 then return false
	else error()
	end
end

source_methods.buffers_queued = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_BUFFERS_QUEUED , int )
	return int[0]
end

source_methods.buffers_processed = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_BUFFERS_PROCESSED , int )
	return int[0]
end

source_methods.type = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_SOURCE_TYPE , int )
	return openal.sourcetypes[ int[0] ] or error("Unknown Source Type")
end

source_methods.play = function ( s )
	openal.alSourcePlay ( s.id )
end

source_methods.pause = function ( s )
	openal.alSourcePause ( s.id )
end

source_methods.state = function ( s )
	openal.alGetSourcei ( s.id , openal.AL_SOURCE_STATE , int)
	return int[0]
end

source_methods.queue = function ( s , n , buffer )
	openal.alSourceQueueBuffers ( s.id , n , buffer )
end

source_methods.unqueue = function ( s , n , buffer )
	openal.alSourceUnqueueBuffers ( s.id , n , buffer )
end

source_methods.clear = function ( s )
	local queued = s:buffers_queued()
	for i=1,queued do
		s:unqueue(s,1,uint)
	end
	return queued
end

source_methods.getvolume = function ( s )
	openal.alGetSourcef ( s.id , openal_defs.AL_GAIN , float )
	return float[0]
end

source_methods.setvolume = function ( s , v )
	openal.alSourcef ( s.id , openal_defs.AL_GAIN , v )
end

source_mt.__gc = source_methods.delete

-- OpenAL Buffers
function openal.newbuffers ( n )
	local buffers = ffi.new ( "ALuint[?]" , n )
	openal.alGenBuffers ( n , buffers )
	assert(checkforerror())
	ffi.gc ( buffers , function ( buffers )
			print("GC BUFFERS")
			return openal.alDeleteBuffers ( n , buffers )
		end )
	return buffers
end

function openal.isbuffer ( b )
	local r = openal.alIsBuffer ( b )
	if r == 1 then return true
	elseif r == 0 then return false
	else error()
	end
end

return openal
