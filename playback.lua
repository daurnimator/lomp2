require "general"

module ( "lomp" , package.seeall )

require "player"

playback = { state = "stopped" }

function playback.play ( )
	if state ~= "stopped" then playback.stop ( ) end -- Remove eventually??
	if not vars.queue [ 0 ] then 
		local r = playback.forward ( ) 
		if not r then return false end
	end
	
	local source = vars.queue [ 0 ].source
	local offset = vars.queue [ 0 ].offset
	
	player.play ( source , offset )
	playback.state = "playing"
	
	return true
end

function playback.stop ( )
	player.stop ( )
	playback.state = "stopped"
	
	return true
end
function playback.pause ( )
	player.pause ( )
	playback.state = "paused"
	
	return true
end
function playback.unpause ( )
	player.unpause ( )
	playback.state = "playing"
	
	return true
end

function playback.goto ( songnum )
	if songnum == 0 then -- Stop?
		
	elseif songnum > 0 then
		for i = 1 , songnum do
			local r = playback.forward ( )
			if not r then break end
		end
		return true
	elseif songnum < 0 then
		for i = 1 , -songnum do
			local r = playback.backward ( )
			if not r then break end
		end
		return true
	end
end

function playback.prv ( )
	return playback.goto ( -1 )
end

function playback.nxt ( )
	return playback.goto ( 1 )
end

function playback.forward ( ) -- Moves forward one song in the queue
	playback.stop ( )
	if vars.queue[0] then
		table.insert ( vars.played , 1 , vars.queue [ 0 ] ) -- Add current to played (history)
		vars.played.revision = vars.played.revision + 1
	end
	if #vars.queue > 0 then -- Hard queue left
		table.remove ( vars.queue , 0 ) -- Shifts all elements down
		
		vars.queue.revision = vars.queue.revision + 1
		return true
	else
		vars.queue [ 0 ] = vars.queue [ 1 ]
		
		vars.ploffset = vars.ploffset + 1
		if vars.ploffset > #vars.pl [ vars.softqueuepl ] then -- No songs left
			if vars.loop then -- Restart soft queue
				vars.ploffset = 0
			else -- Stop?
				
			end
		end
	end
end
function playback.backward ( ) -- Moves back one song from the history
	playback.stop ( )
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