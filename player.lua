require"ex"
module ( "lomp.player" , package.seeall )

extensions = {	"ogg" ,
				"flac" ,
}

function play ( source , offset )
	os.execute ( "xmms2 clear" )
	os.execute ( "xmms2 add '" .. source .. "'")
	os.execute ( "xmms2 play" )
	return true
end


		
		
function pause ( )
	os.execute ( "xmms2 pause" )
	return true
end

function unpause ( )
	os.execute ( "xmms2 play" )
	return true
end

function stop ( )
	os.execute ( "xmms2 stop" )
	return true
end

function getstate ( )
	
end
