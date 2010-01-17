--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dir = dir -- Grab vars needed
local lomp = lomp

local updatelog , ferror = lomp.updatelog , lomp.ferror

local assert , ipairs , pairs , require = assert , ipairs , pairs , require

module ( "mpris" )

_NAME = "Lomp MPRIS Plugin"
_VERSION = "0.1"

local enabled = true
local name = "org.mpris.lompa"

local ldbus = require "ldbus"
local memassert = function ( cond ) return assert ( cond , "Out of Memory" ) end

local conn

--[[
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					
					return reply
--]]	

local function packmetadata ( iter , tags )
	local arrayiter = ldbus.message.iter.new ( )
	local dictiter = ldbus.message.iter.new ( )
	local variantiter = ldbus.message.iter.new ( )
	
	memassert ( iter:open_container ( arrayiter , ldbus.types.array , "{sv}" ) )
	for k , v in pairs ( tags ) do
		for i , vv in ipairs ( v ) do
			memassert ( arrayiter:open_container ( dictiter , ldbus.types.dict_entry ) )
				memassert ( dictiter:append_basic ( k , ldbus.types.string ) )
				memassert ( dictiter:open_container ( variantiter , ldbus.types.variant , ldbus.types.string ) )
					memassert ( variantiter:append_basic ( vv , ldbus.types.string ) )
				memassert ( dictiter:close_container ( variantiter ) )
			memassert ( arrayiter:close_container ( dictiter ) )
		end
	end
	memassert ( iter:close_container ( arrayiter ) )
end

local method_calls = {
	{
		[ "org.freedesktop.MediaPlayer" ] = {
			Identify = function ( msg )
				local reply = memassert ( msg:new_method_return ( ) )
				local ret = ldbus.message.iter.new ( )
				reply:iter_init_append ( ret )
				memassert ( ret:append_basic ( _NAME .. " " .. _VERSION ) )
				return reply
			end ;
			Quit = function ( msg )
				lomp.core.quit ( )
				return memassert ( msg:new_method_return ( ) )
			end ;
			MprisVersion = function ( msg )
				local reply = memassert ( msg:new_method_return ( ) )
				local ret = ldbus.message.iter.new ( )
				reply:iter_init_append ( ret )
				local childiter = ldbus.message.iter.new ( )
				memassert ( ret:open_container ( childiter , ldbus.types.struct ) )
					memassert ( childiter:append_basic ( 1 , ldbus.types.uint16 ) )
					memassert ( childiter:append_basic ( 0 , ldbus.types.uint16 ) )
				memassert ( ret:close_container ( childiter ) )
				return reply
			end ;
		};
	};
	TrackList = {
		{
			[ "org.freedesktop.MediaPlayer" ] = {
				GetMetadata = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local pos = assert ( req:get_basic ( ) )
					
					local item = lomp.vars.queue [ pos ]
					--if not item then return msg:newerror ( 
					local details , err = lomp.metadata.getdetails ( item.typ , item.source )
					-- if not details then return msg:newerror ( 
					
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					packmetadata ( ret , details.tags )
					return reply
				end ;
				GetCurrentTrack = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic ( lomp.vars.ploffset , ldbus.types.int32 ) )
					return reply
				end ;
				GetLength = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic ( lomp.vars.queue.length , ldbus.types.int32 ) )
					return reply
				end ;
				--[[AddTrack = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local uri = assert ( req:get_basic ( ) )
					local play = assert ( req:get_basic ( ) )
					
					local ok
					
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic ( ok , ldbus.types.int32 ) )
					return reply
				end ;
				DelTrack = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local pos = assert ( req:get_basic ( ) )
					
					
					
					return memassert ( msg:new_method_return ( ) )
				end ;--]]
				SetLoop = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local loop = assert ( req:get_basic ( ) )
					
					local ok , err = lomp.core.setloop ( loop )
					--if not ok then return msg:newerror ( 
					
					return memassert ( msg:new_method_return ( ) )
				end ;
				--[[SetRandom = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local random = assert ( req:get_basic ( ) )
					
					
					
					return memassert ( msg:new_method_return ( ) )
				end ;--]]
			};
		};
	} ;
	Player = {
		{
			[ "org.freedesktop.MediaPlayer" ] = {
				Next = function ( msg )
					lomp.core.playback.forward ( )
					return memassert ( msg:new_method_return ( ) )
				end ;
				Prev = function ( msg )
					lomp.core.playback.backward ( )
					return memassert ( msg:new_method_return ( ) )
				end ;
				Pause = function ( msg )
					lomp.core.playback.togglepause  ( )
					return memassert ( msg:new_method_return ( ) )
				end ;
				Stop = function ( msg )
					lomp.core.playback.stop ( )
					return memassert ( msg:new_method_return ( ) )
				end ;
				Play = function ( msg )
					lomp.core.playback.play ( )
					return memassert ( msg:new_method_return ( ) )
				end ;
				--[[Repeat = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local repeat = assert ( req:get_basic ( ) )
					
					
					
					return memassert ( msg:new_method_return ( ) )
				end ;--]]
				GetStatus = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					local structiter = ldbus.message.iter.new ( )
					memassert ( ret:open_container ( structiter , ldbus.types.struct ) )
					memassert ( ret:append_basic ( ( { playing = 0 ; paused = 1 ; stopped = 2 } ) [ lomp.core.playback.state ] , ldbus.types.int32 ) )
					memassert ( ret:append_basic ( 0 , ldbus.types.int32 ) )
					memassert ( ret:append_basic ( 0 , ldbus.types.int32 ) )
					memassert ( ret:append_basic ( lomp.vars.loop , ldbus.types.int32 ) )
					memassert ( ret:close_container ( structiter ) )
					return reply
				end ;
				GetMetadata = function ( msg )
					local item = lomp.vars.currentsong
					--if not item then return msg:newerror ( 
					local details , err = lomp.metadata.getdetails ( item.typ , item.source )
					-- if not details then return msg:newerror ( 
					
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					packmetadata ( ret , details.tags )
					return reply
				end ;
				--[[GetCaps = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic (  , ldbus.types.int32 ) )
					return reply
				end ;--]]
				VolumeSet = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local vol = assert ( req:get_basic ( ) )
					
					local ok , err = lomp.player.setvolume ( vol )
					--if not ok then return msg:newerror ( 
					
					return memassert ( msg:new_method_return ( ) )
				end ;
				VolumeGet = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic ( lomp.player.getvolume ( ) , ldbus.types.int32 ) )
					return reply
				end ;
				PositionSet = function ( msg )
					local req = ldbus.message.iter.new ( )
					assert ( msg:iter_init ( req ) , "No arguments" )
					local offset = assert ( req:get_basic ( ) )
					
					local ok , err = lomp.player.seek ( offset / 1000 , false , false )
					--if not ok then return msg:newerror ( 
					
					return memassert ( msg:new_method_return ( ) )
				end ;
				PositionGet = function ( msg )
					local reply = memassert ( msg:new_method_return ( ) )
					local ret = ldbus.message.iter.new ( )
					reply:iter_init_append ( ret )
					memassert ( ret:append_basic ( lomp.player.getposition ( ) * 1000 , ldbus.types.int32 ) )
					return reply
				end ;
			};
		};
	};
}

local function process_method_call ( msg , object_tree )
	local path = assert ( msg:get_path_decomposed ( ) )
	local object = object_tree
	for i = 1 , #path do
		object = object [ path [ i ] ]
		if not object then return msg:new_error ( ldbus.errors.UnknownObject ) end
	end
	local supported_interfaces = object [ 1 ]
	
	local interface = msg:get_interface ( )
	local supported_methods = supported_interfaces [ interface ]
	if not supported_methods then return msg:new_error ( ldbus.errors.UnknownInterface ) end
	
	local method = msg:get_member ( )
	local func = supported_methods [ method ]
	if not func then return msg:new_error ( ldbus.errors.UnknownMethod ) end
	
	return func ( msg )
end

local function step ( )
	if not conn:read_write ( 0 ) then return false end
	
	local msg = conn:pop_message ( )
	if msg then
		local msgtype = msg:get_type ( )
		updatelog ( "MPRIS: Got dbus " .. msgtype .. ": sender=" .. msg:get_sender ( ) .. " path=" .. msg:get_path ( ) .. " interface=" .. msg:get_interface ( ) .. " member=" .. msg:get_member ( ) , 5 )
		if msgtype == "method_call" then
			local reply = process_method_call ( msg , method_calls )
			if not reply then reply = msg:new_error ( ldbus.errors.NoReply , error_message ) end
			conn:send ( reply )
			conn:flush ( )
		elseif msgtype == "signal" then
		end
	end
	
	if not enabled then conn = nil end
	
	return enabled
end

function enable ( )
	conn = assert ( ldbus.bus.get ( "session" ) )
	local DBUS_REQUEST_NAME_REPLY = assert ( ldbus.bus.request_name ( conn , name , { replace_existing = true } ) )
	updatelog ( "MPRIS: request_name reply: " .. DBUS_REQUEST_NAME_REPLY , 5 )
	lomp.addstep ( step )
end

function disable ( )
	enabled = false
end

if enabled then
	enable ( )
end

return _NAME , _VERSION
