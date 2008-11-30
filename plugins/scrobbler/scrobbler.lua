--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dir = dir -- Grab vars needed

-- Scrobbler Plugin
 -- Sends data to last.fm, etc

module ( "scrobbler" , package.seeall )

_NAME = "Last.fm Audio Scrobbler"
_VERSION = 0.1

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.

http = require "socket.http"
url = require("socket.url")
require "md5" 

loadfile ( dir .. "config.lua" ) ( ) -- Load config

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

function nowplaying ( typ , songpath )
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
	local musicbrainzid = ""
	
	local rbody = "s=" .. sessionid .. "&a=" .. artistname .. "&t=" .. trackname .. "&b=" .. album .. "&l=" .. length .. "&n=" .. tracknumber .. "&m=" .. musicbrainzid
	
	local body , code , h = http.request ( nowplayingurl , rbody )

	if code == 200 then
		local i , j , cap = string.find ( body , "([^\n]+)" )
		if cap == "OK" then
			return true
		elseif cap == "BADSESSION" then
			ferror ( "Bad last.fm session, re-handshaking" , 2 )
			sessionid = nil
			nowplaying ( songpath )
		end
	end
end

lomp.triggers.registercallback ( "songstarted" , nowplaying , "Scrobbler Now-Playing" )

submissionsqueue = { }
function submissions ( )
	if not sessionid then 
		local w , cap , err = handshake ( user , md5pass )
		if not w then return ferror ( "Last.fm Handshake error: " .. err , 1 ) end
	end
	if not submissionsqueue [ 1 ] then return true , "Nothing to submit" end
	
	local rbody = "s=" .. sessionid
	
	for i , v in ipairs ( submissionsqueue ) do
		rbody = rbody .. "&a[" .. i .. "]=" .. v.artist
		rbody = rbody .. "&t[" .. i .. "]=" .. v.title
		rbody = rbody .. "&i[" .. i .. "]=" .. v.starttime
		rbody = rbody .. "&o[" .. i .. "]=" .. v.source
		rbody = rbody .. "&r[" .. i .. "]=" .. v.rating
		rbody = rbody .. "&l[" .. i .. "]=" .. v.length
		rbody = rbody .. "&b[" .. i .. "]=" .. v.album
		rbody = rbody .. "&n[" .. i .. "]=" .. v.tracknumber
		rbody = rbody .. "&m[" .. i .. "]=" .. v.musicbrainz

	end
	
	local body , code , h = http.request ( submissionurl , rbody )
	
	if code == 200 then
		local i , j , cap = string.find ( body , "([^\n]+)" )
		if cap == "OK" then
			-- Remove tracks from submit queue
			submissionsqueue = { }
			return true
		elseif cap == "BADSESSION" then
			ferror ( "Bad last.fm session, re-handshaking" , 2 )
			sessionid = nil
			submissions ( )
		elseif string.find ( cap , "^FAILED" ) then
		end
	end
end
function addtosubmissions ( typ , source )
	local d = lomp.tags.getdetails ( source )
	if d.length <= 30 then return false end -- Has to be > 30 seconds in length to submit
	local t = { }
	t.artist = url.escape ( d.tags [ "artist" ] )
	t.title = url.escape ( d.tags [ "title" ] )
	t.starttime = os.time ( )
	if typ == "file" then t.source = "P" elseif typ == "stream" then t.source "R" else t.source = "P" end
	t.rating = "" -- Should check track rating and maybe give "L" ....
	t.length = url.escape ( d.length or "" )
	t.album = url.escape ( d.tags [ "album" ] )
	t.tracknumber = url.escape ( d.tags [ "track" ] )
	t.musicbrainz = ""
	table.insert ( submissionsqueue , t )
end
lomp.triggers.registercallback ( "songstarted" , addtosubmissions , "Scrobbler Add Song To Submit Queue" )
lomp.triggers.registercallback ( "songstopped" , function ( typ , source , stopoffset ) if stopoffset > 240 or ( stopoffset / lomp.tags.getdetails ( source ).length ) > 0.5 then submissions ( ) else table.remove ( submissionsqueue ) end end , "Scrobbler Submissions" )

return _NAME , _VERSION
