function LOMP ( server ) {
	var that = this // Need for private functions.
	
	this.server = server;
	this.jsonurl = "/JSON";
	
	var statecallbacks = { children : { } , callbacks : [ ] };
	this.addcallback = function ( onfield , func ) {
		var field = statecallbacks;
		for ( var i = 0  ; i < ( onfield.length - 1 ) ; i++ ) {
			var notexist
			if ( typeof field [ onfield [ i + 1 ] ] == "number" ) { notexist = { children : [ ] , callbacks : [ ] }; }
			else { notexist = { children : { } , callbacks : [ ] }; };
			
			field.children [ onfield [ i ] ] = field.children [ onfield [ i ] ] || notexist;
			field = field.children [ onfield [ i ] ];
		};
		field.callbacks.push ( func );
	};
	var docallbacks = function ( callbacktable , onfield , data ) {
		for ( var i = 0 ; i < callbacktable.length ; i++ ) {
			callbacktable [ i ] ( data );
		};
	}
	
	var processcallbacks = function ( onfield , data ) {
		var field = statecallbacks;
		docallbacks ( field.callbacks , onfield , data );
		for ( var i = 0  ; i < ( onfield.length - 1 ) ; i++ ) {
			if ( ! field.children [ onfield [ i ] ] ) { break; };
			field = field.children [ onfield [ i ] ];
			docallbacks ( field.callbacks , onfield , data );
		};
		//docallbacks ( field.callbacks , onfield , data );
	}
	
	this.state = { };
	this.state.playlistinfo = [ ];
	this.state.playlists = [ ];
	
	this.editstate = function ( onfield , data ) {
		var field = this.state;
		for ( var i = 0  ; i < ( onfield.length - 1 ) ; i++ ) {
			var notexist
			if ( typeof field [ onfield [ i + 1 ] ] == "number" ) { notexist = [ ]; }
			else { notexist = { }; };
			
			field [ onfield [ i ] ] = field [ onfield [ i ] ] || notexist;
			field = field [ onfield [ i ] ];
		};
		var subfield = onfield [ onfield.length - 1 ];
		field [ subfield ] = data;
		//console.log(subfield , data)
		processcallbacks ( onfield , data ); 
	};
	
	this.sendqueue = { };

	var send = function ( object , callback ) {
		for ( var k in object ) {
			if ( that.sendqueue [ k ] ) {
				for ( var i = 0 ; i < object [ k ].length ; i++ ) {
					that.sendqueue [ k ].push ( object [ k ] [ i ] );
				};
			} else {
				that.sendqueue [ k ] = object [ k ];
			};
		};
	};
	var processqueue = function ( ) {
		var sendqueue = that.sendqueue;
		that.sendqueue = { };
		
		var tobesent = { };
		for ( var k in sendqueue ) {
			if ( !tobesent [ k ] ) tobesent [ k ] = [ ];
			for ( var i in sendqueue [ k ] ) {
				var a = { };
				a [ k ] = sendqueue [ k ] [ i ] [ k ];
				a.params = sendqueue [ k ] [ i ] .params;
				tobesent [ k ].push ( a );
			};
		};
		
		tobesent = JSON.stringify ( tobesent );
		
		$.post (  that.jsonurl , tobesent , function ( data ) {
			for ( var i = 0 ; i < data.length ; i++ ) {
				if ( data [ i ] [ 0 ] ) {
					sendqueue.cmd [ i ].successcallback ( data [ i ] [ 1 ] ); // Only cmd is supported for now
				} else {
					console.log ( "FAILED" , data [ i ] [ 1 ] )
					sendqueue.cmd [ i ].failcallback ( data [ i ] [ 1 ] );
				};
			};
			//that.refresh();
		} , "json" );
	};
	
	this.getPlaylistInfo = function ( ) {
		send ( { cmd : [ 
			{ cmd : "core.info.getplaylistinfo" , params : [ 0 ] , successcallback : function ( data ) {
				that.editstate ( [ "libraryinfo" ] , data [ 0 ] );
			} }, //Library
			{ cmd : "core.info.getlistofplaylists" , params : [ ] , successcallback : function ( data ) {
				that.editstate ( [ "playlistinfo" ] , data [ 0 ] );
			} }, //All the other playlists
		] } );
	};
	this.updatePlaylist = function ( playlist ) {
		send ( { cmd : [ 
			{ cmd : "core.info.getplaylist" , params : [ playlist + 1 ] , successcallback : function ( data ) {
				that.editstate ( [ "playlists" , playlist ] , data [ 0 ] );
			} }
		] } );
	};
	this.updateLibrary = function ( ) {
		send ( { cmd : [ 
			{ cmd : "core.info.getplaylist" , params : [ 0 ] , successcallback : function ( data ) {
				that.editstate ( [ "library" ] , data [ 0 ] );
			} }
		] } );
	};
	
	this.refresh = function ( ) {
		// Check to see if anything has changed on the server
	
		// Update playlistinfo
		this.getPlaylistInfo ( this.state.currentplaylist );
		
		// Update library if changed
		if ( this.state.libraryinfo && this.state.libraryinfo.revision > ( ( this.state.library || { } ).revision || -1 ) ) {
			this.updateLibrary ( );
		}
		// Update changed playlists
		for (var i = 0 ; i < this.state.playlistinfo.length ; i++ ) {
			if ( this.state.playlistinfo [ i ].revision > ( ( this.state.playlists [ i ] || {} ).revision || -1 ) ) {
				this.updatePlaylist ( i );
			}
		}
		processqueue ( );
		
		console.log ( this.state );
	};
	
	// Setup refreshing
	//this.timer = setInterval ( function ( ) { that.refresh ( ); } , 2000 );
}
