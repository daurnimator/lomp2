require"general"
require"player"

module ( "lomp" , package.seeall )
playback = { state = "stopped" }
--[[
state
	typ = paused, stopped, playing, finished (nothing more to play)

entry
	progress = frame#
	
	
	totalframes = vars.queue[0].metadata.totalframes
	percentage = prog/totalframes	
	
--]]
function playback.updatestate ( )
	local a,b,c,d = player.getstate ( )
	if a then playback.state = "stopped" 
	elseif b then playback.state = "paused"
	elseif c then
	end
	return true 
end

function playback.play ( )
	if not vars.queue[0] then 
		playback.queuenxt ( ) 
		playback.play ( )
	else
		if playback.state == "paused" then
			playback.unpause ( )
		else
			--[[if playback.state == "playing" then
				player.stop ( )
			end--]]
			local w , err = player.play ( vars.queue[0].source )
			if err then
				updatelog ( err )
				playback.state = "stopped" 
			else 
				updatelog ( "Started Playback of " .. vars.queue[0].source )
				playback.updatestate ( )
			end
		end
	end
	return true
end
function playback.queuenxt ( frompos )
	-- If there is a song in the current slot, add it to play history.
	if vars.queue[0] then
		table.insert ( vars.played , 1 , vars.queue[0] )
	end
	
	-- If trying to play current song again:
	if frompos == 0 then 
		-- Play Again
		playback.play ( )
		--Leave this function
		return 
	end
	
	local frompos
	if not frompos then
		if vars.queue.gap == 1 then
			-- If frompos is not give, and we only have the softqueue; play the song at ploffset
			frompos = vars.queue.ploffset + 1 -- + vars.queue.gap
			
			-- If offset is more than number of songs in queue:
			if vars.queue.ploffset >= ( #( vars.queue ) - 1 ) then
				-- If we are looping the softqueue:
				if vars.rpt then
					-- reduce by the length of the soft playlist until we have a track.
					while vars.queue.ploffset >= ( #( vars.queue ) - 1 ) do
						vars.queue.ploffset = vars.queue.ploffset - ( #( vars.queue ) - 1 )
					end
				else -- Else, there is no next song
					playback.state = "finished"
				end
			end
		else	
			-- If frompos is not given, and we have hard queue left; play the next song in the hard queue
			frompos = frompos or 1
		end
	end
	
	-- Set current song to one in position "frompos"
	vars.queue[0] = vars.queue[frompos]
	
	--[[-- If going to play from soft queue: set ploffset
	if vars.queue.gap == 1 then
		vars.queue.ploffset = frompos - vars.queue.gap
		--frompos = vars.queue.gap + vars.queue.ploffset
	end--]]
	
	-- Cleanup (what to do with the thing that was frompos)
	-- If going to play from the HARD queue:
	if frompos < vars.queue.gap then
		-- Remove it (shifting down all others)
		table.remove ( vars.queue , frompos )
		vars.queue.gap = vars.queue.gap - 1
	-- else, if song is in soft queue
	else
		-- Next Song will be
		vars.queue.ploffset = vars.queue.ploffset + 1
		
	end
	return true
end
function playback.queueprv ( )
	table.insert ( vars.queue , 0 , vars.played[1] )
	vars.queue.gap = vars.queue.gap + 1
	table.remove ( vars.played , 1 )
	return true
end
function playback.goto ( qp , play )
	if playback.state == "playing" then
		player.stop ( )
	end
	if qp < 0 then 
		for i = 1  , -qp , 1 do 
			playback.queueprv ( )
			--vars.queue[i].progress = 0
		end
	else
		for i = 1 , qp , 1 do 
			playback.queuenxt ( )
		end	
	end
	if play ~= false and playback.state ~= "finished" then playback.play ( ) end
	return true
end
function playback.nxt ( )
	--[[if vars.shuffle then 
		if AFTER GAP then playback.queuenxt ( math.random ( 1 , vars.queue.gap ) ) 
	end--]]
	playback.goto ( 1 )
	return true
end
function playback.prv ( )
	playback.goto ( -1 )
	return true
end
function playback.pause ( )
	if playback.state == "playing" then
		player.pause ( )
		playback.state = "paused"
	else
		player.unpause ( )
		playback.state = "playing" 
	end
	return true
end
function playback.stop ( )
	if playback.state == "playing" or playback.state == "paused" then
		player.stop( )
		
		playback.state = "stopped" 
		table.insert ( vars.queue , 0 , nil )
	end
	return true
end
