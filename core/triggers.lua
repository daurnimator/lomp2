--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

local ipairs , pcall , type , unpack = ipairs , pcall , type , unpack
local tblremove = table.remove
local coroutinewrap , coroutineyield = coroutine.wrap , coroutine.yield

module ( "lomp.core.triggers" , package.see ( lomp ) )

local callbacks = { }

function register ( callback , func , name , instant )
	local t = callbacks [ callback ]
	if not t then -- If callback doesn't exist, create it
		t = { }
		callbacks [ callback ] = t
	end
	local pos = #t + 1
	t [ pos ] = { func = func , instant = instant , name = name }
	if name then t [ name ] = pos end
	return pos
end

function unregister ( callback , id )
	local t = callbacks [ callback ]
	if not t then return ferror ( "Deregister callback called with invalid callback" , 1 ) end
	
	local pos
	if type ( id ) == "string" then
		pos = t [ id ]
		t [ id ] = nil
	elseif type ( id ) == "number" then
		pos = id
	end
	if not pos then
		return ferror ( "Deregister callback called with invalid position/name" , 1 )
	end
	
	tblremove ( t , pos )
	
	if #t == 0 then callbacks [ callback ] = nil end -- Delete callback table
	
	return true
end

local queue , qn = { } , 1 -- Qn is the next empty queue slot.
local processqueue = coroutinewrap ( function ( )
	local i = 1
	while true do
		if i < qn then
			local ok , err = pcall ( unpack ( queue [ i ] ) )
			if not ok then updatelog ( err ,  2 ) end
			queue [ i ] = nil
			i = i + 1
		else
			coroutineyield ( true )
		end
	end
end )

function fire ( callback , ... )
	local t = callbacks [ callback ]
	if t then
		for i , v in ipairs ( t ) do
			if v.instant then -- Fire instant callbacks right now
				local ok , err = pcall ( v.func , ... )
				if not ok then updatelog ( err ,  2 ) end
			else -- Otherwise add them to the trigger queue
				queue [ qn ] = { v.func , ... }
				qn = qn + 1
			end
		end
		return true
	else
		return false , "Callback does not exist"
	end
end

addstep ( processqueue )
