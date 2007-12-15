require"ex"
module ( "lomp.player" , package.seeall )

fifopath = "lomp.fifo"
io.popen ( "mkfifo " .. fifopath ):close()


--extensions = { wv ,  }

--lomp.playback.goto ( 1 )
function mplayer ( command )
	if io.type ( fifo ) ~= "file" then
		local err
		fifo , err = io.open ( fifopath , "a" ) 
		if not fifo then 
			return nil,  "Could not open " .. fifofile .. ":\n" .. err 
		end
	end
	fifo:write ( command .. "\n" )
	fifo:flush ( )
	fifo:close ( )
	return true
end

function play ( path , frame )
	local r,e
	if io.type ( cmd ) == "file" then
		r , e = mplayer ( "loadfile '" .. path .. "'" )
		if r then return false end
		--mplayer ( "pt_step +" )
	else
		cmd = nil
		cmd = io.popen ( "mplayer -slave -nolirc -input file=" .. fifopath .. " '" .. path .. "'" .. " > lomp.mplayerlog" )
		if not cmd then return false end 
	end
	return true
	--rin, win = io.pipe( )
	--rout, wout = io.pipe( )
	--rerr, werr = io.pipe( )
	--cmd = os.spawn { 
	--	"mplayer" , "-input file=" .. fifopath , "-slave" , "-quiet" , "-nolirc" "'" .. path .. "'" , } --Command then arguments. 
		--stdin = rin , stdout = wout , stderr = wout }; rin:close( ) ; wout:close( ) ; --werr:close( )
end
function n ( )
	return cmd:read ( )
end
function pause ( )
	if io.type ( cmd ) ~= "file" then lomp.updatelog ( "Not playing" ) return false end
	local r , e = mplayer ( "pause" )
	if not r then return false end
	return true
end
function unpause ( )
	if io.type ( cmd ) ~= "file" then lomp.updatelog ( "Not paused" ) return false end
	mplayer ( "pause" )
end
function stop ( )
	if io.type ( cmd ) == "file" then
		mplayer ( "quit" )
	else
		
	end
	return true
end
function getstate ( )
	local stopped , paused
	if io.type ( cmd )  == file then 
		stopped = false
	else stopped = true
	end
	return stopped , paused 
	--return true
end
