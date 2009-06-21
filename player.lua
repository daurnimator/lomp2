--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "lgob.gst"
require "core.triggers"

module ( "lomp.player" , package.see ( lomp ) )

extensions = {	"ogg" ,
				"flac" ,
				"mp3" ,
				"wav" ,
				"wv",
}

local pipeline = gst.ElementFactory.make ( "playbin2" , "player" )
local bus = pipeline:get_bus ( )
bus:add_signal_watch ( )

function queuesong ( typ , source )
	local uri
	if typ == "file" then
		uri = "file://" .. source
	end
	pipeline:set ( "uri" , uri )
	return true
end

function play ( typ , source , offset )
	queuesong ( typ , source )
	
	pipeline:set_state ( gst.STATE_PLAYING )
	pipeline:get_state ( -1 )
	
	if offset then seek ( offset ) end
	return true
end

function changesong ( newtyp , newsource , newoffset )	
	pipeline:set_state ( gst.STATE_READY )
	pipeline:get_state ( -1 )
	queuesong ( newtyp , newsource )
	pipeline:set_state ( gst.STATE_PLAYING )
	pipeline:get_state ( -1 )
	
	if offset then seek ( offset ) end
	return true
end

function pause ( )
	pipeline:set_state ( gst.STATE_PAUSED )
	pipeline:get_state ( -1 )
	return true
end

function unpause ( )
	pipeline:set_state ( gst.STATE_PLAYING )
	pipeline:get_state ( -1 )
	return true
end

function stop ( )
	pipeline:set_state ( gst.STATE_READY )
	pipeline:get_state ( -1 )
	return true
end

function seek ( offset , percent )
	if type ( offset ) ~= "number" then return false end
	if percent then
		if offset < 0 or offset > 100 then
			return false
		else
			local tracklength = select ( 3 , pipeline:query_duration( gst.FORMAT_TIME ) )
			offset = ( offset / 100 ) * tracklength 
			return pipeline:seek_simple ( gst.FORMAT_TIME , offset )
		end
	else
		return pipeline:seek_simple ( gst.FORMAT_TIME , offset * 1000 )
	end
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
	return pipeline:get ( "volume" ) * 100
end

bus:connect ( "message::eof" , function ( )
		--print("eof")
		--triggers.triggercallback ( "songstopped" , typ , source , offset )
	end )
	
--bus:connect ( "message::state-changed" , function ( ) print ("statechange" ) end )

pipeline:connect ( "about-to-finish" , function ( ) 
		--print("about to finish" )
		triggers.triggercallback ( "songabouttofinsh" )
	end )
