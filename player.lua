--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local libvlc = require "vlc"


require "core.triggers"

module ( "lomp.player" , package.see ( lomp ) )

extensions = {	"ogg" ,
				"flac" ,
				"mp3" ,
				"wav" ,
}

function play ( typ , source , offset )
	updatelog ( "play" .. "\t" .. typ .. "\t" .. source  .. "\t" .. (offset or "") , 5)
	if typ == "file" then
		current.info = { typ = typ , source = source }
		current.media = current.instance:media_new ( source )
		updatelog ( "M\t" .. tostring(current.media) , 5 )
		current.media:event_manager ( ) :attach ( "MediaStateChanged" , function ( ev ) 
				if ( ev.new_state == "Ended" ) then
					local position = current.media_player:get_position ( )
					updatelog ( "Ended " .. position , 5 )
					if ( position > 0.995 ) then -- Doesn't seem to have perfect accuracy
						triggers.triggercallback ( "songfinished" , current.info.typ , current.info.source )
						core.playback.forward ( )
						updatelog ( "Forward" , 5 )
					else
						triggers.triggercallback ( "songstopped" , current.info.typ , current.info.source , position )
						updatelog ( "Just stopped" , 5 )
					end
				elseif ( ev.new_state == "Playing" ) then
					updatelog ( "Song just started Playing" , 5 )
					triggers.triggercallback ( "songplaying" , typ , source )
				else
					updatelog ( tostring(ev.obj) .. "\t" .. tostring(ev.type) .. "\t" .. tostring(ev.new_state) , 5) 
				end
			end )
		updatelog ( "N\t" .. tostring(current.media_player) , 5 )
		updatelog ( pcall ( function () current.media_player:set_media ( current.media ) end ) , 5 )
		updatelog ( "O\t" .. tostring(current.media_player) , 5 )
		
		if offset then 
			-- current.player.set_time ( offset ) -- Seconds/1000
			-- current.player.set_position ( offset ) -- Percent*100
		end
		current.media_player:play ( )
		return true
	else 
		updatelog( "TYPE IS: " .. typ , 5)
		return false , typ
	end
end

function changesong ( newtyp , newsource , newoffset )
	play ( newtyp , newsource , newoffset )
end	
		
function pause ( )
	if current.media_player:can_pause ( ) and current.media_player:is_playing ( ) then
		current.media_player:pause ( )
	end
end

function unpause ( )
	if not current.media_player:is_playing ( ) then
		current.media_player:pause ( )
	end
end

function stop ( )
	if current.media_player then
		current.media_player:stop ( )
	end
	return true
end

function getstate ( )
	
end

function setvolume ( vol )
	if type ( vol ) ~= "number" or vol < 0 or vol > 100 then
		return false
	end
	current.instance:audio_set_volume ( vol )
	return true
end

function getvolume ( )
	return current.instance:audio_get_volume ( )
end

current = { }
current.instance = libvlc.new ( )
current.media_player = current.instance:media_player_new ( )

-- Debug
function skip ( )
	current.media_player:set_position(.98)
end
