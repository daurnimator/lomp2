--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "core.triggers"

module ( "lomp.player" , package.see ( lomp ) )

extensions = {	
	"ogg" ; "oga" ;
	"flac" ;
	"mpeg" ; "mpg" ; "mp1" ; "mp2" ; "mp3" ; "mpa" ;
	"wav" ;
	"wv" ;
	--"m4a" ; "m4r" ;
}

require "lgob.gst"

local pipeline = gst.ElementFactory.make ( "playbin2" , "player" )
local bus = pipeline:get_bus ( )
bus:add_signal_watch ( )

function queuesong ( typ , source )
	if not typ or not source then return false end
	local uri
	if typ == "file" then
		uri = "file://" .. source
	end
	pipeline:set ( "uri" , uri )
	return true
end

function play ( typ , source , offset )
	if not typ or not source then return false end
	
	pipeline:set_state ( gst.STATE_READY )
	pipeline:get_state ( -1 )
	
	queuesong ( typ , source )
	
	pipeline:set_state ( gst.STATE_PLAYING )
	pipeline:get_state ( -1 )
	
	if offset then seek ( offset ) end
	return true
end

function pause ( )
	if getstate ( ) ~= "playing" then return false end
	pipeline:set_state ( gst.STATE_PAUSED )
	pipeline:get_state ( -1 )
	return true
end

function unpause ( )
	if getstate ( ) ~= "paused" then return false end
	pipeline:set_state ( gst.STATE_PLAYING )
	pipeline:get_state ( -1 )
	return true
end

function stop ( )
	pipeline:set_state ( gst.STATE_READY )
	pipeline:get_state ( -1 )
	return true
end

function seek ( offset , relative , percent )
	local tracklength = select ( 3 , pipeline:query_duration( gst.FORMAT_TIME ) )
	local currentposition = select ( 3 , pipeline:query_position( gst.FORMAT_TIME ) )
	
	if percent then
		offset = ( offset / 100 ) * tracklength 
	else
		offset = offset * 1000 -- Convert from seconds to milliseconds
	end
	
	if relative then
		offset = currentposition + offset
	end
	
	if offset > tracklength or offset < 0 then return false end
	
	return pipeline:seek_simple ( gst.FORMAT_TIME , offset )
end

function getstate ( )
	local GstStateChangeReturn , state , pendingstate = pipeline:get_state ( -1 )
	if state == gst.STATE_NULL then
	elseif state == gst.STATE_READY then
		return "stopped"
	elseif state == gst.STATE_PAUSED then
		return "paused"
	elseif state == gst.STATE_PLAYING then
		return "playing"
	end
end

function setvolume ( vol )
	if type ( vol ) ~= "number" or vol < 0 or vol > 1000 then
		return false
	end
	pipeline:set ( "volume" , vol/100 )
	return true , ( vol > 100 ) -- If vol is over 100, distortion is likely
end

function mute ( )
	pipeline:set ( "mute" , true )
	return true
end

function unmute ( )
	pipeline:set ( "mute" , false )
	return true
end

function getvolume ( )
	return pipeline:get ( "volume" ) * 100 , pipeline:get ( "mute" )
end

function getposition ( )
	local r , t , position = pipeline:query_position( gst.FORMAT_TIME )
	return position / 1000 -- Convert from milliseconds to seconds
end

bus:connect ( "message::eof" , function ( )
		playback.state = "stopped"
	end )

bus:connect ( "message" , function ( ... ) print ("statechange" , ... ) end )

pipeline:connect ( "about-to-finish" , function ( )
		updatelog ( "About to finish song" , 5 )
		triggers.triggercallback ( "player_abouttofinish" )
	end )
