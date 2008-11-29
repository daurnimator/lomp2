--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- Scrobbler Plugin
 -- Sends data to last.fm, etc

-- Please fill in your last.fm login details:
 -- Your last.fm username
local user = "daurnimator"  
 -- md5sum of your last.fm password
local md5pass = "changeme"



module ( "scrobbler" , package.seeall )

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

http = require "socket.http"
url = require("socket.url")
require "md5" 

local clientid = "tst"
local clientver = "1.0"

local sessionid , nowplayingurl , submissionurl = false , false , false

-- Handshake
function handshake ( user , md5pass , count )
	count = ( count or 0 ) + 1
	if count > 4 then -- Max 3 retries
		ferror ( "Could not handshake with last.fm" , 1 )
	end
	
	local time = os.time ( )
	local authenticationtoken = md5.sumhexa ( md5pass .. time )
	local rurl = "http://post.audioscrobbler.com/?hs=true&p=1.2.1&c=" .. clientid .. "&v=" .. clientver .. "&u=" .. user .. "&t=" .. time .. "&a=" .. authenticationtoken
	
	local body , code , h = http.request ( rurl )
	if code == 200 then
		local i , j , cap = string.find ( body , "([^\n]+)" )
		if cap == "OK" then
			i , j , sessionid = string.find ( body , "([^\n]+)" , j + 2 )
			i , j , nowplayingurl = string.find ( body , "([^\n]+)" , j + 2 )
			i , j , submissionurl = string.find ( body , "([^\n]+)" , j + 2 )
			if sessionid and nowplayingurl and submissionurl then
				return cap
			else
				return ferror ( "No session id retrieved from last.fm" , 1 )
			end
		elseif cap == "BANNED" then
			return false , cap , "This Client has been banned from last.fm, please report this"
		elseif cap == "BADAUTH" then
			return false , cap , "Incorrect user/password combination"
		elseif cap == "BADTIME" then
			return false , cap , "Fix your damn clock, do you really think your time is currently " .. os.date ( "%c" , time )
		elseif string.find ( cap , "^FAILED" ) then
			-- Retry
			return handshake ( user , md5pass , count )
		end
	else -- Retry
		return handshake ( user , md5pass , count )
	end
end	

function nowplaying ( songpath )
	if not sessionid then 
		local w , cap , err = handshake ( user , md5pass )
		if not w then ferror ( "Last.fm Handshake error: " .. err , 1 ) end
	end
	
	--local songpath = lomp.vars.queue [ 0 ].source
	local songdetails = lomp.tags.getdetails ( songpath )
	
	local artistname = url.escape ( songdetails.tags [ "artist" ] )
	local trackname = url.escape ( songdetails.tags [ "title" ] )
	local album = url.escape ( songdetails.tags [ "album" ] )
	local length = url.escape ( songdetails.length or "" )
	local tracknumber = url.escape ( songdetails.tags [ "track" ] )
	local musicbrainzid = url.escape ( "" )
	
	local rbody = "s=" .. sessionid .. "&a=" .. artistname .. "&t=" .. trackname .. "&b=" .. album .. "&l=" .. length .. "&n=" .. tracknumber .. "&m=" .. musicbrainzid
	
	local body , code , h = http.request ( nowplayingurl , rbody )
	
	if code == 200 then
		local i , j , cap = string.find ( body , "([^\n]+)" )
		if cap == "OK" then
			return true
		elseif cap == "BADSESSION" then
			ferror ( "Bad last.fm session, re-handshaking" , 2 )
			sessionid = nil
			nowplaying ( )
		end
	end
end

lomp.triggers.registercallback ( "songchanged" , nowplaying , "Scrobbler Now-Playing" )
