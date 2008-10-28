--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "ex"

require "core.triggers"

module ( "lomp.player" , package.see ( lomp ) )

extensions = {	"ogg" ,
				"flac" ,
}

function play ( source , offset )
	--cmd = io.popen ( "ogg123 " .. source )
	--rin, win = io.pipe( )
	--rout, wout = io.pipe( )
	--rerr, werr = io.pipe( )
	local null = io.open ( "/dev/null" )
	werr = null
	local cmd = { 
		"ogg123" , source , --Command then arguments. 
		stdin = rin , stdout = wout , stderr = werr 
	}
	
	if tonumber ( offset ) then table.insert ( cmd , 2 , "--skip " .. offset ) end
	
	triggers.songchanged ( )
	
	proc = os.spawn ( cmd );
	--rin:close( ) ; wout:close( ) ; werr:close( )
	_ , _ , pid = string.find ( tostring ( proc ) , "^process %((%d+)," )
	if not proc then return false end 
	return true
end

function changesong ( newsource )
	stop ( )
	play ( newsource )
end	
		
function pause ( )
	--os.execute "killall -STOP ogg123"
	if proc then
		os.execute ( "kill -STOP " .. pid )
	end
end

function unpause ( )
	--os.execute "killall -CONT ogg123"
	if proc then
		os.execute ( "kill -CONT " .. pid )
	end
end

function stop ( )
	--os.execute "killall ogg123"
	if proc then
		os.execute ( "kill " .. pid )
	end
end

function callonend ( )
	-- When file is finished playing, call this.
end

function getstate ( )
	--[[local r = rerr:read ( 3 )  -- Junk
	local r = rerr:read ( )
	rerr:read ( ) rerr:read ( 2 )-- Blank Junk
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( )
	r = r .. "\n" .. rerr:read ( 76 )
	return '"' .. r .. '"'
	--]]
end
