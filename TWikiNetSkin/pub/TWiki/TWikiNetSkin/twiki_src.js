// TWiki namespace
var twiki;
if (!twiki) twiki = {};

twiki.getMetaTag = function(inKey) {
    if (twiki.metaTags == null || twiki.metaTags.length == 0) {
        // Do this the brute-force way because of the problem
        // seen sporadically on Bugs web where the DOM appears complete, but
        // the META tags are not all found by getElementsByTagName
        var head = document.getElementsByTagName("META");
        head = head[0].parentNode.childNodes;
        twiki.metaTags = new Array();
        for (var i = 0; i < head.length; i++) {
            if (head[i].tagName != null &&
                head[i].tagName.toUpperCase() == 'META') {
                twiki.metaTags[head[i].name] = head[i].content;
            }
        }
    }
    return twiki.metaTags[inKey]; 
};

// Get all elements under root that have the given tag and include the
// given class
twiki.getElementsByClassName = function(root, tag, className) {
	var elms = root.getElementsByTagName(tag);
	className = className.replace(/\-/g, "\\-");
	var re = new RegExp("\\b" + className + "\\b");
	var el;
	var hits = new Array();
	for (var i = 0; i < elms.length; i++) {
		el = elms[i];
		if (re.test(el.className)) {
			hits.push(el);
		}
	}
	return hits;
}

twiki.Window = {
	
	POPUP_WINDOW_WIDTH : 600,
	POPUP_WINDOW_HEIGHT : 480,
	POPUP_ATTRIBUTES : "titlebar=0,resizable,scrollbars",
	
	/**
	Launch a fixed-size help window.
	@param inUrl : (required) URL String of new window
	@param inOptions : (optional) value object with keys:
		web : (String) name of Web
		topic : (String) name of topic; will be window name unless specified in 'name'
		skin : (String) name of skin
		template : (String) name of template
		cover : (String) name of cover
		section : (String) name of section
		urlparams : (String) additional url params to pass to the window
		name : (String) name of window; may be set if 'topic' has not been set
		width : (String) width of new window; overrides default value POPUP_WINDOW_WIDTH
		height : (String) height of new window; overrides default value POPUP_WINDOW_HEIGHT
		attributes : (String) additional window attributes; overrides default value POPUP_ATTRIBUTES. Each attribute/value pair is separated by a comma. Example attributes string: "width=500,height=400,resizable=1,scrollbars=1,status=1,toolbar=1"
	@param inAltWindow : (Window) Window where url is loaded into if no pop-up could be created. The original window contents is replaced with the passed url (plus optionally web, topic, skin path)
	@use
	<pre>
	var window = twiki.Window.openPopup(
		"%SCRIPTURL{view}%/",
			{
    			topic:"WebChanges",
    			web:"%SYSTEMWEB%"
    		}
    	);
	</pre>
	@return The new Window object.
	*/
	openPopup:function (inUrl, inOptions, inAltWindow) {
		if (!inUrl) return null;
		
		var paramsString = "";
		var name = "";
		var pathString = inUrl;
		var windowAttributes = [];
		
		// set default values, may be overridden below
		var width = twiki.Window.POPUP_WINDOW_WIDTH;
		var height = twiki.Window.POPUP_WINDOW_HEIGHT;
		var attributes = twiki.Window.POPUP_ATTRIBUTES;
		
		if (inOptions) {
			var pathElements = [];
			if (inOptions.web != undefined) pathElements.push(inOptions.web);
			if (inOptions.topic != undefined) {				
				pathElements.push(inOptions.topic);
			}
			pathString += pathElements.join("/");
			
			var params = [];
			if (inOptions.skin != undefined) {
				params.push("skin=" + inOptions.skin);
			}
			if (inOptions.template != undefined) {
				params.push("template=" + inOptions.template);
			}
			if (inOptions.section != undefined) {
				params.push("section=" + inOptions.section);
			}
			if (inOptions.cover != undefined) {
				params.push("cover=" + inOptions.cover);
			}
			if (inOptions.urlparams != undefined) {
				params.push(inOptions.urlparams);
			}
			paramsString = params.join(";");
			if (paramsString.length > 0) {
				// add query string
				paramsString = "?" + paramsString;
			}			
			if (inOptions.topic != undefined) {
				name = inOptions.topic;
			}
			if (inOptions.name != undefined) {
				name = inOptions.name;
			}
			
			if (inOptions.width != undefined) width = inOptions.width;
			if (inOptions.height != undefined) height = inOptions.height;
			if (inOptions.attributes != undefined) attributes = inOptions.attributes;
		}
	
		windowAttributes.push("width=" + width);
		windowAttributes.push("height=" + height);

		windowAttributes.push(attributes);
		var attributesString = windowAttributes.join(",");
		var url = pathString + paramsString;
		
		var window = open(url, name, attributesString);
		if (window) {
			window.focus();
			return window;
		}
		// no window opened
		if (inAltWindow && inAltWindow.document) {
			inAltWindow.document.location.href = pathString;
		}
		return null;
	}
}

// Unfortunate global function required because so many translated
// strings use it
function launchWindow(inWeb, inTopic) {
    var scripturlpath = twiki.getMetaTag('SCRIPTURLPATH');
    var scriptsuffix = twiki.getMetaTag('SCRIPTSUFFIX');
    twiki.Window.openPopup(scripturlpath+'/view'+
                           scriptsuffix+'/',
                           { web:inWeb, topic:inTopic,
                                   template:"viewplain" } );
    return false;
}

twiki.Event = {

	/**
	Chain a new load handler onto the existing handler chain
	Original code: http://simon.incutio.com/archive/2004/05/26/addLoadEvent
	Modified for TWiki
	@param inFunction : (Function) function to add
	@param inDoPrepend : (Boolean) if true: adds the function to the head of the handler list; otherwise it will be added to the end (executed last)
	*/
	addLoadEvent:function (inFunction, inDoPrepend) {
		if (typeof(inFunction) != "function") {
			return;
		}
		var oldonload = window.onload;
		if (typeof window.onload != 'function') {
			window.onload = function() {
				inFunction();
			};
		} else {
			var prependFunc = function() {
				inFunction(); oldonload();
			};
			var appendFunc = function() {
				oldonload(); inFunction();
			};
			window.onload = inDoPrepend ? prependFunc : appendFunc;
		}
	}
	
};

/**
HTML utility functions.
*/
twiki.HTML = {

	/**
	Writes HTML to an HTMLElement.
	@param inId : (String) id of element to write to
	@param inHtml : (String) HTML to write
	@return The updated HTMLElement
	*/
	setHtmlOfElementWithId:function(inId, inHtml) {
		var elem = document.getElementById(inId);
		return twiki.HTML.setHtmlOfElement(elem, inHtml);
	},
	
	/**
	Writes HTML to HTMLElement el.
	@param el : (HTMLElement) element to write to
	@param inHtml : (String) HTML to write
	@return The updated HTMLElement
	*/
	setHtmlOfElement:function(el, inHtml) {
		if (!el || inHtml == undefined) return null;
		el.innerHTML = inHtml;
		return el;
	},
	
	/**
	Returns the HTML contents of element with id inId.
	@param inId : (String) id of element to get contents of
	@return HTLM contents string.
	*/
	getHtmlOfElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.getHtmlOfElement(elem);
	},
	
	/**
	Returns the HTML contents of element el.
	@param el : (HTMLElement) element to get contents of
	@return HTLM contents string.
	*/
	getHtmlOfElement:function(el) {
		if (!el) return null;
		return el.innerHTML;
	},
	
	/**
	Clears the contents of element inId.
	@param inId : (String) id of element to clear the contents of
	@return The cleared HTMLElement.
	*/
	clearElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.clearElement(elem);
	},
	
	/**
	Clears the contents of element el.
	@param el (HTMLElement) : object to clear
	*/
	clearElement:function(el) {
		if (!el) return null;
		twiki.HTML.setHtmlOfElement(el, "");
		return el;
	},
	
	/**
	untested
	*/
	deleteElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.deleteElement(elem);
	},
	
	/**
	untested
	*/
	deleteElement:function(el) {
		if (!el) return null;
		el.parentNode.removeChild(el);
		return el;
	},
	
	/**
	Inserts a new HTMLElement after an existing element.
	@param el : (HTMLElement) (required) the element to insert after
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	@use
	<pre>
	twiki.HTML.insertAfterElement(
    		document.getElementById('title'),
    		'div',
    		'<strong>not published</strong>',
    		{
    			"style":
    				{
    					"backgroundColor":"#f00",
    					"color":"#fff"
    				}
    		}
    	);
    </pre>
	*/
	insertAfterElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.appendChild(newElement);
			return newElement;
		}
		return null;
	},
	
	/**
	Inserts a new HTMLElement before an existing element.
	@param el : (HTMLElement) (required) the element to insert before
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	*/
	insertBeforeElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.parentNode.insertBefore(newElement, el);
			return newElement;
		}
		return null;
	},
	
	/**
	Replaces an existing HTMLElement with a new element.
	@param el : (HTMLElement) (required) the existing element to replace
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	*/
	replaceElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.parentNode.replaceChild(newElement, el);
			return newElement;
		}
		return null;
	},
	
	/**
	Creates a new HTMLElement. See insertAfterElement, insertBeforeElement and replaceElement.
	@return The new HTMLElement
	@priviliged
	*/
	_createElementWithTypeAndContents:function(inType, inHtmlContents, inAttributes) {
		var newElement = document.createElement(inType);
		if (inHtmlContents != undefined) {
			newElement.innerHTML = inHtmlContents;
		}
		if (inAttributes != undefined) {
			twiki.HTML.setElementAttributes(newElement, inAttributes);
		}
		return newElement;
	},

	/**
	Passes attributes from value object inAttributes to all nodes in NodeList inNodeList.
	@param inNodeList : (NodeList) nodes to set the style of
	@param inAttributes : (Object) value object with element properties, with stringified keys. For example, use "class":"twikiSmall" to set the class. This cannot be a property key written as <code>class</code> because this is a reserved keyword.
	@use
	In this example all NodeList elements get assigend a class and style:
	<pre>
	var elem = document.getElementById("my_div");
	var nodeList = elem.getElementsByTagName('ul')
	var attributes = {
		"class":"twikiSmall twikiGrayText",
    	"style":
    		{
    			"fontSize":"20px",
    			"backgroundColor":"#444",
    			"borderLeft":"5px solid red",
				"margin":"0 0 1em 0"
    		}
    	};
	twiki.HTML.setNodeAttributesInList(nodeList, attributes);
	</pre>
	*/
	setNodeAttributesInList:function (inNodeList, inAttributes) {
		if (!inNodeList) return;
		var i, ilen = inNodeList.length;
		for (i=0; i<ilen; ++i) {
			var elem = inNodeList[i];
			twiki.HTML.setElementAttributes(elem, inAttributes);
		}
	},
	
	/**
	Sets attributes to an HTMLElement.
	@param el : (HTMLElement) element to set attributes to
	@param inAttributes : (Object) value object with attributes
	*/
	setElementAttributes:function (el, inAttributes) {
		for (var attr in inAttributes) {
			if (attr == "style") {
				var styleObject = inAttributes[attr];
				for (var style in styleObject) {
					el.style[style] = styleObject[style];
				}
			} else {
				//el.setAttribute(attr, inAttributes[attr]);
				el[attr] = inAttributes[attr];
			}
		}
	}
	
};

twiki.CSS = {

	/**
	Remove the given class from an element, if it is there.
	@param el : (HTMLElement) element to remove the class of
	@param inClassName : (String) CSS class name to remove
	*/
	removeClass:function(el, inClassName) {
		if (!el) return;
		var classes = twiki.CSS.getClassList(el);
		if (!classes) return;
		var index = twiki.CSS._indexOf(classes, inClassName);
		if (index >= 0) {
			classes.splice(index,1);
			twiki.CSS.setClassList(el, classes);
		}
	},
	
	/**
	Add the given class to the element, unless it is already there.
	@param el : (HTMLElement) element to add the class to
	@param inClassName : (String) CSS class name to add
	*/
	addClass:function(el, inClassName) {
		if (!el) return;
		var classes = twiki.CSS.getClassList(el);
		if (!classes) return;
		if (twiki.CSS._indexOf(classes, inClassName) < 0) {
			classes[classes.length] = inClassName;
			twiki.CSS.setClassList(el,classes);
		}
	},
	
	/**
	Replace the given class with a different class on the element.
	The new class is added even if the old class is not present.
	@param el : (HTMLElement) element to replace the class of
	@param inOldClass : (String) CSS class name to remove
	@param inNewClass : (String) CSS class name to add
	*/
	replaceClass:function(el, inOldClass, inNewClass) {
		if (!el) return;
		twiki.CSS.removeClass(el, inOldClass);
		twiki.CSS.addClass(el, inNewClass);
	},
	
	/**
	Get an array of the classes on the object.
	@param el : (HTMLElement) element to get the class list from
	*/
	getClassList:function(el) {
		if (!el) return;
		if (el.className && el.className != "") {
			return el.className.split(' ');
		}
		return [];
	},
	
	/**
	Set the classes on an element from an array of class names.
	@param el : (HTMLElement) element to set the class list to
	@param inClassList : (Array) list of CSS class names
	*/
	setClassList:function(el, inClassList) {
		if (!el) return;
		el.className = inClassList.join(' ');
	},
	
	/**
	Determine if the element has the given class string somewhere in it's
	className attribute.
	@param el : (HTMLElement) element to check the class occurrence of
	@param inClassName : (String) CSS class name
	*/
	hasClass:function(el, inClassName) {
		if (!el) return;
		if (el.className) {
			var classes = twiki.CSS.getClassList(el);
			if (classes) return (twiki.CSS._indexOf(classes, inClassName) >= 0);
			return false;
		}
	},
	
	/* PRIVILIGED METHODS */
	
	/**
	See: twiki.Array.indexOf
	Function copied here to prevent extra dependency on twiki.Array.
	*/
	_indexOf:function(inArray, el) {
		if (!inArray || inArray.length == undefined) return null;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == el) return i;
		}
		return -1;
	}

}

/**
Requires twikiCSS.js
*/

twiki.Form = {
	
	/*
	Original js filename: formdata2querystring.js
	
	Copyright 2005 Matthew Eernisse (mde@fleegix.org)
	
	Licensed under the Apache License, Version 2.0 (the "License");
	http://www.apache.org/licenses/LICENSE-2.0

	Original code by Matthew Eernisse (mde@fleegix.org), March 2005
	Additional bugfixes by Mark Pruett (mark.pruett@comcast.net), 12th July 2005
	Multi-select added by Craig Anderson (craig@sitepoint.com), 24th August 2006

	Version 1.3
	
	Changes for TWiki:
	Added KEYVALUEPAIR_DELIMITER and documentation by Arthur Clemens, 2006
	*/
	
	KEYVALUEPAIR_DELIMITER : ";",

	/**
	Serializes the data from all the inputs in a Web form
	into a query-string style string.
	@param inForm : (HTMLElement) Reference to a DOM node of the form element
	@param inFormatOptions : (Object) value object of options for how to format the return string. Supported options:
		  collapseMulti: (Boolean) take values from elements that can return multiple values (multi-select, checkbox groups) and collapse into a single, comma-delimited value (e.g., thisVar=asdf,qwer,zxcv)
	@returns Query-string formatted String of variable-value pairs
	@example
	<code>
	var queryString = twiki.Form.formData2QueryString(
		document.getElementById('myForm'),
		{collapseMulti:true}
	);
	</code>
	*/
	formData2QueryString:function (inForm, inFormatOptions) {
		if (!inForm) return null;
		var opts = inFormatOptions || {};
		var str = '';
		var formElem;
		var lastElemName = '';
		
		for (i = 0; i < inForm.elements.length; i++) {
			formElem = inForm.elements[i];
			
			switch (formElem.type) {
				// Text fields, hidden form elements
				case 'text':
				case 'hidden':
				case 'password':
				case 'textarea':
				case 'select-one':
					str += formElem.name
						+ '='
						+ encodeURI(formElem.value)
						+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					break;
				
				// Multi-option select
				case 'select-multiple':
					var isSet = false;
					for(var j = 0; j < formElem.options.length; j++) {
						var currOpt = formElem.options[j];
						if(currOpt.selected) {
							if (opts.collapseMulti) {
								if (isSet) {
									str += ','
										+ encodeURI(currOpt.text);
								} else {
									str += formElem.name
										+ '='
										+ encodeURI(currOpt.text);
									isSet = true;
								}
							} else {
								str += formElem.name
									+ '='
									+ encodeURI(currOpt.text)
									+ twiki.Form.KEYVALUEPAIR_DELIMITER;
							}
						}
					}
					if (opts.collapseMulti) {
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Radio buttons
				case 'radio':
					if (formElem.checked) {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value)
							+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Checkboxes
				case 'checkbox':
					if (formElem.checked) {
						// Collapse multi-select into comma-separated list
						if (opts.collapseMulti && (formElem.name == lastElemName)) {
						// Strip of end ampersand if there is one
						if (str.lastIndexOf('&') == str.length-1) {
							str = str.substr(0, str.length - 1);
						}
						// Append value as comma-delimited string
						str += ','
							+ encodeURI(formElem.value);
						}
						else {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value);
						}
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
						lastElemName = formElem.name;
					}
					break;
					
				} // switch
			} // for
		// Remove trailing separator
		str = str.substr(0, str.length - 1);
		return str;
	},
	
	/**
	Makes form field values safe to insert in a TWiki table. Any table-breaking characters are replaced.
	@param inForm: (String) the form to make safe
	*/
	makeSafeForTableEntry:function(inForm) {
		if (!inForm) return null;
		var formElem;
		
		for (i = 0; i < inForm.elements.length; i++) {
			formElem = inForm.elements[i];
			switch (formElem.type) {
				// Text fields, hidden form elements
				case 'text':
				case 'password':
				case 'textarea':
					formElem.value = twiki.Form._makeTextSafeForTableEntry(formElem.value);
					break;
			}
		}
	},
	
	/**
	Makes a text safe to insert in a TWiki table. Any table-breaking characters are replaced.
	@param inText: (String) the text to make safe
	@return table-safe text.
	*/
	_makeTextSafeForTableEntry:function(inText) {
		if (inText.length == 0) return "";
		var safeString = inText;
		var re;
		// replace \n by \r
		re = new RegExp(/\r/g);
		safeString = safeString.replace(re, "\n");	
		// replace pipes by forward slashes
		re = new RegExp(/\|/g);
		safeString = safeString.replace(re, "/");
		// replace double newlines
		re = new RegExp(/\n\s*\n/g);
		safeString = safeString.replace(re, "%<nop>BR%%<nop>BR%");
		// replace single newlines
		re = new RegExp(/\n/g);
		safeString = safeString.replace(re, "%<nop>BR%");
		// make left-aligned by appending a space
		safeString += " ";
		return safeString;
	},
	
	/**
	Finds the form element.
	@param inFormName : (String) name of the form
	@param inElementName : (String) name of the form element
	@return HTMLElement
	*/
	getFormElement:function(inFormName, inElementName) {
		return document[inFormName][inElementName];
	},
	
	/**
	Sets input focus to input element. Note: only one field on a page can have focus.
	@param inFormName : (String) name of the form
	@param inInputFieldName : (String) name of the input field that will get focus
	*/
	setFocus:function(inFormName, inInputFieldName) {
		try {
			var el = twiki.Form.getFormElement(inFormName, inInputFieldName);
			el.focus();
		} catch (er) {}
	},
	
	/**
	Sets the default text of an input field (for instance the text 'Enter keyword or product number' in a search box) that is cleared when the field gets focus. The field is styled with CSS class 'twikiInputFieldBeforeFocus'.
	@param el : (HTMLElement) the input field to receive default text
	@param inText : (String) the default text
	*/
	initBeforeFocusText:function(el, inText) {
		el.FP_defaultValue = inText;
		if (!el.value || el.value == inText) {
			twiki.Form._setDefaultStyle(el);
		}
	},
	
	/**
	Clears the default input field text. The CSS styling 'twikiInputFieldBeforeFocus' is removed. Call this function at 'onfocus'.
	@param el : (HTMLElement) the input field that has default text
	*/
	clearBeforeFocusText:function(el) {
		if (!el.FP_defaultValue) {
			el.FP_defaultValue = el.value;
		}
		if (el.FP_defaultValue == el.value) {
			el.value = "";
		}
		twiki.CSS.addClass(el, "twikiInputFieldFocus");
		twiki.CSS.removeClass(el, "twikiInputFieldBeforeFocus");
	},
	
	/**
	Restores the default text when the input field is empty. Call this function at 'onblur'.
	@param el : (HTMLElement) the input field to clear
	*/
	restoreBeforeFocusText:function(el) {
		if (!el.value && el.FP_defaultValue) {
			twiki.Form._setDefaultStyle(el);
		}
		twiki.CSS.removeClass(el, "twikiInputFieldFocus");
	},
	
	/**
	Sets the value and style of unfocussed or empty text field.
	@param el : (HTMLElement) the input field that has default text
	*/
	_setDefaultStyle:function(el) {
		el.value = el.FP_defaultValue;
		twiki.CSS.addClass(el, "twikiInputFieldBeforeFocus");
	}
	
};

