local assert = assert

local config = config [ ... ]

local general = require "general"

local crater = require "crater"
local new_handler , new_stream = crater.new_handler , crater.new_stream

local socket = require "socket"

new_handler ( assert ( socket.bind ( config.host , config.port ) ) , function ( client )
		log ( "Client connected." )
		
		local stream = new_stream ( )
		local receive = stream.receive
		local send = function ( s ) return stream.send ( s .. "\r\n" ) end
		
		local version = assert ( receive ( "*l" ):match ( "^LOMP%s+(%d+)$" ) , "Not a LOMP client" )
		log ( "Version" , version )
		send ( "OK" )
		
		log ( "Client disconnected." )
		return "done"
	end )
