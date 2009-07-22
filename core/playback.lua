--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.core.playback" , package.see ( lomp ) )

require "player"

state = "stopped"

function play ( fromoffset )
	if state ~= "stopped" then stop ( ) end -- Remove eventually??
	if not vars.queue [ 0 ] then 
		local r = forward ( ) 
		if not r then return false , "Nothing to play" end
	end
	
	local typ = vars.queue [ 0 ].typ
	local source = vars.queue [ 0 ].source
	local offset 
	if type ( fromoffset ) == "boolean" then
		offset = vars.queue [ 0 ].offset
	elseif type ( fromoffset ) == "number" then
		offset = fromoffset
	end
	
	player.play ( typ , source , offset )
	state = "playing"
	vars.queue [ 0 ].laststarted = os.time ( )
	
	triggers.triggercallback ( "playback_startsong" , typ , source )
	
	return true
end

function stop ( )
	local item = vars.queue [ 0 ]
	local offset = player.getposition ( )
	
	if item then -- There shouldn't be anything playing if there is nothing in current playing slot....
		item.offset = 0
		
		local newstate = player.stop ( )
		if newstate == "stopped" then
			if state ~= "stopped" then
				triggers.triggercallback ( "playback_stop" , item.typ , item.source , offset )
			end
			state = "stopped"
			return true
		else -- Stop didn't work
			return false
		end
	else -- Nothing to stop...
		return false
	end
end

function pause ( )
	local item = vars.queue [ 0 ]
	local offset = player.getposition ( )
	item.offset = offset
	
	if item and player.pause ( ) then
		state = "paused"
		triggers.triggercallback ( "playback_pause" , offset )
		return true
	else
		return false
	end
end

function unpause ( )
	local item = vars.queue [ 0 ]
	
	if item and player.unpause ( ) then
		state = "playing"
		triggers.triggercallback ( "playback_unpause" )
		return true
	else
		return false
	end
end

function togglepause ( )
	if state == "playing" then
		return pause ( )
	elseif state == "paused" then
		return unpause ( )
	else
		return ferror ( "Tried to toggle pause when neither playing or paused" )
	end
end

function goto ( songnum )
	stop ( )
	
	if songnum == 0 then
		return true
	elseif songnum > 0 then
		for i = 1 , songnum do
			if not forward ( ) then return false end
		end
		return true
	elseif songnum < 0 then
		for i = 1 , -songnum do
			if not select ( 2 , backward ( ) ) then return false end
		end
		return true
	end
end

function previous ( )
	return goto ( -1 )
end

function next ( )
	return goto ( 1 )
end

function forward ( queueonly ) -- Moves forward one song in the queue
	local success
	if vars.queue [ 0 ] then
		if vars.queue [ 0 ].laststarted then
			table.insert ( vars.played , 1 , vars.queue [ 0 ] ) -- Add current to played (history)
			vars.played.revision = vars.played.revision + 1
		end
	end
	if vars.hardqueue.length > 0 then -- Hard queue left
		vars.queue [ 0 ] = vars.hardqueue [ 1 ]
		core.item.removeitem ( core.playlist.getnum ( vars.hardqueue ) , 1 )
		
		success = true
	else
		if vars.queue [ 1 ] then
			vars.queue [ 0 ] = vars.queue [ 1 ]
			vars.ploffset = vars.ploffset + 1
			if vars.ploffset > vars.playlist [ vars.softqueueplaylist ].length then -- No songs left
				if vars.loop then -- Restart soft queue
					vars.ploffset = 0
				else -- Stop?
					
				end
			end
			success = true -- More songs left
		else
			success = false -- No more songs.
		end
	end
	if state == "playing" then
		if success then
			local item = vars.queue [ 0 ]
			local typ , source = item.typ , item.source 
			if queueonly then
				success = player.queuesong ( typ , source )
			else
				success = player.play ( typ , source ) 
			end
			triggers.triggercallback ( "playback_startsong" , typ , source )
		end
	else
		stop ( ) -- Stop if in non-playing state (eg, paused)
	end
	return success
end

function backward ( ) -- Moves back one song from the history
	stop ( )
	local current = vars.queue [ 0 ]
	if current then
		core.item.additem ( current , core.playlist.getnum ( vars.hardqueue ) , 1 )
	end
	if vars.played [ 1 ] then
		vars.queue [ 0 ] = vars.played [ 1 ]
		table.remove ( vars.played , 1 ) -- Shifts all elements down
		vars.played.revision = vars.played.revision + 1
		return true , true
	else -- Nothing in history.
		return true , false
	end
end


function seek ( offset , relative , percent )
	if type ( offset ) ~= "number" then return false end
	
	player.seek ( offset , relative , percent )
	
	vars.queue [ 0 ].offset = player.getposition ( )
	
	return true
end

triggers.registercallback ( "player_abouttofinish" , function ( ) forward ( true ) end , "queuenextsong" )

