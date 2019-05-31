component {

	function init(
		required string appID
	,	required string searchKey
	,	required string adminKey
	,	string apiUrl= "https://<appid>.algolia.net;https://<appid>-1.algolianet.com;https://<appid>-2.algolianet.com;https://<appid>-3.algolianet.com"
	,	numeric httpTimeOut = 5
	,	boolean debug= ( request.debug ?: false )
	) {
		this.appID = arguments.appID;
		this.searchKey = arguments.searchKey;
		this.adminKey = arguments.adminKey;
		this.httpTimeOut = arguments.httpTimeOut;
		this.debug = arguments.debug;
		this.apiUrlPool = listToArray( replaceNoCase( arguments.apiUrl, "<appid>", this.appID, "all" ), ";" );
		this.apiUrl = this.apiUrlPool[ 1 ];
		arrayDeleteAt( this.apiUrlPool, 1 );
		this.paginationLimitedTo = 1000;
		return this;
	}

	function debugLog(required input) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "Algolia: " & arguments.input );
			} else {
				request.log( "Algolia: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="Algolia", type="information" );
		}
		return;
	}

	function mcDateFormat(required string date) {
		if ( len( arguments.date ) && isDate( arguments.date ) ) {
			arguments.date = dateConvert( "local2utc", arguments.date );
			arguments.date = dateTimeFormat( arguments.date, "yyyy-mm-dd HH:nn:ss" );
		} else {
			arguments.date = "";
		}
		return arguments.date;
	}

	function indexes() {
		var out = this.apiRequest(
			api= "GET /1/indexes"
		);
		return out;
	}

	function indexCopy(required string index, required string newIndex) {
		var json = { "operation"= "copy", "destination"= arguments.newIndex };
		var out = this.apiRequest(
			api= "POST /1/indexes/#arguments.index#/operation"
		,	json= json
		);
		return out;
	}

	function indexMove(required string index, required string newIndex) {
		var json = { "operation"= "move", "destination"= arguments.newIndex };
		var out = this.apiRequest(
			api= "POST /1/indexes/#arguments.index#/operation"
		,	json= json
		);
		return out;
	}

	function indexSettings(required string index) {
		var out = this.apiRequest(
			api= "GET /1/indexes/#arguments.index#/settings"
		);
		return out;
	}

	function indexUpdate(required string index, required struct settings) {
		var out = this.apiRequest(
			api= "PUT /1/indexes/#arguments.index#/settings"
		,	json= arguments.settings
		);
		return out;
	}

	function batch(required string index, required array batch) {
		var out = "";
		var json = { "requests"= arguments.batch };
		if ( arrayLen( arguments.batch ) ) {
			out = this.apiRequest(
				api= "POST /1/indexes/#arguments.index#/batch"
			,	json= json
			);
		} else {
			out = {
				success = true
			,	error = ""
			,	status = "no data in batch"
			,	json = json
			,	statusCode = 0
			,	response = ""
			,	verb = "POST"
			,	requestUrl = this.apiUrl & "/1/indexes/#arguments.index#/batch"
			};
		}
		return out;
	}

	array function insertObjectBatch(required array batch, required struct data) {
		arrayAppend( arguments.batch, { "action"= "addObject", "body"= arguments.data } );
		return arguments.batch;
	}

	array function upsertObjectBatch(required array batch, required struct data) {
		arrayAppend( arguments.batch, { "action"= "updateObject", "body"= arguments.data } );
		return arguments.batch;
	}

	array function updateObjectBatch(required array batch, required struct data) {
		arrayAppend( arguments.batch, { "action"= "partialUpdateObjectNoCreate", "body"= arguments.data } );
		return arguments.batch;
	}

	array function deleteObjectBatch(required array batch, required string objectID) {
		arrayAppend( arguments.batch, { "action"= "deleteObject", "body"= { "objectID"= arguments.objectID } } );
		return arguments.batch;
	}

	function upsertObject(required string index, required string objectID, required struct data) {
		var out = this.apiRequest(
			api= "PUT /1/indexes/#arguments.index#/#arguments.objectID#"
		,	json= arguments.data
		);
		return out;
	}

	function deleteObject(required string index, required string objectID) {
		var out = this.apiRequest(
			api= "DELETE /1/indexes/#arguments.index#/#arguments.objectID#"
		);
		return out;
	}

	function deleteObjects(required string index, required string objectIDs) {
		var out = "";
		var batch = [];
		var id = "";
		for ( id in arguments.objectIDs ) {
			arrayAppend( batch, { "action"= "deleteObject", "body"= { "objectID"= id } } );
		}
		out = this.batch( arguments.index, batch );
		return out;
	}

	function batchSearch(required string index, required array batch) {
		var out = "";
		var json = { "requests"= [] };
		var s = 0;
		for ( s in arguments.batch ) {
			arrayAppend( json.requests, {
				"indexName"= arguments.index
			,	"params"= replace( this.structToQueryString( s ), "?", "" )
			} );
		}
		var out = this.apiRequest(
			api= "POST /1/indexes/*/queries"
		,	json= json
		);
		return out;
	}

	function getFacets(
		required string index
	,	string query= ""
	,	string maxValuesPerFacet= ""
	,	string tagFilters= ""
	,	facetFilters= ""
	,	string numericFilters= ""
	,	string facets= "*"
	,	boolean advancedSyntax= false
	,	numeric minWordSizefor1Typo= 4
	,	numeric minWordSizefor2Typos= 8
	,	boolean allowTyposOnNumericTokens= false
	,	string removeWordsIfNoResults= "none"
	,	boolean ignorePlurals= false
	,	string queryType= "prefixLast"
	,	string typoTolerance= true
	,	string restrictSearchableAttributes= ""
	,	boolean synonyms= true
	,	string optionalWords= ""
	,	numeric minProximity= 1
	,	string verb= "GET"
	) {
		arguments.page = 0;
		arguments.hitsPerPage = 1;
		arguments.analytics = false;
		arguments.attributesToSnippet = "[]";
		arguments.attributesToHighlight = "[]";
		arguments.attributesToRetrieve = "[]";
		return this.search( argumentCollection = arguments );
	}

	function search(
		required string index
	,	string query= ""
	,	string page= ""
	,	string hitsPerPage= ""
	,	string maxValuesPerFacet= ""
	,	string tagFilters= ""
	,	facetFilters= ""
	,	string numericFilters= ""
	,	string facets= "*"
	,	string attributesToRetrieve= "*"
	,	string attributesToSnippet= ""
	,	string attributesToHighlight= "*"
	,	boolean advancedSyntax= false
	,	numeric minWordSizefor1Typo= 4
	,	numeric minWordSizefor2Typos= 8
	,	boolean allowTyposOnNumericTokens= false
	,	string removeWordsIfNoResults= "none"
	,	boolean ignorePlurals= false
	,	string queryType= "prefixLast"
	,	string typoTolerance= true
	,	string restrictSearchableAttributes= ""
	,	boolean analytics= true
	,	string analyticsTags= ""
	,	boolean synonyms= true
	,	boolean replaceSynonymsInHighlight= true
	,	string optionalWords= ""
	,	numeric minProximity= 1
	,	string verb= "GET"
	) {
		var out = "";
		var params = {};
		if ( isNumeric( arguments.page ) && arguments.page != 0 ) {
			params[ "page" ] = arguments.page;
		}
		if ( isNumeric( arguments.hitsPerPage ) ) {
			params[ "hitsPerPage" ] = arguments.hitsPerPage;
		}
		if ( len( arguments.query ) ) {
			params[ "query" ] = arguments.query;
		}
		if ( len( arguments.tagFilters ) ) {
			params[ "tagFilters" ] = arguments.tagFilters;
		}
		if ( isSimpleValue( arguments.facetFilters ) && len( arguments.facetFilters ) ) {
			params[ "facetFilters" ] = arguments.facetFilters;
		} else if ( isArray( arguments.facetFilters ) && arrayLen( arguments.facetFilters ) ) {
			params[ "facetFilters" ] = serializeJSON( arguments.facetFilters );
		}
		if ( isNumeric( arguments.maxValuesPerFacet ) ) {
			params[ "maxValuesPerFacet" ] = arguments.maxValuesPerFacet;
		}
		if ( isSimpleValue( arguments.numericFilters ) && len( arguments.numericFilters ) ) {
			params[ "numericFilters" ] = arguments.numericFilters;
		} else if ( isArray( arguments.numericFilters ) && arrayLen( arguments.numericFilters ) ) {
			params[ "numericFilters" ] = serializeJSON( arguments.numericFilters );
		}
		if ( len( arguments.facets ) ) {
			params[ "facets" ] = arguments.facets;
		}
		if ( arguments.attributesToRetrieve != "*" ) {
			params[ "attributesToRetrieve" ] = arguments.attributesToRetrieve;
		}
		if ( len( arguments.attributesToSnippet ) ) {
			params[ "attributesToSnippet" ] = arguments.attributesToSnippet;
		}
		if ( arguments.attributesToHighlight != "*" ) {
			params[ "attributesToHighlight" ] = arguments.attributesToHighlight;
		}
		if ( arguments.advancedSyntax ) {
			params[ "advancedSyntax" ] = arguments.advancedSyntax;
		}
		if ( arguments.minWordSizefor1Typo != "4" ) {
			params[ "minWordSizefor1Typo" ] = arguments.minWordSizefor1Typo;
		}
		if ( arguments.minWordSizefor2Typos != "8" ) {
			params[ "minWordSizefor2Typos" ] = arguments.minWordSizefor2Typos;
		}
		if ( arguments.allowTyposOnNumericTokens ) {
			params[ "allowTyposOnNumericTokens" ] = arguments.allowTyposOnNumericTokens;
		}
		if ( arguments.removeWordsIfNoResults != "none" ) {
			params[ "removeWordsIfNoResults" ] = arguments.removeWordsIfNoResults;
		}
		if ( arguments.ignorePlurals ) {
			params[ "ignorePlurals" ] = arguments.ignorePlurals;
		}
		if ( arguments.queryType != "prefixLast" ) {
			params[ "queryType" ] = arguments.queryType;
		}
		if ( arguments.typoTolerance != "true" ) {
			params[ "typoTolerance" ] = arguments.typoTolerance;
		}
		if ( len( arguments.restrictSearchableAttributes ) ) {
			params[ "restrictSearchableAttributes" ] = arguments.restrictSearchableAttributes;
		}
		if ( !arguments.analytics ) {
			params[ "analytics" ] = arguments.analytics;
		}
	//	if( len( arguments.analyticsTags ) ) {
	//		params[ "analyticsTags" ] = serializeJSON( listToArray( arguments.analyticsTags ) );
	//	}
		if ( !arguments.synonyms ) {
			params[ "synonyms" ] = arguments.synonyms;
		}
		if ( !arguments.replaceSynonymsInHighlight ) {
			params[ "replaceSynonymsInHighlight" ] = arguments.replaceSynonymsInHighlight;
		}
		if ( len( arguments.optionalWords ) ) {
			params[ "optionalWords" ] = arguments.optionalWords;
		}
		if ( arguments.minProximity != 1 ) {
			params[ "minProximity" ] = arguments.minProximity;
		}
		var qs = this.structToQueryString( params );
		if ( arguments.verb == "POST" ) {
			var json = { "params"= replace( qs, "?", "" ) };
			out = this.apiRequest(
				api= "POST /1/indexes/#arguments.index#/query"
			,	json= json
			);
		} else if ( arguments.verb == "GET" ) {
			out = this.apiRequest(
				api= "GET /1/indexes/#arguments.index##qs#"
			);
		}
		return out;
	}

	function browse(
		required string index
	,	string cursor= ""
	,	string query= ""
	,	string page= ""
	,	string hitsPerPage= ""
	,	string tagFilters= ""
	,	facetFilters= ""
	,	string numericFilters= ""
	,	string attributesToRetrieve= "*"
	,	string attributesToSnippet= ""
	,	string attributesToHighlight= "*"
	,	boolean advancedSyntax= false
	,	numeric minWordSizefor1Typo= 4
	,	numeric minWordSizefor2Typos= 8
	,	boolean allowTyposOnNumericTokens= false
	,	string removeWordsIfNoResults= "none"
	,	boolean ignorePlurals= false
	,	string queryType= "prefixLast"
	,	string typoTolerance= true
	,	string restrictSearchableAttributes= ""
	,	boolean analytics= true
	,	string analyticsTags= ""
	,	boolean synonyms= true
	,	boolean replaceSynonymsInHighlight= true
	,	string optionalWords= ""
	,	numeric minProximity= 1
	) {
		var out = "";
		var params = {};
		if ( len( arguments.cursor ) ) {
			params[ "cursor" ] = arguments.cursor;
		}
		if ( isNumeric( arguments.page ) && arguments.page != 0 ) {
			params[ "page" ] = arguments.page;
		}
		if ( isNumeric( arguments.hitsPerPage ) ) {
			params[ "hitsPerPage" ] = arguments.hitsPerPage;
		}
		if ( len( arguments.query ) ) {
			params[ "query" ] = arguments.query;
		}
		if ( len( arguments.tagFilters ) ) {
			params[ "tagFilters" ] = arguments.tagFilters;
		}
		if ( isSimpleValue( arguments.facetFilters ) && len( arguments.facetFilters ) ) {
			params[ "facetFilters" ] = arguments.facetFilters;
		} else if ( isArray( arguments.facetFilters ) && arrayLen( arguments.facetFilters ) ) {
			params[ "facetFilters" ] = serializeJSON( arguments.facetFilters );
		}
		if ( isSimpleValue( arguments.numericFilters ) && len( arguments.numericFilters ) ) {
			params[ "numericFilters" ] = arguments.numericFilters;
		} else if ( isArray( arguments.numericFilters ) && arrayLen( arguments.numericFilters ) ) {
			params[ "numericFilters" ] = serializeJSON( arguments.numericFilters );
		}
		if ( arguments.attributesToRetrieve != "*" ) {
			params[ "attributesToRetrieve" ] = arguments.attributesToRetrieve;
		}
		if ( len( arguments.attributesToSnippet ) ) {
			params[ "attributesToSnippet" ] = arguments.attributesToSnippet;
		}
		if ( arguments.attributesToHighlight != "*" ) {
			params[ "attributesToHighlight" ] = arguments.attributesToHighlight;
		}
		if ( arguments.advancedSyntax ) {
			params[ "advancedSyntax" ] = arguments.advancedSyntax;
		}
		if ( arguments.minWordSizefor1Typo != "4" ) {
			params[ "minWordSizefor1Typo" ] = arguments.minWordSizefor1Typo;
		}
		if ( arguments.minWordSizefor2Typos != "8" ) {
			params[ "minWordSizefor2Typos" ] = arguments.minWordSizefor2Typos;
		}
		if ( arguments.allowTyposOnNumericTokens ) {
			params[ "allowTyposOnNumericTokens" ] = arguments.allowTyposOnNumericTokens;
		}
		if ( arguments.removeWordsIfNoResults != "none" ) {
			params[ "removeWordsIfNoResults" ] = arguments.removeWordsIfNoResults;
		}
		if ( arguments.ignorePlurals ) {
			params[ "ignorePlurals" ] = arguments.ignorePlurals;
		}
		if ( arguments.queryType != "prefixLast" ) {
			params[ "queryType" ] = arguments.queryType;
		}
		if ( arguments.typoTolerance != "true" ) {
			params[ "typoTolerance" ] = arguments.typoTolerance;
		}
		if ( len( arguments.restrictSearchableAttributes ) ) {
			params[ "restrictSearchableAttributes" ] = arguments.restrictSearchableAttributes;
		}
		if ( !arguments.analytics ) {
			params[ "analytics" ] = arguments.analytics;
		}
		if ( len( arguments.analyticsTags ) ) {
			params[ "analyticsTags" ] = listToArray( arguments.analyticsTags, "|" );
		}
		if ( !arguments.synonyms ) {
			params[ "synonyms" ] = arguments.synonyms;
		}
		if ( !arguments.replaceSynonymsInHighlight ) {
			params[ "replaceSynonymsInHighlight" ] = arguments.replaceSynonymsInHighlight;
		}
		if ( len( arguments.optionalWords ) ) {
			params[ "optionalWords" ] = arguments.optionalWords;
		}
		if ( arguments.minProximity != 1 ) {
			params[ "minProximity" ] = arguments.minProximity;
		}
		var qs = this.structToQueryString( params );
		out = this.apiRequest(
			api= "GET /1/indexes/#arguments.index#/browse#qs#"
		);
		return out;
	}

	function getCursor(
		required string index
	,	string query= ""
	,	string tagFilters= ""
	,	facetFilters= ""
	,	string numericFilters= ""
	,	boolean advancedSyntax= false
	,	numeric minWordSizefor1Typo= 4
	,	numeric minWordSizefor2Typos= 8
	,	boolean allowTyposOnNumericTokens= false
	,	string removeWordsIfNoResults= "none"
	,	boolean ignorePlurals= false
	,	string queryType= "prefixLast"
	,	string typoTolerance= true
	,	string restrictSearchableAttributes= ""
	,	boolean synonyms= true
	,	string optionalWords= ""
	,	numeric minProximity= 1
	) {
		arguments.page = 0;
		structDelete( arguments, "cursor" );
		var out = this.browse( argumentCollection = arguments );
		return ( out.success ? out.response.cursor : "" );
	}

	struct function apiRequest(required string api, json= "") {
		var http = {};
		var dataKeys = 0;
		var item = "";
		var out = {
			success = false
		,	error = ""
		,	status = ""
		,	json = ""
		,	statusCode = 0
		,	response = ""
		,	verb = listFirst( arguments.api, " " )
		,	requestUrl = this.apiUrl & listRest( arguments.api, " " )
		};
		if ( isStruct( arguments.json ) ) {
			out.json = serializeJSON( arguments.json );
			out.json = reReplace( out.json, "[#chr(1)#-#chr(7)#|#chr(11)#|#chr(14)#-#chr(31)#]", "", "all" );
		} else if ( isSimpleValue( arguments.json ) && len( arguments.json ) ) {
			out.json = arguments.json;
		}
		this.debugLog( arguments );
		this.debugLog( out );
		cftimer( type="debug", label="algolia request" ) {
			cfhttp( result="http", method=out.verb, url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut ) {
				cfhttpparam( name="X-Algolia-API-Key", type="header", value=this.adminKey );
				cfhttpparam( name="X-Algolia-Application-Id", type="header", value=this.appID );
				if ( out.verb == "POST" || out.verb == "PUT" ) {
					cfhttpparam( name="Content-Type", type="header", value="application/json" );
					cfhttpparam( type="body", value=out.json );
				}
			}
		}
		this.debugLog( http );
		out.response = toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 5 ) {
			arrayAppend( this.apiUrlPool, this.apiUrl );
			this.apiUrl = this.apiUrlPool[ 1 ];
			arrayDeleteAt( this.apiUrlPool, 1 );
		}
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error = "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error = out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success = true;
		}
		//  parse response 
		if ( left( out.response, 1 ) == "{" ) {
			try {
				out.response = deserializeJSON( out.response );
				if ( isStruct( out.response ) && structKeyExists( out.response, "error" ) ) {
					out.success = false;
					out.error = out.response.error;
				} else if ( !out.success && structKeyExists( out.response, "message" ) ) {
					out.error = out.response.message;
				}
			} catch (any cfcatch) {
				out.error = "JSON Error: " & cfcatch.message;
			}
		}
		if ( len( out.error ) ) {
			out.success = false;
		}
		if ( !out.success ) {
			this.debugLog( out );
		}
		return out;
	}

	string function structToQueryString(required struct stInput, boolean bEncode= true, string lExclude= "", string sDelims= ",") {
		var sOutput = "";
		var sItem = "";
		var sValue = "";
		var amp = "?";
		for ( sItem in stInput ) {
			if ( !len( lExclude ) || !listFindNoCase( lExclude, sItem, sDelims ) ) {
				sValue = stInput[ sItem ];
				if ( !isNull( sValue ) && isSimpleValue( sValue ) ) {
					if ( bEncode ) {
						sOutput &= amp & sItem & "=" & urlEncodedFormat( sValue );
					} else {
						sOutput &= amp & sItem & "=" & sValue;
					}
					amp = "&";
				}
			}
		}
		return sOutput;
	}

	string function urlEncoded(required string url) {
		return replace( replace( urlEncodedFormat( arguments.url ), "%20", "+", "all" ), "%2E", ".", "all" );
	}

	string function stripTags(required string sInput, string sReplacement= "") {
		return replaceList( sInput, "</,<!,<,>", ",,," );
	}

	string function listRemove(required string lInput, required string sMatch, string sDelims= ",") {
		var bFound = true;
		while ( condition="bFound == true" ) {
			bFound = listFindNoCase( lInput, sMatch, sDelims );
			if ( !bFound ) {
				break;
			}
			lInput = listDeleteAt( lInput, bFound, sDelims );
		}
		return lInput;
	}

	struct function formatData(required struct data, string sCols= structKeyList( arguments.data )) {
		var sField = "";
		var stOutput = {};
		var v = 0;
		for ( sField in sCols ) {
			v = arguments.data[ sField ];
			if ( left( v, 1 ) == "|" ) {
				if ( len( v ) > 1 ) {
					stOutput[ sField ] = listToArray( v, "|" );
				}
			} else if ( len( v ) ) {
				stOutput[ sField ] = v;
			}
		}
		return stOutput;
	}

	string function hashData(required struct data, string sCols= qInput.columnList) {
		var sField = "";
		var buffer = createObject( "java", "java.lang.StringBuffer" ).init();
		var v = 0;
		for ( sField in sCols ) {
			buffer.append( arguments.data[ sField ][ nRow ] );
		}
		return hash( buffer.toString() );
	}

	struct function formatQueryData(required query qInput, numeric nRow= 1, string sCols= qInput.columnList) {
		var sField = "";
		var stOutput = {};
		var v = 0;
		for ( sField in sCols ) {
			v = qInput[ sField ][ nRow ];
			if ( left( v, 1 ) == "|" ) {
				if ( len( v ) > 1 ) {
					stOutput[ sField ] = listToArray( v, "|" );
				}
			} else if ( len( v ) ) {
				stOutput[ sField ] = v;
			}
		}
		return stOutput;
	}

	string function hashQueryData(required query qInput, numeric nRow= 1, string sCols= qInput.columnList) {
		var sField = "";
		var buffer = createObject( "java", "java.lang.StringBuffer" ).init();
		var v = 0;
		for ( sField in sCols ) {
			buffer.append( qInput[ sField ][ nRow ] );
		}
		return hash( buffer.toString() );
	}

}
