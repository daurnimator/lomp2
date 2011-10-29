local assert , error , type = assert , error , type
local table_concat = table.concat
local coroutine_create , coroutine_resume , coroutine_status , coroutine_yield = coroutine.create , coroutine.resume , coroutine.status , coroutine.yield

local doc = require "codedoc".document

local loop = require "loop"
local watch_fd = loop.watch_fd

local new_stream = doc ( {
	desc = [[Returns a threading socket like object]] ;
	params = { } ;
	returns = { { "table" , "has methods 'receive' and 'write'" , [[
table with write and receieve functions that yield the current coroutine.
]];
	} } ;
} , function ( )
	local data = ""
	return {
		receive = function ( format )
			return assert ( coroutine_yield ( "receive" , format ) , "socket closed" )
		end ;
		write = function ( str )
			return assert ( coroutine_yield ( "write" , str ) , "socket closed" )
		end ;
	}
end )

local new_handler = doc ( {
	desc = [[
Registers a new watcher for ^master_socket^.
^handler^ is a function that will be turned into a coroutine; it should use coroutine.yield ( "done" | true | "yield" | "write" | "receive" , extra )
]] ;
	params = {
		{ "master_socket" , "socket like object" } ;
		{ "handler" , "coroutine callback" , [[
^handler^ function is turned into a coroutine, then called with the client socket as only argument.

Yielding:
	"done" | true	closes the socket.
	"write"			does a client:send ( extra ), returns number of bytes written, or if the socket is closed: false , last byte written
	"receive"		does a client:receive ( extra ) , returns data or if the socket is closed: false , partial_read
]] } ;
	} ;
	returns = { } ;
} , function ( master_socket , handler )
	assert ( handler , "No handler function" )


	watch_fd ( master_socket , "r" , function ( loop , io , master_socket )
			local client = master_socket:accept ( )
			client:settimeout ( 0 )

			local co = coroutine_create ( handler )

			local handle_resume

			local h = function ( data , err , partial )
				if data then
					handle_resume ( coroutine_resume ( co , data ) )
				elseif err == "closed" then
					handle_resume ( coroutine_resume ( co , false , partial ) )
				elseif err == "timeout" then
				end
				return data , err , partial
			end

			handle_resume = function ( ok , need , extra )
				if not ok then
					error ( need , 3 )
				elseif need == "receive" then
					-- Have to try and read from luasocket first: only NEW events are caught by libev
					local data , err , partial_read = h ( client:receive ( extra , partial_read ) )
					if err == "timeout" then
						watch_fd ( client , "r" , function ( loop , io , client )
							data , err , partial_read = client:receive ( extra , partial_read )

							if err ~= "timeout" then
								io:stop ( loop )
							end

							h ( data , err , partial_read )
						end )
					end
				elseif need == "write" then
					local ok , err
					local partial_write = 0
					watch_fd ( client , "w" , function ( loop  , io , client )
							ok , err , partial_write = client:send ( extra , partial_write + 1 )

							if err ~= "timeout" then
								io:stop ( loop )
							end

							h ( ok , err , partial_write )
						end )
				elseif need == "done" or need == true then
					client:close ( )
				else
					error ( "Coroutine yielded incorrectly (reached end of body?)" )
				end
			end

			handle_resume ( coroutine_resume ( co , client ) )
		end )
end )

return {
	new_stream = new_stream ;
	new_handler = new_handler ;
}
