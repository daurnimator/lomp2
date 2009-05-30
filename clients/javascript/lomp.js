function LOMP ( server ) {
	this.server = server;
	this.jsonurl = "http://" + this.server + "/JSON";
	this.state = new Object ( );
	this.refreshes = 0;
	
	this.getListOfPlaylists = function ( playlist ) {
		$.post (  this.jsonurl , '{ "cmd" : [ { "cmd" : "core.info.getlistofplaylists" , "params" : [] } ] }' , function ( data ) { 
			var ret = eval ( data ) [ 0 ]
			if ( ret [ 0 ] ) {
				console.log ( ret [ 1 ] [ 0 ])
			};
		}, "json" );
	};
	
	this.refresh = function ( ) {
		// Check to see if anything has changed on the server
	
	
		// Update list of playlists
		this.getListOfPlaylists ( this.state.currentplaylist );
		
	};
	// Setup refreshing
	var obj = this
	this.timer = setInterval ( function ( ) { obj.refresh ( ); } , 2000 );
}
