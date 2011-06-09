#!/usr/bin/env sh
echo "#include <alsa/asoundlib.h>" | gcc -E -xc - | grep -v "^# " > alsa.h
echo "#include <errno.h>" | gcc -E -dM -xc - | lua -e 'c={} io.write("return {")
	for n,v in io.stdin:read("*a"):gmatch("#define%s+(%a%w*)%s+(%w+)") do
		c[n]=tonumber(v) or c[v] io.write(n,"=",v,";\n")
	end
	io.write("}\n")' > errnos.lua
