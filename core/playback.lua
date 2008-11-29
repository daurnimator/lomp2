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
	
	vars.queue [ 0 ].played = true
	
	local typ = vars.queue [ 0 ].typ
	local source = vars.queue [ 0 ].source
	local offset 
	if type( fromoffset ) == "boolean" then offset = vars.queue [ 0 ].offset
	else offset = fromoffset end
	
	player.play ( typ , source , offset )
	state = "playing"
	triggers.triggercallback ( "songstarted" , typ , source )
	
	return true
end

function stop ( )
	local stopoffset 
	local typ = vars.queue [ 0 ].typ
	local source = vars.queue [ 0 ].source
	
	player.stop ( )
	state = "stopped"
	triggers.triggercallback ( "songstopped" , typ , source , stopoffset )
	
	return true
end
function pause ( )
	player.pause ( )
	state = "paused"
	
	return true
end
function unpause ( )
	player.unpause ( )
	state = "playing"
	
	return true
end

function goto ( songnum )
	stop ( )
	
	if songnum == 0 then -- Stop?
		
	elseif songnum > 0 then
		local r
		for i = 1 , songnum do
			r = forward ( )
			if not r then break end
		end
		return r
	elseif songnum < 0 then
		local r
		for i = 1 , -songnum do
			r = backward ( )
			if not r then break end
		end
		return r
	end
end

function previous ( )
	return goto ( -1 )
end

function next ( )
	return goto ( 1 )
end

function forward ( ) -- Moves forward one song in the queue
	local m -- More songs left?
	if vars.queue [ 0 ] then
		if vars.queue [ 0 ].played then
			table.insert ( vars.played , 1 , vars.queue [ 0 ] ) -- Add current to played (history)
			vars.played.revision = vars.played.revision + 1
		end
	end
	if #vars.hardqueue > 0 then -- Hard queue left
		table.remove ( vars.hardqueue , 0 ) -- Shifts all elements down
		
		vars.hardqueue.revision = vars.hardqueue.revision + 1
		m = true
	else
		if vars.queue [ 1 ] then
			vars.queue [ 0 ] = vars.queue [ 1 ]
			
			vars.ploffset = vars.ploffset + 1
			if vars.ploffset > #vars.pl [ vars.softqueuepl ] then -- No songs left
				if vars.loop then -- Restart soft queue
					vars.ploffset = 0
				else -- Stop?
					
				end
			end
			m = true
		else -- No more songs.
			m = false
		end
	end
	if state == "playing" then
		if m then 
			vars.queue [ 0 ].played = true
			player.changesong ( vars.queue [ 0 ].source ) 
		end
	else
		stop ( ) -- Stop if in non-playing state (eg, paused)
	end
	if m then return true else return false end
end
function backward ( ) -- Moves back one song from the history
	stop ( )
	if vars.played [ 1 ] then
		table.insert ( vars.queue , 0 , vars.played [ 1 ] ) -- Move most recent history to current, shifting current to hardqueue (and shifting any others up)
		table.remove ( vars.played , 1 ) -- Shifts all elements down
		vars.queue.revision = vars.queue.revision + 1
		vars.played.revision = vars.played.revision + 1
		return true
	else -- Nothing in history.
		return false
	end
end
