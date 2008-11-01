
/**
Ideally the rounding of objects is done in TWikiNetSkinPlugin, but unfortunately it is too hard to parse a DOM tree with regex only.
*/
var TWikiNetSkin = {
	
	_wrapInRoundedBlock:function(el, inElClassName, inRoundedWrapperClassName) {
		var elHtml = twiki.HTML.getHtmlOfElement(el);
		var roundedHtml = '<div class="' + inRoundedWrapperClassName + '"><div class="rCRounded"><div class="rCTR"><div class="rCTL"></div>' + '<div class="' + inElClassName + '">' + elHtml + '</div>' + '</div><div class="rCBR"><div class="rCBL"></div></div></div></div>';
		var rounded = document.createElement("div");
		twiki.HTML.setHtmlOfElement(rounded, roundedHtml);
		return rounded;
	},
	
	makeRounded:function(el, inClassName, inRoundedWrapperClassName) {
		var rounded = TWikiNetSkin._wrapInRoundedBlock(el, inClassName, inRoundedWrapperClassName);
		el.parentNode.replaceChild(rounded, el);
	}
}

var twikinetSkinRules = {

	'.patternEditPage .twikiForm' : function(el) {
		TWikiNetSkin.makeRounded(el, 'twikiForm', 'twikinetRounded twikinetRoundedForm');
	},
	'.twikiHelp' : function(el) {
		TWikiNetSkin.makeRounded(el, 'twikiHelp', 'twikinetRoundedHelp');
	}
};
Behaviour.register(twikinetSkinRules);