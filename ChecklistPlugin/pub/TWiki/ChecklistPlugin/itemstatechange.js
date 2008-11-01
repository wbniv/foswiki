var clpStateChangeObjectArray = new Array(); // queue
var clpCursorNormalStyle = "move";
var clpCursorInProgressStyle = "wait";
var clpInProgressDivText = "State is changing ... please wait ...";
function ClpStateChangeObject(url, stateChangeRequest) {
	this.stateChangeRequest = stateChangeRequest;
	this.url = url;
	this.clpDoIt=clpDoIt;
	this.clpHandleNextObject=clpHandleNextObject;
	this.clpHandleTextResponse=clpHandleTextResponse;
	this.clpInit = clpInit;
	this.changes = new Array();
	this.changesNew = new Array();
}
function clpInit() {
	try { // Firefox, Opera 8.0+, Safari
		this.stateChangeRequest = new XMLHttpRequest();
		// if (this.stateChangeRequest.overrideMimeType) this.stateChangeRequest.overrideMimeType("text/xml");
	} catch (e) { // Internet Explorer
		try {
			this.stateChangeRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
			try {
				this.stateChangeRequest=new ActiveXObject("Microsoft.XMLHTTP");
			} catch (e) {
				alert("Your browser does not support AJAX!\nPlease disable AJAX (e.g. use attribute: useajax=\"off\") ");
			}
		}

	}
	return this.stateChangeRequest;
}
function clpStripUrl(href) {
	href.match(/submitItemStateChange.'([^']+)'/);
	return RegExp.$1;
}
function clpHandleNextObject(self) {
	clpStateChangeObjectArray.shift(); // remove myself
	while (self.changes.length>0) {
		var oldUrl = clpStripUrl(self.changes.shift());
		var newUrl = clpStripUrl(self.changesNew.shift());
		var n = clpGetStateChangeObject(oldUrl);
		if (n) n.url=newUrl;
	}
	if (clpStateChangeObjectArray.length>0) clpStateChangeObjectArray.shift().clpDoIt();
	clpSetCursorByTagName("body", "auto");
}
function clpHandleStateChange(self) {
	if (self.stateChangeRequest.readyState!=4) return;
	if (self.stateChangeRequest.status != 200) {
		document.write(self.stateChangeRequest.responseText);
		return;
	}

	var responseText = self.stateChangeRequest.responseText;
	/* var responseXML = self.stateChangeRequest.responseXML;
	if ((!responseXML.hasChildNodes) && (typeof(XMLHttpRequest)=="undefined")) {
		var text = self.stateChangeRequest.responseText;
		responseXML = new ActiveXObject("Msxml2.DOMDocument");
		text = responseText.replace(/<\/html>/,"");
		text = responseText.slice(text.indexOf("<body"));
		responseXML.loadXML(text);
		if (responseXML.parseError.errorCode != 0) responseXML=null;
		if (responseXML!=null) responseXML.setProperty("SelectionLanguage", "XPath");
	}
	*/
	clpHandleTextResponse(self, responseText);
}
function clpHandleTextResponse(self, responseText) {
	var links = responseText.match(/<a[^>]+name="CLP_A_[^>]+>/ig);
	if (links && (links.length>0)) {
		AllLinks: for (var i = 0 ; i < links.length; ++i) {
			var e;
			var link = links[i];
			link.match(/name="CLP_A_([^"]+)"/);
			var id = RegExp.$1;

			var imgExpr = new RegExp("<img[^>]+name=\"CLP_IMG_" + id + "\"[^>]*>","i");
			var img = "" + imgExpr.exec(responseText);
			img.match(/src="([^"]+)"/);
			var src = RegExp.$1;
			img.match(/alt="([^"]+)"/);
			var alt = RegExp.$1;
			//img.match(/onclick="([^"]+)"/);
			//var onclick = RegExp.$1;
			var els = document.getElementsByName("CLP_IMG_"+id);
			if  (els && els.length) {
				for (var j=0; j<els.length; ++j) {
					if (src && (els[j].src == src)) continue AllLinks;
					if ((!src || src == "") && (alt && alt!="" && els[j].alt == alt)) continue AllLinks;
					els[j].src = src;
					if (!src || src == "") els[j].alt = alt;
				
					//if (onclick) els[j].onclick=onclick;
				}
			}

			els = document.getElementsByName("CLP_A_"+id);
			if (els && els.length) {
				for (var j=0; j<els.length; ++j) {
					link.match(/href="([^"]+)"/);
					var href=RegExp.$1;
					els[j].style.cursor=clpCursorNormalStyle;
					self.changes.push(els[j].href);
					self.changesNew.push(href);
					els[j].href = href; 
				}
			}

			var divExpr = new RegExp("<div[^>]+id=\"CLP_TT_"+id+"\"[^>]*>(.*?)</div>");
			divExpr.exec(responseText);
			var divTxt = RegExp.$1;

			clpChangeDivText("CLP", id, divTxt);
						
			var smlinksRegExp = new RegExp("<a[^>]+id=\"CLP_SM_A_"+id+"_[^>]+>","gi");
			var smlinks = responseText.match(smlinksRegExp);
			
			if (smlinks && (smlinks.length>0)) {
				for (var j=0; j<smlinks.length; ++j) {
					var smlink = smlinks[j];
					smlink.match(/id="([^"]+)"/i);
					var smid = RegExp.$1;
					smlink.match(/href="([^"]+)"/);
					var smhref = RegExp.$1;
					smlink.match(/title="([^"]+)"/);
					var smtitle = RegExp.$1;
					var sme = document.getElementById(smid);
					if (sme) {
						sme.style.cursor=clpCursorNormalStyle;
						sme.href = smhref;
					} // if
					var smttid = smid.replace(/CLP_SM_A_/,"");
					sme = document.getElementById("CLP_SM_IMG_"+smttid);
					if (sme) sme.style.cursor=clpCursorNormalStyle;
					var smDivExpr = new RegExp("<div[^>]+id=\"CLP_SM_TT_"+smttid+"\"[^>]*>(.*?)</div>");	
					smDivExpr.exec(responseText);
					var smDivTxt = RegExp.$1;
					clpChangeDivText("CLP_SM",smttid, smDivTxt);
				} // for
			} // if
		} // for 
	} else {
		document.write(responseText);
	} // if
	clpHandleNextObject(self);
}
function clpDoIt() {
	if (!this.clpInit()) {
		document.submit(url);
		return;
	}
	clpSetCursorByTagName("body", clpCursorInProgressStyle);
	var self = this;
	this.stateChangeRequest.onreadystatechange=function() {
		try {
			clpHandleStateChange(self);
		} catch (e) {
			alert("Sorry, an error occured:\n"+e+"\nPlease reload the page!");
		}
	};
	if (this.stateChangeRequest.onerror) {
		this.stateChangeRequest.onerror=function() {
			document.write(self.stateChangeRequest.responseText);
		};
	}
	this.stateChangeRequest.open("GET", this.url, true);
	// this.stateChangeRequest.setRequestHeader('Content-Type', 'text/xml'); 
	this.stateChangeRequest.setRequestHeader('Cache-Control', 'no-cache'); 
	this.stateChangeRequest.send(null);
}
function clpStripId(url) {
	return url.replace(/clpid=[^;]+;/i,"");
}
function clpGetStateChangeObject(url) {
	for (var i=0; i<clpStateChangeObjectArray.length; ++i) {
		if (clpStripId(clpStateChangeObjectArray[i].url)==clpStripId(url)) return clpStateChangeObjectArray[i];
	}
	return null;
}
function clpGetIdFromUrl(url) {
	// clpscn + clpsc
	url.match(/clpsc=([^\;]+)\;/);
	var clpsc = RegExp.$1;
	url.match(/clpscn=([^\;]+)\;/);
	var clpscn = RegExp.$1;
	return clpscn+clpsc;
}
function clpChangeDivText(prefix,id, text) {
	var e = document.getElementById(prefix+"_TT_"+id);
	if (e) {
		if (e.innerHTML) {
			e.innerHTML = text;
		} else {
			while (e.hasChildNodes()) e.removeChild(e.firstChild); 
			e.appendChild(document.createTextNode(text));
		}
	}
	
}
function clpSetCursorByTagName(tagName, cursor) {
	var eArr = document.getElementsByTagName(tagName);
	if (eArr && eArr.length>0) eArr[0].style.cursor=cursor;
}
var clpSubmitItemStateChangeMutex = 0;
function submitItemStateChange(url) {
	while (clpSubmitItemStateChangeMutex>0) { alert("You click to fast for me"); }
	clpSubmitItemStateChangeMutex++;
	var newStateChangeObject = new ClpStateChangeObject(url);
	clpStateChangeObjectArray.push(newStateChangeObject);

	var id = clpGetIdFromUrl(url);
	var e = document.getElementById("CLP_A_"+id);
	if (e) e.style.cursor=clpCursorInProgressStyle;

	clpChangeDivText("CLP", id, clpInProgressDivText);

	if (clpStateChangeObjectArray.length==1) newStateChangeObject.clpDoIt();
	clpSubmitItemStateChangeMutex--;
}

// --- tooltips (derived from http://www.texsoft.it/index.php?c=software&m=sw.js.htmltooltip&l=it) ---
function clpTooltipFindPos(obj) {
        var curleft;
        var curtop;
        curleft = 0; curtop = 0;

        if (obj.offsetParent) {
                curleft = obj.offsetLeft;
                curtop = obj.offsetTop;
                while ((obj = obj.offsetParent)) {
                        if (obj.offsetLeft) curleft += obj.offsetLeft;
                        if (obj.offsetTop) curtop += obj.offsetTop;
                }
        } else if (obj.x && obj.y) {
                curleft = obj.x;
                curtop = obj.y;
        }
        return [curleft,curtop];
}
var clpTooltipLastVisibleId = new Array();
function clpTooltipShow(tooltipId, parentId, posX, posY,closeAll) {
	var it = document.getElementById(tooltipId);
	if (closeAll) {
		while (clpTooltipLastVisibleId.length>0) {
			var lv = document.getElementById(clpTooltipLastVisibleId.shift());
			if (lv) lv.style.visibility = 'hidden';
		}
	}
	clpTooltipLastVisibleId.push(tooltipId);
    
	if (!it) return;

	var img = document.getElementById(parentId); 

	var pos = clpTooltipFindPos(img);

	it.style.left = (pos[0]+posX) + 'px';
	it.style.top = (pos[1]+posY) + 'px';

	it.style.visibility = 'visible'; 

	img.style.cursor=clpCursorNormalStyle;
}

function clpTooltipHide(id) {
	var it = document.getElementById(id); 
	if (it) it.style.visibility = 'hidden'; 
}

