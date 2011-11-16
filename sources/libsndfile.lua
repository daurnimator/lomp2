-- Source using libsndfile

local sndfile = require "libsndfile"

local function reset ( self )
	self.sf:seek ( 0 )
end

local function source ( self , dest , len )
	local n = self.sf:read_short ( dest , len )
	return n > 0 , n
end

local function position ( self )
	return tonumber ( self.sf:seek ( 0 , "cur" ) )
end

local function seek ( self , newpos )
	newpos = newpos + self.from
	self.sf:seek ( newpos , "set" )
end

local function sf_path ( path )
	local sf , info = sndfile.openpath ( path )

	local format = 	( ( info.channels == 1 and "MONO" )
				or ( info.channels == 2 and "STEREO" )
				or error ( ) ) .. "16"

	return {
		from = 0 ;
		to = tonumber ( info.frames ) ;
		sample_rate = info.samplerate ;
		format = format ;

		reset = reset ;
		source = source ;
		position = position ;
		seek = seek ;

		sf = sf ;
	}
end

return {
	path = sf_path ;
}
