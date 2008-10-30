
/*
InitZenCssUrls() modifies the url's on the page to append the current css design choice to all links. 
this allows the user to try out different designs without cookies, or other session persistent ways
*/
InitZenCssUrls = function() {
	var zengardenCss = "http://www.csszengarden.com/";
	var nextCss = 1;
	if (myMatch = currentCss.match(/\/\d\d\d\/(\d\d\d)\.css$/)) { 
		nextCss = myMatch[1];
		nextCss++;
	}
	var nextCssStr = '000';
	nextCssStr = nextCssStr.substr(0, 3-nextCss.toString().length) + nextCss.toString();
	var nextUrl = zengardenCss + nextCssStr + "/" + nextCssStr + ".css";
	var previousUrl = nextUrl;
	var previousCss = nextCss - 2;
	if (previousCss <= 0) {
		previousCss = 200;
	}
	var previousCssStr = '000';
	previousCssStr = previousCssStr.substr(0, 3-previousCss.toString().length) + previousCss.toString();
    previousUrl = zengardenCss + previousCssStr + "/" + previousCssStr + ".css";

	//add the cssfile parameter to all URLs..
	var links = document.getElementsByTagName('A');
	for(var i=0;i<links.length;i++) {
		if (links[i].id == 'defaultCss') {
		    links[i].href = '?skin=zengarden;zengardentopic='+currentText+';cssfile='+zengardenCss+"001/001.css";
		    continue;
		}
		if (links[i].id == 'nextCss') {
	    	links[i].href = '?skin=zengarden;zengardentopic='+currentText+';cssfile='+nextUrl;
		    continue;
		}
		if (links[i].id == 'previousCss') {
    		links[i].href = '?skin=zengarden;zengardentopic='+currentText+';cssfile='+previousUrl;
		    continue;
		}
		
		//only append to url's from this TWiki's scripted cgi-s
		if (links[i].href.indexOf(twikiScriptUrlBase) != 0) continue;
		
		var URLseperator = ';';
		if (links[i].href.indexOf('?') == -1) {
			URLseperator = '?';
		}
		//TODO:don't add to non TWiki scripted URLs
		//TODO: should make skin= to actual URLPARAM..
		links[i].href = links[i].href+URLseperator+'cssfile='+currentCss+';skin=zengarden;zengardentopic='+currentText;
	}
	//add to form actions too
	var forms = document.getElementsByTagName('form');
	for(var i=0;i<forms.length;i++) {
		var element = document.createElement("input");
    	element.setAttribute("name", "cssfile");
    	element.setAttribute("type", "hidden");
    	element.setAttribute("value", currentCss);
		forms[i].appendChild(element);
		var SkinElement = document.createElement("input");
    	SkinElement.setAttribute("name", "skin");
    	SkinElement.setAttribute("type", "hidden");
    	SkinElement.setAttribute("value", "zengarden");
		forms[i].appendChild(SkinElement);
	}
}
