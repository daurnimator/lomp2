require"general"

module ( "lomp" , package.seeall )

require"player"

playback = { state = "stopped" }

function playback.play ( )
	if not vars.queue [ 0 ] then 
		local r = playback.forward ( ) 
		if not r then return false end
	end
	
	local source = vars.queue [ 0 ].source
	local offset = vars.queue [ 0 ].offset
	
	player.play ( source , offset )
	playback.state = "playing"
end

function playback.stop ( )
	player.stop ( )
	playback.state = "stopped"
end
function playback.pause ( )
	player.pause ( )
	playback.state = "paused"
end
function playback.unpause ( )
	player.unpause ( )
	playback.state = "playing"
end

function playback.goto ( songnum )
	if songnum > 0 then
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
		vars.played.rev = vars.played.rev + 1
	end
	if #vars.queue > 0 then -- Hard queue left
		table.remove ( vars.queue , 0 ) -- Shifts all elements down
		vars.queue.rev = vars.queue.rev + 1
		return true
	else
		if vars.queue [ 1 + vars.ploffset ] == nil and vars.loop then 
			ploffset = 0 -- If at end of soft queue, go back to start (of soft queue).
		end
		if vars.queue [ 1 + vars.ploffset ] ~= nil then -- Only soft queue left
			vars.queue [ 0 ] = vars.queue [ vars.ploffset + 1 ]
			vars.ploffset = vars.ploffset + 1
		
			vars.queue.rev = vars.queue.rev + 1
			return true
		else -- No songs left
			return false
		end
	end
end
function playback.backward ( ) -- Moves back one song from the history
	playback.stop ( )
	if vars.played [ 1 ] then
		table.insert ( vars.queue , 0 , vars.played [ 1 ] ) -- Move most recent history to current, shifting current to hardqueue (and shifting any others up)
		table.remove ( vars.played , 1 ) -- Shifts all elements down
		vars.queue.rev = vars.queue.rev + 1
		vars.played.rev = vars.played.rev + 1
		return true
	else -- Nothing in history.
		return false
	end
end
