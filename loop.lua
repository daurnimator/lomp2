local setmetatable = setmetatable

local doc = require "codedoc".document

local ev = require "ev"
local ev_IO_new = ev.IO.new

do -- Add getfd function to file namespace
	local ok , posix = pcall ( require , "posix" )
	if ok then
		getmetatable ( io.stdin ).__index.getfd = posix.fileno
	else
		print ( "Unable to watch file descriptors" )
	end
end

-- Create main loop
local loop = ev.Loop.new ( )

local watch_fd
do
	-- A table that maps io watchers to their file descriptors
	local fds = setmetatable ( { } , { __mode = "kv" } )
	
	watch_fd = doc ( {
		desc = [[Adds a watcher on the file descriptor ^file^ for the actions in ^mask^ with callback ^callback^, then starts it on the main loop.]] ;
		params = {
			{ "file" , 	[[file handle]] , [[such as returned by io.open or luasocket; must have `:getfd()` method.]] } ;
			{ "mask" , 	[["read" or "write"]] } ;
			{ "callback" , 	[[function]] , [[callback is called with ( loop , ^io^ , ^file^ , event_type ).]] } ;
		} ;
		returns = {
			{ "io" , [[libev io object]] }
		} ;
	} , function ( file , mask , callback )
		local fd = file:getfd ( )
		local io = ev_IO_new ( function ( loop , io , revents )
				return callback ( loop , io , fds [ io ] , revents % 2 == 1 and "read" or revents % 4 >= 2 and "write" or revents )
			end , fd , ( mask:match("r") and ev.READ or 0 ) + ( mask:match("w") and ev.WRITE or 0 ) )
		fds [ io ] = file
		io:start ( loop )
		return io
	end )
end

return {
	loop = loop ;
	watch_fd = watch_fd ;
}
