function LOMP ( server ) {
	var that = this // Need for private functions.
	
	this.server = server;
	this.jsonurl = "/JSON";
	this.state = new Object ( );
	this.state.playlistinfo = new Array ( );
	this.state.playlists = [ ];
	
	var send = function ( object , callback ) {
		$.post (  that.jsonurl , JSON.stringify ( object ) , callback , "json" );
	}
	
	this.getPlaylistInfo = function ( ) {
		var cmd = { cmd : [ 
			{ cmd : "core.info.getplaylistinfo" , params : [ 0 ] }, //Library
			{ cmd : "core.info.getlistofplaylists" , params : [ ] }, //All the other playlists
		] };
		send ( cmd , function ( data ) {
			if ( data [ 0 ] [ 0 ] ) {
				that.state.libraryinfo = data [ 0 ] [ 1 ] [ 0 ];
			};
			if ( data [ 1 ] [ 0 ] ) {
				that.state.playlistinfo = data [ 1 ] [ 1 ] [ 0 ];
			};
		} );
	};
	this.updatePlaylist = function ( playlist ) {
		var cmd = { cmd : [ 
			{ cmd : "core.info.getplaylist" , params : [ playlist + 1 ] },
		] };
		send ( cmd , function ( data ) {
			if ( data [ 0 ] [ 0 ] ) {
				that.state.playlists [ playlist ] = data [ 0 ] [ 1 ] [ 0 ]
			};
		} );
	};
	this.updateLibrary = function ( ) {
		var cmd = { cmd : [ 
			{ cmd : "core.info.getplaylist" , params : [ 0 ] },
		] };
		send ( cmd , function ( data ) {
			if ( data [ 0 ] [ 0 ] ) {
				that.state.library = data [ 0 ] [ 1 ] [ 0 ]
			};
		} );
	};
	
	this.refresh = function ( ) {
		// Check to see if anything has changed on the server
	
		// Update playlistinfo
		this.getPlaylistInfo ( this.state.currentplaylist );
		
		// Update library if changed
		if ( this.state.libraryinfo && this.state.libraryinfo.revision > ( ( this.state.library || { } ).revision || 0 ) ) {
			this.updateLibrary ( );
		}
		// Update changed playlists
		for (var i = 0 ; i < this.state.playlistinfo.length ; i++ ) {
			if ( this.state.playlistinfo [ i ].revision > ( ( this.state.playlists [ i ] || {} ).revision || 0 ) ) {
				this.updatePlaylist ( i );
			}
		}
		
		console.log ( this.state );
	};
	
	// Set up things for first time.
	this.updateLibrary ( );
	
	// Setup refreshing
	this.timer = setInterval ( function ( ) { that.refresh ( ); } , 2000 );
}
