/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

var twiki;
if (twiki == undefined) twiki = {};

/**
twiki.AjaxRequest is a wrapper class around Yahoo's Connection Manager connection.js class: http://developer.yahoo.com/yui/connection/
*/

twiki.AjaxRequest = function () {
	
	// PRIVATE METHODS AND VARIABLES
	// MAY BE CALLED ONLY BY PRIVILEGED METHODS
	
	var self = this;

	/**
	Key-value set of Properties objects. The value is accessed by request identifier name.
	@private
	*/
	var _storage = {};
	
	var SCRIPT_NODE_ID_PREFIX = "TWIKI_ADDED_SCRIPT_";
	
	/**
	Inner property data class.
	*/
	var Properties = function(inName) {
		this.name = inName; // String
		this.url; // String
		this.response; //  Object
		this.lockedProperties = {}; // Value object of properties that cannot be changed
		this.handler = "_writeHtml"; // String
		this.scope = twiki.AjaxRequest.getInstance(); // Object
		this.container; // String; id of HTML container
		this.type = "text"; // String; possible values: "text", "xml", "script", "scriptfile"
		this.cache = false; // Boolean
		this.method = "GET"; // String
		this.postData; // String
		this.indicator; // HTML String
		this.failHandler = "_defaultFailHandler"; // String
		this.failScope = twiki.AjaxRequest.getInstance(); // Object
		//
		this.owner = twiki.AjaxRequest.getInstance(); // Object
		this.scriptNodeIds = [];
	}
	/**
	Debug string
	*/
	Properties.prototype.toString = function() {
		return "name=" + this.name
			+ "; handler=" + this.handler
			+ "; scope=" + this.scope.toString()
			+ "; container=" + this.container
			+ "; url=" + this.url
			+ "; type=" + this.type
			+ "; cache=" + this.cache
			+ "; method=" + this.method
			+ "; postData=" + this.postData
			+ "; indicator=" + this.indicator
			+ "; response=" + this.response;
	}
	
	/**
	Creates a unique id for the loading indicator.
	@private
	*/
	function _getIndicatorId (inName) {
		return "twikiRequestIndicator" + inName;
	}
	
	/**
	Wraps indicator HTML inside a div with unique id, so indicator can be removed even when it is located outside of replaceable content.
	@private
	*/
	function _wrapIndicator (inName, inHtml) {
		return "<span id=\""
			+ _getIndicatorId(inName)
			+ "\">"
			+ inHtml
			+ "<\/span>";
	}
	
	/**
	Hides (removes) the loading indicator image for request inName.
	@private
	*/
	function _hideLoadingIndicator (inName) {
		foswiki.HTML.deleteElementWithId(_getIndicatorId(inName));
	}
	
	/**
	Stores a property key-value pair. If the property is locked the value is not set.
	@param inObject (Properties) : reference to Properties object
	@param inKey (String) : name of property
	@param inValue (Object) : new value of property
	@private
	*/
	function _storeProperty (inObject, inKey, inValue) {
		if (inValue == undefined) return;
		if (inObject.lockedProperties[inKey]) return;
		inObject[inKey] = inValue;
	}

	/**
	Retrieves the response reference for a given response object.
	Compares tIds.
	@private
	*/
	function _referenceForResponse (inResponse) {
		for (var i in _storage) {
			var response = _storage[i].response;
			if (response && response.tId == inResponse.tId) {
				return _storage[i];
			}
		}
		return null;
	}
	
	/**
	Creates a new script node with id inNodeName
	@param inNodeName (String) : the id of the new script node
	@return The new script node
	*/
	function _createScriptNode (inNodeName) {
		var scriptNode = document.createElement('script');
		scriptNode.id = inNodeName;
		scriptNode.setAttribute('language', 'javascript');
		scriptNode.setAttribute('type', 'text/javascript');
		return scriptNode;
	}
	
	/**
	Dynamically adds script code to the head by first wrapping it inside a script node.
	@param inHeadNode (Node) : (required) the head dom node
	@param inNodeName (String) : (required) the id of the new node
	@param inCode (String) : (required) the script code
	@todo Safari seems to deal differently with script nodes. Shame we need an exception, perhaps there is another way.
	*/
	function _addScriptCodeToHead (inHeadNode, inNodeName, inCode) {
		var scriptNode = _createScriptNode(inNodeName);
		// if Safari:
		if (navigator && 
			navigator.vendor &&
			navigator.vendor.search(/Apple/) != -1) {
				var textNodeSafari = document.createTextNode(inCode);
				scriptNode.appendChild(textNodeSafari);
		} else {
			// if Explorer or Firefox (possibly all the rest):
			scriptNode.text = inCode;
		}
		inHeadNode.appendChild(scriptNode);
	}
	
	/**
	Adds a script source reference to the head by first wrapping it inside a script node.
	@param inHeadNode (Node) : (required) the head dom node
	@param inNodeName (String) : (required) the id of the new node
	@param inUrl (String) : (required) the url to add
	@return The script node if successfully appended to head.
	*/
	function _addScriptUrlToHead (inHeadNode, inNodeName, inUrl) {
		var scriptNode = _createScriptNode(inNodeName);
		scriptNode.setAttribute('src', inUrl);
		var success = inHeadNode.appendChild(scriptNode);
		return success;
	}
	
	/**
	Removes multiple script nodes from the head, based on stored ids in Properties.scriptNodeIds.
	@param inName (String) : (required) unique identifier for the request
	@return The cleared head node.
	*/
	function _removeScriptsFromHead (inName) {
		var headNode = document.getElementsByTagName('head').item(0);
		var ref = _storage[inName];
		if (!ref) return;
		for (var i=0; i<ref.scriptNodeIds.length; i++) {
			var id = ref.scriptNodeIds[i];
			_removeScriptFromHead(headNode, id); 
		}
		ref.scriptNodeIds = [];
		return headNode;
	}
	
	/**
	Removes a script node from the head.
	@param inHeadNode (Node) : (required) the head dom node
	@param inId (String) : (required) the unique id of the element to remove
	*/
	function _removeScriptFromHead (inHeadNode, inId) {
		var old = document.getElementById(inId);
		if (old) {
			inHeadNode.removeChild(old);
		}
	}
	
	/**
	Creates a unique script node id based on the number of elements already in Property.scriptNodeIds and the Property name.
	@param inRef (Property) : (required) reference to the Property object
	@return (String) A new unique id.
	*/
	function _createScriptNodeId (inRef) {
		var idNum = inRef.scriptNodeIds.length;
		return SCRIPT_NODE_ID_PREFIX + inRef.name + "_" + idNum;
	}
	
	// PRIVILEGED METHODS
	// MAY BE INVOKED PUBLICLY AND MAY ACCESS PRIVATE ITEMS
	
	/**
	See twiki.AjaxRequest.load
	@return The YAHOO.util.Connect.asyncRequest object.
	*/
	this._load = function (inName, inProperties) {
		
		var ref = this._storeProperties(inName, inProperties);
		if (!ref) return;
		
		// always stop loading possible previous request
		this._stop(inName);
		
		// check if this data has been retrieved before and stored
		if (ref.store) {
			if (ref.type == 'text' || ref.type == 'xml') {
				
				return this._writeHtml(ref.container, ref.store);
			}
			if (ref.type == 'script' || ref.type == 'scriptfile') {
				return null;
			}
		}
		
		// when writing a script url to the head no request is necessary
		if (ref.type == 'scriptfile') {
			var result = self._addScriptUrlToHead(ref.name, ref.url);
			if (ref.cache) {
				self._storeProcessedResponse(ref.name, result);
			}
			return null;
		}
		
		// no stored data was found, so start loading
		if (ref.scope == undefined) {
			alert("twiki.AjaxRequest._load: no scope given for function "
				+ ref.handler);
			return;
		}
		
		// get loading animation
		var indicatorHtml = null;
		if (ref.indicator != null) {
			indicatorHtml = ref.indicator;
		}
		if (indicatorHtml == null) {
			indicatorHtml = this._defaultIndicatorHtml;
		}

		var wrappedIndicator = _wrapIndicator(inName, indicatorHtml);
		foswiki.HTML.setHtmlOfElementWithId(ref.container, wrappedIndicator);

		var cache = (ref.cache != undefined) ? ref.cache : false;
		var callback = {
			success: this._handleSuccess,
			failure: this._handleFailure,
			argument:{container:ref.container, cache:ref.cache}
		};

		var method = (ref.method != undefined) ? ref.method : "GET";
		var postData = (ref.postData != undefined) ? ref.postData : "";
		var connectRequest = YAHOO.util.Connect.asyncRequest(method, ref.url, callback, postData);
		this._storeProperties(inName, {response:connectRequest});
		return connectRequest;
	}
	
	/**
	@param inName (String) : (required) unique identifier for the request
	@param inProperties (Object) : value object with the properties defined in inner class Properties
	@privileged
	*/
	this._storeProperties = function (inName, inProperties) {
		// check if object with name already exists
		// if so, update only the param values that are not null
		var ref = _storage[inName];
		if (!ref) {
			ref = new Properties(inName);
		}
		
		if (!inProperties) {
			// nothing to store, but keep reference
			_storage[inName] = ref;
			return ref;
		}

		_storeProperty(ref, "url", inProperties.url);
		_storeProperty(ref, "response", inProperties.response);
		_storeProperty(ref, "handler", inProperties.handler);
		_storeProperty(ref, "scope", inProperties.scope);
		_storeProperty(ref, "container", inProperties.container);
		_storeProperty(ref, "type", inProperties.type);
		_storeProperty(ref, "cache", inProperties.cache);
		_storeProperty(ref, "method", inProperties.method);
		_storeProperty(ref, "postData", inProperties.postData);
		_storeProperty(ref, "indicator", inProperties.indicator);
		_storeProperty(ref, "failHandler", inProperties.failHandler);
		_storeProperty(ref, "failScope", inProperties.failScope);
		
		_storage[inName] = ref;
		return ref;
	}
	
	/**
	See twiki.AjaxRequest.lockProperties
	*/
	this._lockProperties = function(inName, inPropertyList) {
		if (!inPropertyList || inPropertyList.length == 0) {
			return;
		}		
		var ref = _storage[inName];
		if (!ref) return;
		
		var i, ilen = inPropertyList.length;
		for (i=0; i<ilen; i++) {
			var property = inPropertyList[i];
			ref.lockedProperties[property] = true;
		}
	}
	
	/**
	See twiki.AjaxRequest.releaseProperties
	*/
	this._releaseProperties = function(inName, inPropertyList) {
		if (!inPropertyList || inPropertyList.length == 0) {
			return;
		}
		var ref = _storage[inName];
		if (!ref) return;
		
		var i, ilen = inPropertyList.length;
		for (i=0; i<ilen; i++) {
			var property = inPropertyList[i];
			delete ref.lockedProperties[property];
		}
	}
	
	/**
	See twiki.AjaxRequest.stop
	*/
	this._stop = function (inName) {
		_hideLoadingIndicator(inName);
		var ref = _storage[inName];		
		if (!ref) return;
		if (ref.response) YAHOO.util.Connect.abort(ref.response);
	}

	/**
	@privileged
	*/
	this._handleSuccess = function(inResponse) {
		if (inResponse.responseText !== undefined) {
			var ref = _referenceForResponse(inResponse);
			_hideLoadingIndicator(ref.name);
			var result;
			var text = (ref.type == 'xml') ? inResponse.responseXML : inResponse.responseText;
			if (ref.type == 'script') {
				result = self._addScriptToHead(ref.name, text);
			} else {
				result = ref.scope[ref.handler].apply(ref.scope, [ref.container, text]);
			}
			if (ref.cache) {
				self._storeProcessedResponse(ref.name, result);
			}
		}	
	}
	
	/**
	@privileged
	*/
	this._handleFailure = function(inResponse) {
		var ref = _referenceForResponse(inResponse);
		if (!ref) return;
		ref.owner._stop(ref.name);
		var result = ref.failScope[ref.failHandler].apply(ref.failScope, [ref.name, inResponse.status]);
	}
	
	/**
	@privileged
	*/
	this._defaultFailHandler = function(inName, inStatus) {
		alert("Could not load request for "
			+ inName
			+ " because of (error status): "
			+ inStatus);
	}
	
	/**
	Dynamically adds a script src reference to head in the format:
	<pre>
	<script type="text/javascript" src="myScriptUrl.js"></script>
	</pre>
	@param inName (String) : (required) unique identifier for the request
	@param inUrl (String) : (required) url of the script; in the example above <code>myScriptUrl.js</code>
	@return 1 if successfully added, 0 if not
	*/
	this._addScriptUrlToHead = function (inName, inUrl) {
		var headNode = _removeScriptsFromHead(inName);
		var ref = _storage[inName];
		if (!ref) return;
		
		var id = _createScriptNodeId(ref);
		var success = _addScriptUrlToHead(headNode, id, inUrl);
		if (success) {
			ref.scriptNodeIds.push(id);
			return 1;
		}
		return 0;
	}
	
	/**
	Adds dynamically loaded script (code/code with tags/file reference) to the head.
	@param inName (String) : (required) unique identifier for the request
	@param inCode : (required) Script code to add. These formats are possible:
	Just the code:
	<pre>
	function showAlert () {
		alert("Hello"));
	}
	</pre>
	
	Or the code surrounded by <code><script></script></code> tags:
	<pre>
	<script language="javascript">
	// <![CDATA[
	function showAlert () {
		alert("Hello");
	}
	showAlert();
	// ]]>
	</script>
	</pre>
	
	Or a mixture of code and source urls:
	<pre>
	<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/foswiki.js"></script>
	<script language="javascript">
	// <![CDATA[
	function showAlert () {
		alert("Hello");
	}
	showAlert();
	// ]]>
	</script>
	</pre>
	
	Note that all code is converted to a single line. Single line comments may make the code no longer work.
	
	@return The script text.
	@todo Use the multiline js code as is; do not convert to single line
	@todo Better handling of return values
	*/
	this._addScriptToHead = function (inName, inCode) {
		var headNode = _removeScriptsFromHead(inName);
		var ref = _storage[inName];
		if (!ref) return;	
		
		// use the input text stripped from newlines
		// remove newlines and spaces at start and end
		var cleanedCode = inCode;
		cleanedCode = cleanedCode.replace(new RegExp("^\\s*|\\s*$"), "");
		
		// I am not sure why I cannot use script including newlines in the regex
		// below (see codeRegex)
		// for now I will strip any newlines
		// so make sure that CDATA tags with single line out-comments //
		// are converted to multiline out-comments
		
		// replace // <![CDATA[ with /* <![CDATA[ */
		cleanedCode = cleanedCode.replace(new RegExp("\/\/\\s*\<\!\\[CDATA\\[", "gmi"), "/* <![CDATA[ */");
		// replace // ]]> with /* ]]> */
		cleanedCode = cleanedCode.replace(new RegExp("\/\/\\s*\]\]\>", "gmi"), "/* ]]> */");
		
		// replace newlines in the middle with ;
		cleanedCode = cleanedCode.replace(new RegExp( "\\n|\\r", "g"), ";");
		
		// find script urls
		var urlRegex = new RegExp("\<script.*?src\\s*\=\\s*\"(.*?)\"\>.*?\<\/script\>", "gmi");

		var result;
		var hasUrls = 0;
		while((result = urlRegex.exec(cleanedCode)) != null) {
			var url = result[1];
			if (url) {
				var id = _createScriptNodeId(ref);
				_addScriptUrlToHead(headNode, id, url);
				ref.scriptNodeIds.push(id);
				hasUrls = 1;
			}
		}
		// strip text from script urls
		cleanedCode = cleanedCode.replace(urlRegex, "");
		if (cleanedCode.length == 0 && hasUrls) {
			return 1;
		}
		
		// find the code (not urls)
		var codeRegex = new RegExp("\<script.*?\>\\s*(.*?)\\s*\<\/script\>", "gmi");
		var hasCode = 0;
		while((result = codeRegex.exec(cleanedCode)) != null) {
			var scriptCode = result[1];
			if (scriptCode.length > 0) {
				var id = _createScriptNodeId(ref);
				_addScriptCodeToHead(headNode, id, scriptCode);
				ref.scriptNodeIds.push(id);
				hasCode = 1;
			}
		}
		if (!hasCode) {
			// add all input text to head
			var id = _createScriptNodeId(ref);
			_addScriptCodeToHead(headNode, id, cleanedCode);
			ref.scriptNodeIds.push(id);
		}
		return 1;
	}
	
	/**
	Stores HTML block inHtml for request name inName so it can be retrieved at a later time (to fetch the stored HTML pass parameter cache as true).
	@param inName (String) : (required) unique identifier for the request
	@param inProcessed (Object) : HTML or script to store with this request
	@public
	*/
	this._storeProcessedResponse = function(inName, inProcessed) {
		var ref = _storage[inName];
		if (!ref) return;
		ref.store = inProcessed;
	}
	
	this._clearCache = function(inName) {
		var ref = _storage[inName];
		if (!ref) return;
		this._storeProcessedResponse(inName, null);
		if (ref.type == 'script' || ref.type == 'scriptfile') {
			_removeScriptsFromHead(inName);
		}
	}

	/**
	@privileged
	*/
	this._writeHtml = function(inContainer, inHtml) {
		var element = foswiki.HTML.setHtmlOfElementWithId(inContainer, inHtml);
		return foswiki.HTML.getHtmlOfElementWithId(inContainer);
	}
	
	this._defaultIndicatorHtml = "<img src='indicator.gif' alt='' />"; // for local testing, as a static url makes no sense for TWiki
	
	/**
	See twiki.AjaxRequest.setDefaultIndicatorHtml
	*/
	this._setDefaultIndicatorHtml = function (inHtml) {
		if (!inHtml) return;
		this._defaultIndicatorHtml = inHtml;
	}

}

// CLASS INSTANCE

twiki.AjaxRequest.__instance__ = null; //define the static property
twiki.AjaxRequest.getInstance = function () {
	if (this.__instance__ == null) {
		this.__instance__ = new twiki.AjaxRequest();
	}
	return this.__instance__;
}

// PUBLIC STATIC MEMBERS

/**
Sets one or more properties of a request.
@param inName (String) : (required) unique identifier for the request
@param inProperties (Object) : (optional) properties to store with this request:
	handler (String) : Name of function to proces response data. Note: a handler must always be given a scope! To clear a previously defined handler, pass an empty string.
	scope (Object) : owner of handler
	container (String) : id of HTML element to load content into
	url (String) : url to fetch HTML from
	type (String) : "text" (default) the fetched response will be returned as text; "xml": return as XML; "script": the script (code, or code with surrounding tags) will be added to the head; "scriptfile": the file reference will be added to the head and loaded automatically
	cache (Boolean) : if true, the fetched response text will be cached for subsequent retrieval; default false
	method (String) : either "GET" or "POST"; default "GET"
	postData (String) : data to send
	indicator (String) : loading indicator - HTML that will be displayed while retrieving data; if empty, getDefaultIndicatorHtml() is used
Required properties to load a request:
	if no handler is given (_writeHtml will be used): url, container
	if a handler is given: handler, scope, url
@public static
*/
twiki.AjaxRequest.setProperties = function(inName, inProperties) {
	twiki.AjaxRequest.getInstance()._storeProperties(inName, inProperties);
}

/**
Adds properties to the list of locked properties. Locked properties cannot be changed unless they are freed using twiki.AjaxRequest.releaseProperties.
@param inName (String) : (required) unique identifier for the request
@param ... : (required) comma-separated list of properties to lock
@public static
*/
twiki.AjaxRequest.lockProperties = function(inName) {
	var properties = twiki.Array.convertArgumentsToArray(arguments, 1);
	if (!properties) return;
	twiki.AjaxRequest.getInstance()._lockProperties(inName, properties);
}

/**
Frees properties from the list of locked properties. Freed/unlocked properties can be changed.
@param inName (String) : (required) unique identifier for the request
@param ... : (required) comma-separated list of properties to release
@public static
*/
twiki.AjaxRequest.releaseProperties = function(inName, inPropertyList) {
	var properties = twiki.Array.convertArgumentsToArray(arguments, 1);
	if (!properties) return;
	twiki.AjaxRequest.getInstance()._releaseProperties(inName, properties);
}

/**
Removes the cached response text, if any.
@public static
*/
twiki.AjaxRequest.clearCache = function(inName) {
	twiki.AjaxRequest.getInstance()._clearCache(inName);
}

/**
Convenience method to directly load the HTML contents of inUrl into HTML element with id inContainer.
@param inName (String) : (required) unique identifier for the request
@param inProperties (Object) : (optional) properties to store with this request:
	url (String) : (can be used instead of inUrl) url to fetch HTML from
	cache (Boolean) : if true, the fetched response text will be cached for subsequent retrieval; default false
	method (String) : either "GET" or "POST"; default "GET"
	postData (String) : data to send
	indicator (String) : loading indicator - HTML that will be displayed while retrieving data; if empty, twiki.AjaxRequest.defaultIndicatorHtml is used
@return The new connection request.
@public static
*/
twiki.AjaxRequest.load = function(inName, inProperties) {
	return twiki.AjaxRequest.getInstance()._load(inName, inProperties);
}

/**
Aborts loading of request with name inName.
@param inName (String) : (required) unique identifier for the request
@public static
*/
twiki.AjaxRequest.stop = function(inName) {
	twiki.AjaxRequest.getInstance()._stop();
}

/**
The default indicator HTML string.
@public static
*/
twiki.AjaxRequest.getDefaultIndicatorHtml = function() {
	return twiki.AjaxRequest.getInstance()._defaultIndicatorHtml;
}

/**
Sets the default indicator HTML string.
@param inHtml (String) : HTML string for the loading indicator
@public static
*/
twiki.AjaxRequest.setDefaultIndicatorHtml = function(inHtml) {
	return twiki.AjaxRequest.getInstance()._setDefaultIndicatorHtml(inHtml);
}
