--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local pairs , pcall , require , select , tonumber , type , unpack = pairs , pcall , require , select , tonumber , type , unpack
local tblconcat = table.concat

module ( "eventserver" , package.see ( lomp ) )

local server = require "server"
local Json = require "Json"

--[[
Protocol details:

Server:
After each received phrase, the server will reply with a status code, number of return values, length of each return value, then the return values themselves (which are not seperated).

Client:
A client sends "phrases", they take the form: <PHRASE> <param_1> <param_2> <param_n>\n
  where <PHRASE> is a string in all caps.
When client connects, it should first send: LOMP <version> <client>\n
  where <version> is an integer and <client> is a string not containing \n

Supported Client Phrases:
SET <key> <val>
CMD <command> <json array of parameters>
SUBSCRIBE <event>
UNSUBSCRIBE <event>
GET <variable>

Example session: (C = client , S=server)

C: LOMP 1
( Connecting, version 1)
S: 0
( Success )
C: SET client lomp client
( Set client name to lomp client )
S: 0
( Success )
C: SUBSCRIBE loop
( Subscribe to the "loop" event )
S: 0
( Success )
S: -1 loop 6 [true]
( Event "loop" has fired, 6 character long (json) param array: is an array with true as the only element )

]]

local function packobject ( session , ... )
	local vararg = { ... }
	local vararglen = select ( "#" , ... )
	for i = 1 , vararglen do
		local var = vararg [ i ]
		if var == nil then var = Json.Null end
		vararg [ i ] = var
	end
	
	local encoded
	if session.vars.dataencoding == "json" then
		encoded = Json.Encode ( vararg )
	else
		return ferror ( "Eventserver: invalid data encoding" , 1 )
	end
	
	return #encoded , encoded
end

local versions = {
	{ -- 1
		init = function ( )
			return { version = 1 ; subscriptions = { } ; vars = { dataencoding = "json" } }
		end ;
		codes = {
			EVENT = -1 ;
			SUCCESS = 0 ;
			BAD_FORMAT = 1 ;
			INVALID_PHRASE = 2 ;
			ERROR = 3 ;
			ALREADY_SUBSCRIBED = 4 ;
		} ;
		func = function ( conn , session , ver , line )
			local phrase , params = line:match ( "^(%u+)%s*(.*)$" )
			if not phrase then
				conn.write ( ver.codes.BAD_FORMAT .. "\n" )
				return
			end
			local phrasefunc = ver.phrases [ phrase ]
			if not phrasefunc then
				conn.write ( ver.codes.INVALID_PHRASE .. "\n" )
				return
			end
			conn.write ( phrasefunc ( conn , session , ver , params ) .. "\n" )
		end ;
		phrases = {
			SET = function ( conn , session , ver , params )
				local key , val = params:match ( "^(%S+)%s*(.*)$" )
				session.vars [ key ] = tonumber ( val ) or val
				return ver.codes.SUCCESS
			end ;
			CMD = function ( conn , session , ver , params )
				local func , args = params:match ( "^(%S+)%s*(.*)$" )
				if args ~= "" then
					local ok
					ok , args = pcall ( Json.Decode , args )
					if not ok or type ( args ) ~= "table" then return ver.codes.BAD_FORMAT end
				else
					args = { }
				end
				
				local function interpret ( ok , ... )
					if not ok then return tblconcat ( { ver.codes.ERROR , packobject ( session , ... ) } , " " )
					else return tblconcat ( { ver.codes.SUCCESS , packobject ( session , ... ) } , " " ) end
				end
				return interpret ( cmd ( func , unpack ( args ) ) )
			end ;
			SUBSCRIBE = function ( conn , session , ver , params )
				local callbackname = params:match ( "^(%S+)" )
				local subs = session.subscriptions
				if subs [ callbackname ] then return ver.codes.ALREADY_SUBSCRIBED end
				local pos = core.triggers.register ( callbackname , function ( ... )
						local result = { ver.codes.EVENT , callbackname , packobject ( session , ... ) }
						conn.write ( tblconcat ( result , " " ) .. "\n")
					end , "Event Client Subscription" )
				if pos then
					subs [ callbackname ] = pos					
					return ver.codes.SUCCESS
				else
					return ver.codes.ERROR
				end
			end ;
			UNSUBSCRIBE = function ( conn , session , ver , params )
				local callbackname  = params:match ( "^(%S+)" )
				if not callbackname then return ver.codes.BAD_FORMAT end
				
				local subs = session.subscriptions
				if subs [ callbackname ] and core.triggers.unregister ( callbackname , subs [ callbackname ] ) then
					subs [ callbackname ] = nil
					return ver.codes.SUCCESS
				else
					return ver.codes.ERROR
				end
			end ;
			GET = function ( conn , session , ver , params )
				local ok , results = var ( params )
				if ok then
					return tblconcat ( { ver.codes.SUCCESS , packobject ( session , results ) } , " " )
				else
					return tblconcat ( { ver.codes.ERROR , packobject ( session , results ) } , " " )
				end
			end ;
		} ;
	} ;
}

local connections = { }

function incoming ( conn , data , err )
	if err then
		updatelog ("Eventserver Incoming: " .. ( err or "" ) , 5 )
	elseif data then
		local session = connections [ conn ]
		if not session then
			local s , e , version = data:find ( "^LOMP%s+(%d+)" )
			version = tonumber ( version )
			local ver = versions [ version ]
			if ver then
				conn.write ( ver.codes.SUCCESS .. "\n" )
				session = ver.init ( )
				connections [ conn ] = session
			else 
				updatelog ( "Client tried to connect with unsupported protocol" , 4 )
				conn.close ( )
				return
			end
		else
			local ver = versions [ session.version ]
			return ver.func ( conn , session , ver , data )
		end
	end
end

function initiate ( host , port )
	local s , err = server.addserver ( {
			incoming = incoming ;
			disconnect = function ( conn , err )
				local session = connections [ conn ]
				
				-- Delete all subscriptions
				for k , v in pairs ( session.subscriptions ) do
					core.triggers.unregister ( k , v )
				end
				
				connections [ conn ] = nil
			end ;
		} , port , host , "*l" ) 
	if s then
		updatelog ( "LOMP Event Server started; bound to '" .. host .. "', port #" .. port , 4 )
		return true
	else
		return ferror ( "Event Server could not be started: " .. err , 1 )
	end
end

initiate ( config.address , config.port )
addstep ( server.step )
