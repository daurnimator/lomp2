#!/usr/bin/env sh

# Make a lua table of errno.h error strings.
	echo '#include <errno.h>' |
	gcc -E -dM -xc - |
	lua -e 'c={} io.write("return {\n")
	for n,v in io.stdin:read("*a"):gmatch("#define%s+(E%w*)%s+(%w+)") do
		c[n]=tonumber(v) or c[v] io.write(n,"=",v,";\n")
	end
	io.write("}\n")' > errnos.lua

# ALSA
	echo '#include <alsa/asoundlib.h>' |
	gcc -E -xc - |
	grep -v "^# " >	defs_alsa.h

# SRC (libsamplerate)
	echo '#include <samplerate.h>' |
	gcc -E -xc - |
	grep -v "^# " > defs_samplerate.h

# FFMPEG
	echo '
		#include <libavutil/avutil.h>
		#include <libavcodec/avcodec.h>
		#include <libavformat/avformat.h>
	' |
	gcc -E -xc - |
	grep -v "^# " > defs_ffmpeg.h
