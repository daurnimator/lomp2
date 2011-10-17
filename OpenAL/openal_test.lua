package.path = package.path .. ";./?/init.lua"

local ffi = require"ffi"
local openal = require"OpenAL"

local dev = openal.opendevice()
local ctx = openal.newcontext(dev)
openal.alcMakeContextCurrent(ctx)

local source = openal.newsources()

local NUM_BUFFERS = 5
local buffers = openal.newbuffers(NUM_BUFFERS)

local BUFFER_SIZE = 440*100
local frequency = 44100
local format = openal.format.MONO16;
local source_data = ffi.new("int16_t[?]",BUFFER_SIZE)
local source_len = ffi.sizeof(source_data)

--Generate sinusoidal test signal
local m = 2*math.pi/frequency*440
for i=0,BUFFER_SIZE-1 do
        source_data[i]=(2^15-1)*math.sin(m*i)
end


for i=0,NUM_BUFFERS-1 do
        openal.alBufferData(buffers[i],format,source_data,source_len,frequency)
end
assert(openal.checkforerror())

openal.alSourceQueueBuffers(source[0],NUM_BUFFERS,buffers)
openal.alSourcePlay(source[0]);
assert(openal.checkforerror())

local buffer = ffi.new("ALuint[1]")
local val = ffi.new("ALint[1]")

local progress = 0
local time = os.clock()
while true do
        openal.alGetSourcei(source[0],openal.AL_BUFFERS_PROCESSED,val)
        if val[0]>0 then
                for i=val[0],1,-1 do
                        openal.alSourceUnqueueBuffers(source[0], 1, buffer)
                        openal.alBufferData(buffer[0], format, source_data, source_len, frequency)
                        openal.alSourceQueueBuffers(source[0], 1, buffer)
						assert(openal.checkforerror())

						progress = progress + BUFFER_SIZE/frequency
						io.write(string.format("Played %f seconds @time %f\r",progress,os.clock()-time))
                end
                openal.alGetSourcei(source[0], openal.AL_SOURCE_STATE, val)
                if val[0] ~= openal.AL_PLAYING then
                        print("HERE")
                        openal.alSourcePlay(source[0])
                end
        end
end
