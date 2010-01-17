--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local require , select , type = require , select , type
local ostime = os.time
local tblinsert , tblremove = table.insert , table.remove

module ( "lomp.core.playback" , package.see ( lomp ) )

require "player"

state = "stopped"

function play ( fromoffset, offsetispercent )
	local currentsong = vars.currentsong
	
	if not currentsong then
		local r , err = forward ( )
		if not r then return false , err end
		currentsong = vars.currentsong
	end
	
	local typ = currentsong.typ
	local source = currentsong.source
	
	local offset 
	if type ( fromoffset ) == "boolean" then
		offset = currentsong.offset
	elseif type ( fromoffset ) == "number" then
		offset = fromoffset
	end
	
	local ok , err = player.play ( typ , source , offset , offsetispercent )
	if not ok then
		return false , "Could not start playback: " .. err
	end
	
	state = "playing"
	currentsong.laststarted = ostime ( )
	core.triggers.fire ( "playback_startsong" , typ , source )
	
	return true
end

function stop ( )
	local item = vars.currentsong
	local offset = player.getposition ( )
	
	if item then -- There shouldn't be anything playing if there is nothing in current playing slot....
		item.offset = item.baseoffset
		
		local newstate = player.stop ( )
		if newstate == "stopped" then
			if state ~= "stopped" then
				core.triggers.fire ( "playback_stop" , item.typ , item.source , offset )
			end
			state = "stopped"
			return true
		else -- Stop didn't work
			return false , "Could not stop"
		end
	else -- Nothing to stop...
		return false , "Nothing to stop"
	end
end

function pause ( )
	local item = vars.currentsong
	
	if item then
		local offset = player.getposition ( )
		item.offset = offset
		
		local ok , err = player.pause ( )
		if ok then
			state = "paused"
			core.triggers.fire ( "playback_pause" , offset )
			return true
		else
			return false , err or "Could not pause"
		end
	else
		return false , "Nothing to pause"
	end
end

function unpause ( )
	local item = vars.currentsong
	
	if item then
		local ok , err = player.unpause ( )
		if ok then
			state = "playing"
			core.triggers.fire ( "playback_unpause" )
			return true
		else
			return false , err or "Could not unpause"
		end	
	else
		return false , "Nothing to unpause"
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
			if not forward ( ) then return false , "Not enough songs" end
		end
		return true
	elseif songnum < 0 then
		for i = 1 , -songnum do
			if not select ( 2 , backward ( ) ) then return false , "Not enough songs to go back to" end
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
	local success , err
	
	local currentsong = vars.currentsong
	if currentsong then
		if currentsong.laststarted then -- Only add to played if it was actually started.
			tblinsert ( vars.played , 1 , currentsong ) -- Add current to played (history)
			vars.played.revision = vars.played.revision + 1
		end
	end
	if vars.hardqueue.length > 0 then -- Hard queue left
		currentsong = vars.hardqueue [ 1 ]
		core.item.removeitem ( vars.hardqueue , 1 )
		success = true
	else
		if core.setploffset ( vars.ploffset + 1 ) then -- Songs left in softqueue
			currentsong = vars.queue [ 1 ]
			success = true
		else
			currentsong = false
			success = false
			err = "No more songs."
		end
	end
	
	if state == "playing" then
		if success then
			local typ , source = currentsong.typ , currentsong.source 
			if queueonly then
				success , err = player.queuesong ( typ , source )
			else
				success , err = player.play ( typ , source ) 
			end
			if success then
				core.triggers.fire ( "playback_startsong" , typ , source )
			end
		end
	else
		stop ( ) -- Stop if in non-playing state (eg, paused)
	end
	
	vars.currentsong = currentsong
	
	return success , err
end

function backward ( ) -- Moves back one song from the history
	stop ( )
	local currentsong = vars.currentsong
	if currentsong then
		core.item.additem ( vars.hardqueue , 1 , currentsong )
	end
	if vars.played [ 1 ] then
		vars.currentsong = vars.played [ 1 ]
		tblremove ( vars.played , 1 ) -- Shifts all elements down
		vars.played.revision = vars.played.revision + 1
		return true
	else -- Nothing left in history.
		return false , "No played songs left"
	end
end


function seek ( offset , relative , percent )
	if type ( offset ) ~= "number" then return false , "Invalid offset" end
	local currentsong = vars.currentsong
	if not currentsong then return false , "No item" end
	
	player.seek ( offset , relative , percent )
	
	local newoffset = player.getposition ( )
	currentsong.offset = newoffset

	core.triggers.fire ( "playback_seek" , newoffset )	

	return true
end

core.triggers.register ( "player_abouttofinish" , function ( ) forward ( true ) end , "queuenextsong" , true )
