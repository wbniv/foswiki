/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

/**
Singleton class. Requires behaviour.js from BehaviourContrib.
*/
var twiki;
if (!twiki) twiki = {};
twiki.TwistyPlugin = new function () {

	var self = this;

	/**
	Retrieves the name of the twisty from an HTML element id. For example 'demotoggle' will return 'demo'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getName = function (inId) {
		var re = new RegExp("(.*)(hide|show|toggle)", "g");
		var m = re.exec(inId);
		var name = (m && m[1]) ? m[1] : "";
    	return name;
	}
	
	/**
	Retrieves the type of the twisty from an HTML element id. For example 'demotoggle' will return 'toggle'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getType = function (inId) {
		var re = new RegExp("(.*)(hide|show|toggle)", "g");
		var m = re.exec(inId);
    	var type = (m && m[2]) ? m[2] : "";
    	return type;
	}
	
	/**
	Toggles the collapsed state. Calls _update().
	@privileged
	*/
	this._toggleTwisty = function (ref) {
		if (!ref) return;
		ref.state = (ref.state == twiki.TwistyPlugin.CONTENT_HIDDEN) ? twiki.TwistyPlugin.CONTENT_SHOWN : twiki.TwistyPlugin.CONTENT_HIDDEN;
		self._update(ref, true);
	}
	
	/**
	Updates the states of UI trinity 'show', 'hide' and 'content'.
	Saves new state in a cookie if one of the elements has CSS class 'twistyRememberSetting'.
	@param ref : (Object) twiki.TwistyPlugin.Storage object
	@privileged
	*/
	this._update = function (ref, inMaySave) {
		var showControl = ref.show;
		var hideControl = ref.hide;
		var contentElem = ref.toggle;
		if (ref.state == twiki.TwistyPlugin.CONTENT_SHOWN) {
			// show content
			twiki.CSS.addClass(showControl, 'twistyHidden');	// hide 'show'
			twiki.CSS.removeClass(hideControl, 'twistyHidden'); // show 'hide'
			twiki.CSS.removeClass(contentElem, 'twistyHidden'); // show content
		} else {
			// hide content
			twiki.CSS.removeClass(showControl, 'twistyHidden'); // show 'show'	
			twiki.CSS.addClass(hideControl, 'twistyHidden'); // hide 'hide'
			twiki.CSS.addClass(contentElem, 'twistyHidden'); // hide content
		}
		if (inMaySave && ref.saveSetting) {
	        twiki.Pref.setPref(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, ref.state);
		}
		if (ref.clearSetting) {
	        twiki.Pref.setPref(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, "");
		}
	}
	
	/**
	Stores a twisty HTML element (either show control, hide control or content 'toggle').
	@param e : (Object) HTMLElement
	@privileged
	*/
	this._register = function (e) {
		if (!e) return;
		var name = self._getName(e.id);
		var ref = self._storage[name];
		if (!ref) {
			ref = new twiki.TwistyPlugin.Storage();
		}
		if (twiki.CSS.hasClass(e, "twistyRememberSetting")) ref.saveSetting = true;
		if (twiki.CSS.hasClass(e, "twistyForgetSetting")) ref.clearSetting = true;
		if (twiki.CSS.hasClass(e, "twistyStartShow")) ref.startShown = true;
		if (twiki.CSS.hasClass(e, "twistyStartHide")) ref.startHidden = true;
		if (twiki.CSS.hasClass(e, "twistyFirstStartShow")) ref.firstStartShown = true;
		if (twiki.CSS.hasClass(e, "twistyFirstStartHide")) ref.firstStartHidden = true;
		ref.name = name;
		var type = self._getType(e.id);
		ref[type] = e;
		self._storage[name] = ref;
		switch (type) {
			case 'show': // fall through
			case 'hide':
				e.onclick = function() {
					self._toggleTwisty(ref);
					return false;
				}
				break;
		}
		return ref;
	}
	
	/**
	Key-value set of twiki.TwistyPlugin.Storage objects. The value is accessed by twisty id identifier name.
	@example var ref = self._storage["demo"];
	@privileged
	*/
	this._storage = {};
	
	/**
	UI element behaviour, in case no javascript 'trigger' tags are inserted in the html
	@privileged
	*/
	this._UIbehaviour = {	
		/**
		Show control, hide control
		*/
		'.twistyTrigger' : function(e) {
			twiki.TwistyPlugin.init(e.id);
			e = null;
		},
		/**
		Content element
		*/
		'.twistyContent' : function(e) {
			twiki.TwistyPlugin.init(e.id);
			e = null;
		},
		/**
		Content element
		*/
		'.twistyExpandAll' : function(e) {
			e.onclick = function() {
				twiki.TwistyPlugin.toggleAll(twiki.TwistyPlugin.CONTENT_SHOWN);
			}
			e = null;
		},
		'.twistyCollapseAll' : function(e) {
			e.onclick = function() {
				twiki.TwistyPlugin.toggleAll(twiki.TwistyPlugin.CONTENT_HIDDEN);
			}
			e = null;
		}
	};
	Behaviour.register(this._UIbehaviour);
};

/**
Public constants.
*/
twiki.TwistyPlugin.CONTENT_HIDDEN = 0;
twiki.TwistyPlugin.CONTENT_SHOWN = 1;
twiki.TwistyPlugin.COOKIE_PREFIX = "TwistyContrib_";

/**
The cached full TWiki cookie string so the data has to be read only once during init.
*/
twiki.TwistyPlugin.prefList;

/**
Initializes a twisty HTML element (either show control, hide control or content 'toggle') by registering and setting the visible state.
Calls _register() and _update().
@public
@param inId : (String) id of HTMLElement
@return The stored twiki.TwistyPlugin.Storage object.
*/
twiki.TwistyPlugin.init = function(inId) {
	var e = document.getElementById(inId);
	if (!e) return;

	// check if already inited
	var name = this._getName(inId);
	var ref = this._storage[name];
	if (ref && ref.show && ref.hide && ref.toggle) return ref;

	// else register
	ref = this._register(e);
	
	twiki.CSS.replaceClass(e, "twistyMakeHidden", "twistyHidden");
	twiki.CSS.removeClass(e, "twikiMakeVisible");
	twiki.CSS.removeClass(e, "twikiMakeVisibleBlock");
	twiki.CSS.removeClass(e, "twikiMakeVisibleInline");
	twiki.CSS.removeClass(e, "twikiMakeHidden");
	
	if (ref.show && ref.hide && ref.toggle) {
		// all Twisty elements present

		if (twiki.CSS.hasClass(e, "twistyInited1")) {
			ref.state = twiki.TwistyPlugin.CONTENT_SHOWN
			this._update(ref, false);
			return ref;
		}
		if (twiki.CSS.hasClass(e, "twistyInited0")) {
			ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN
			this._update(ref, false);
			return ref;
		}

		if (twiki.TwistyPlugin.prefList == null) {
			// cache complete cookie string
			twiki.TwistyPlugin.prefList = twiki.Pref.getPrefList();
		}
		var cookie = twiki.Pref.getPrefValueFromPrefList(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, twiki.TwistyPlugin.prefList);
		if (ref.firstStartHidden) ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (ref.firstStartShown) ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;
		// cookie setting may override  firstStartHidden and firstStartShown
		if (cookie && cookie == "0") ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (cookie && cookie == "1") ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;
		// startHidden and startShown may override cookie
		if (ref.startHidden) ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (ref.startShown) ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;

		this._update(ref, false);
	}
	return ref;	
}

twiki.TwistyPlugin.toggleAll = function(inState) {
	var i;
	for (var i in this._storage) {
		var e = this._storage[i];
		e.state = inState;
		this._update(e, true);
	}
}

/**
Storage container for properties of a twisty HTML element: show control, hide control or toggle content.
*/
twiki.TwistyPlugin.Storage = function () {
	this.name;										// String
	this.state = twiki.TwistyPlugin.CONTENT_HIDDEN;	// Number
	this.hide;										// HTMLElement
	this.show;										// HTMLElement
	this.toggle;									// HTMLElement (content element)
	this.saveSetting = false;						// Boolean; default not saved
	this.clearSetting = false;						// Boolean; default not cleared
	this.startShown;								// Boolean
	this.startHidden;								// Boolean
	this.firstStartShown;							// Boolean
	this.firstStartHidden;							// Boolean
}