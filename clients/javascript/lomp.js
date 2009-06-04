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
	
	this.sendqueue = { get : [ ] , post : [ ] };

	var sendpost = function ( name , params , successcallback , failcallback ) {
		that.sendqueue.post.push ( { cmd : name , params : params , successcallback : successcallback , failcallback : failcallback } );
	};
	var sendget = function ( name , successcallback , failcallback ) {
		that.sendqueue.get.push ( { "var" : name , successcallback : successcallback , failcallback : failcallback } );
	};
	var processpost = function ( postqueue , aftercallback ) {
		var postbody = [ ];
		for ( var i in postqueue ) {
			var a = { };
			a.cmd = postqueue [ i ].cmd;
			a.params = postqueue [ i ] .params;
			postbody.push ( a );
		};

		$.post (  that.jsonurl , JSON.stringify ( postbody ) , function ( postdata ) {
			for ( var i = 0 ; i < postdata.length ; i++ ) {
				if ( postdata [ i ] [ 0 ] ) {
					postqueue [ i ].successcallback ( postdata [ i ] [ 1 ] );
				} else {
					postqueue [ i ].failcallback ( postdata [ i ] [ 1 ] );
				};
			};
			aftercallback ( );
		} , "json" );
	};
	var processget = function ( getqueue , aftercallback ) {
		var url = that.jsonurl+"?";
		for ( var i = 0 ; i < getqueue.length ; i++ ) {
			url += url + ( i + 1 ) + "=" + escape ( getqueue [ i ] ["var"] ) + "&";
		};
		
		$.get ( url , function ( getdata ) {
			for ( var i = 0 ; i < getdata.length ; i++ ) {
				if ( getdata [ i ] [ 0 ] ) {
					getqueue [ i ].successcallback ( getdata [ i ] [ 1 ] );
				} else {
					getqueue [ i ].failcallback ( getdata [ i ] [ 1 ] );
				};
			};
			aftercallback ( );
		} , "json" );
	};
	var processqueue = function ( ) {
		// First post
		if ( that.sendqueue.post [ 0 ] ) {
			var aftercallback = function () {};//that.refresh
			// Then GET
			if ( that.sendqueue.get [ 0 ] ) {
				aftercallback = function ( ) {
					processget ( that.sendqueue.get , aftercallback );
					that.sendqueue.get = [ ];
				}
			}
			processpost ( that.sendqueue.post , aftercallback );
			that.sendqueue.post = [ ];
		};		
	};
	
	this.getPlaylistInfo = function ( ) {
		sendpost ( "core.info.getplaylistinfo" , [ 0 ] , function ( data ) {
			that.editstate ( [ "libraryinfo" ] , data [ 0 ] );
		} ); //Library
		sendpost ( "core.info.getlistofplaylists" , [ ] , function ( data ) {
			that.editstate ( [ "playlistinfo" ] , data [ 0 ] );
		} ); //All the other playlists
	};
	this.updatePlaylist = function ( playlist ) {
		sendpost ( "core.info.getplaylist" , [ playlist + 1 ] , function ( data ) {
			that.editstate ( [ "playlists" , playlist ] , data [ 0 ] );
		} );
	};
	this.updateLibrary = function ( ) {
		sendpost ( "core.info.getplaylist" , [ 0 ] , function ( data ) {
				that.editstate ( [ "library" ] , data [ 0 ] );
		} );
	};
	
	this.refresh = function ( ) {
		// Check to see if anything has changed on the server
	
		// Update playlistinfo
		that.getPlaylistInfo ( that.state.currentplaylist );
		
		// Update library if changed
		if ( that.state.libraryinfo && that.state.libraryinfo.revision > ( ( that.state.library || { } ).revision || -1 ) ) {
			that.updateLibrary ( );
		}
		// Update changed playlists
		for (var i = 0 ; i < that.state.playlistinfo.length ; i++ ) {
			if ( that.state.playlistinfo [ i ].revision > ( ( that.state.playlists [ i ] || {} ).revision || -1 ) ) {
				that.updatePlaylist ( i );
			}
		}
		processqueue ( );
		
		console.log ( that.state );
	};
	
	// Setup refreshing
	//this.timer = setInterval ( function ( ) { that.refresh ( ); } , 2000 );
}
