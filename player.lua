--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local require , select , type = require , select , type

module ( "lomp.player" , package.see ( lomp ) )

require "core.triggers"

local gst = require "lgob.gst"

extensions = {	
	"ogg" ; "oga" ;
	"flac" ;
	"mpeg" ; "mpg" ; "mp1" ; "mp2" ; "mp3" ; "mpa" ;
	"wav" ;
	"wv" ;
	--"m4a" ; "m4r" ;
}

local pipeline = gst.ElementFactory.make ( "playbin2" , "player" )
if not pipeline then updatelog ( "Could not create gstreamer pipeline" , 0 ) end
updatelog ( "GST version: " .. gst.version ( ) , 5 )
--local bus = pipeline:get_bus ( )
--bus:add_signal_watch ( )

function geturi ( typ , source )
	if not typ or not source then return false , "Bad argument" end
	
	if typ == "file" then
		return "file://" .. source:gsub ( "([^/A-Za-z0-9_])" , function ( c ) return ("%%%02x"):format ( c:byte ( ) ) end ) -- Escapes a file path (for uri)
	else
		return false , "Invalid file typ"
	end
end

function queuesong ( typ , source )
	local uri , err = geturi ( typ , source )
	if not uri then return ferror ( err , 1 ) end
	
	pipeline:set ( "uri" , uri )
	
	return true
end

function play ( typ , source , offset , offsetispercent )
	local uri , err = geturi ( typ , source )
	if not uri then return ferror ( err , 1 ) end
	
	local GstStateChangeReturn = pipeline:set_state ( gst.STATE_READY )
	if GstStateChangeReturn == gst.STATE_CHANGE_ASYNC then
		pipeline:get_state ( -1 )
	elseif GstStateChangeReturn == gst.STATE_CHANGE_SUCCESS then
	elseif GstStateChangeReturn == gst.STATE_CHANGE_FAILURE then
		return false
	end
	
	pipeline:set ( "uri" , uri )
	
	local GstStateChangeReturn = pipeline:set_state ( gst.STATE_PLAYING )
	if GstStateChangeReturn == gst.STATE_CHANGE_ASYNC then
		pipeline:get_state ( -1 )
	elseif GstStateChangeReturn == gst.STATE_CHANGE_SUCCESS then
	elseif GstStateChangeReturn == gst.STATE_CHANGE_FAILURE then
		return false , "Failed set_state"
	end

	if offset then
		return seek ( offset , false , offsetispercent )
	else
		return true
	end
end

function pause ( )
	if getstate ( ) ~= "playing" then return false end
	pipeline:set_state ( gst.STATE_PAUSED )
	return getstate ( )
end

function unpause ( )
	if getstate ( ) ~= "paused" then return false end
	pipeline:set_state ( gst.STATE_PLAYING )
	return getstate ( )
end

function stop ( )
	pipeline:set_state ( gst.STATE_READY )
	return getstate ( )
end

function seek ( offset , relative , percent )
	local tracklength = select ( 3 , pipeline:query_duration ( gst.FORMAT_TIME ) )
	local currentposition = select ( 3 , pipeline:query_position ( gst.FORMAT_TIME ) )
	
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
	
	--[[if GstStateChangeReturn == gst.STATE_CHANGE_FAILURE then
		return false
	--elseif GstStateChangeReturn == gst.STATE_CHANGE_SUCCESS then
	--else
		-- Timeout is infinite, we shouldn't get here.
	end--]]
	
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
		return false , "Unavailable volume level"
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
	local r , t , position = pipeline:query_position ( gst.FORMAT_TIME )
	return position / 1000 -- Convert from milliseconds to seconds
end

--[[bus:connect ( "message::eof" , function ( )
		playback.state = "stopped"
	end )

bus:connect ( "message" , function ( ... ) print ("statechange" , ... ) end )
--]]

pipeline:connect ( "about-to-finish" , function ( )
		core.triggers.fire ( "player_abouttofinish" )
	end )
