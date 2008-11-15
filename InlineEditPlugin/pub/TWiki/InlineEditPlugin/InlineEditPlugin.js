/*
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
*/

//Argh: Cairo patternskin compatibility!
function initPage() {
    if (onloadFuncChainCalled == 0) {
        onloadFuncChain();
    }
}

var onloadFuncChain;
var onloadFuncChainCalled = 0;
// DON'T overwrite existing onload handlers (copied from NatSkin)
//  http://simon.incutio.com/archive/2004/05/26/addLoadEvent
function addLoadEvent(func){
  var oldonload = window.onload;
  if (typeof window.onload != 'function') {
    window.onload = function() {
      onloadFuncChainCalled = 1;
      func();
    }
  } else {
    window.onload = function() {
      onloadFuncChainCalled = 1;
      oldonload();
      func();
    }
  }
  onloadFuncChain = window.onload;
}

//create the TWiki namespace if needed
if ( typeof( TWiki ) == "undefined" ) {    TWiki = {}; }
//create the TWiki.InlineEditPlugin namespace if needed
if ( typeof( TWiki.InlineEditPlugin ) == "undefined" ) {    TWiki.InlineEditPlugin = {}; }


TWiki.InlineEditPlugin.requestTopicState = function(topic, success_func) {
	if (success_func == undefined) {
		success_func = showTopicState;
	}
    var callback = { 
	  success: success_func, 
	  failure: function(o) {
	  			alert('Error!\nStatusText='+o.statusText+'\nContents='+o.responseText);
		}
        ,argument: ['svenwashere'] 
	};
	var restUrl = TWikiScriptUrl+'/rest/InlineEditPlugin/getTopicState';
    //have to URI encode the data - to allow + signs in topic text..
	var postParams = 'replywitherrors=1;dataType=JSON;topicName='+topic;
	var transaction = YAHOO.util.Connect.asyncRequest('POST', restUrl, callback, postParams); 
	return transaction;
}

//show the current state of the topic
showTopicState = function(o) { //where o is the return obj from YAHOO.util.Connect.asyncRequest
	var stateJSON = o.responseText;
    var state= eval('('+stateJSON+')');

//TODO: make a status bar?
//    if (state.topicRevision != currentState.topicRevision) {
//        alert(state.topicUser+' updated this topic on '+state.topicDate+'\n It might be safer to refresh before editing');
//        //replace with custom popup window, with ability to refresh, cancel....
//    } else 
	if ((state.leasedBy != '') && (state.leasedBy != state.me)) {
        alert('Sorry, this topic is being locked / leased for edit by '+state.leasedBy+' for the next '+state.leasedFor+' minutes');
        //replace with custom popup window, with ability to wait for lock, or to cancel - re-request every now and then, and then re-fresh view
    } else {
        alert('Ready to edit   ' + stateJSON);
    }

    //don't just do this - it over-writes the save url with the wrong one..
    //topicSections[state.topicSection] = state;
}

//used by the JS TML2HTML to render
getViewUrl = function(web,topic) {
return 'http://www.home.org.au';//TODO:fill me in
 }

getEditableHTML = function(topicSectionObject) {
    var tml2html = new TML2HTML();
    var options = new Object();
    options.getViewUrl = getViewUrl;


    var editableHTML = 'ERROR: you should never see this';

    if ( topicSectionObject.TML2HTMLdiv != null ) {
        editableHTML = topicSectionObject.TML2HTMLdiv.innerHTML;
    } else {
        editableHTML = tml2html.convert(topicSectionObject.tml, options);
    }

    //hack around the fact i'm using private members
    //TODO: i'll want this array to be global, so that we don't need to parse more than once
    tml2html.refs = new Array();
    //this pulls the vars out..
    editableHTML = tml2html._processTags(editableHTML);
    //put round clickable spans..
    for (var i = 0; i < tml2html.refs.length; i++) {
        //TODO: this won't work :( as it strips %'s off Macros nested inside other Macros - but its needed as otherwise OnSave added %'s to the vars
         tml2html.refs[i] =  tml2html.refs[i].substring(1,  tml2html.refs[i].length-1);
         //TODO:replace this with an over-rideable / configurable function that ComponentEditPlugin can set.
         // because it seems that the onclick context has little access to the surrounding environment
         //this is totally reliant on the iframe window src being the same as that of the main page. (Ingy says he'll use my fix..)
         //TODO: use edited return value and put back into document
        //NOTE: HTML2TML looks for TMLvariable (lowercase v)
         tml2html.refs[i] = "<span id='TMLvariable"+i+"' class='TMLvariable' >" + tml2html.refs[i] + '</span>';
    }
    //now put them back..
    editableHTML = tml2html._dropBack(editableHTML);

    return editableHTML;
}

// Find all the divs in the page (after it has loaded) and Wikiwygify them.
var topicSections = [];
InlineEditOnload = function() {
    var divs = [];
    var tmldivs = [];
    var tml2htmldivs = [];
    var twikiTopicStatedivs = [];
    var elements = document.getElementsByTagName('div');
    for (var i = 0; i < elements.length; i++) {
        //The user viewed HTML
        if (jscss('check', elements[i], 'inlineeditTopicHTML')) {
            var id = elements[i].id.substring((elements[i].id.lastIndexOf('_'))+1, elements[i].id.length) * 1;
            //alert(elements[i].id + '>----<'+id+'>')
            divs[id] = elements[i];
        }
        //The HTML generated using the perl TM2HTML code
        if (jscss('check', elements[i], 'inlineeditTopicTML2HTML')) {
            var id = elements[i].id.substring((elements[i].id.lastIndexOf('_'))+1, elements[i].id.length) * 1;
            tml2htmldivs[id] = elements[i];
        }
    }
    elements = document.getElementsByTagName('button');
    for (var i = 0; i < elements.length; i++) {
    }
    elements = document.getElementsByTagName('textarea');
    for (var i = 0; i < elements.length; i++) {
        if (jscss('check', elements[i], 'inlineeditTopicTML')) {
            var id = elements[i].id.substring((elements[i].id.lastIndexOf('_'))+1, elements[i].id.length) * 1;
            tmldivs[id] = elements[i].value;
        }
        if (jscss('check', elements[i], 'inlineeditTopicInfo')) {
            var id = elements[i].id.substring((elements[i].id.lastIndexOf('_'))+1, elements[i].id.length) * 1;
            twikiTopicStatedivs[id] = elements[i];
        }
    }
    if (divs.length == 0) {
//        alert('InlineEdit: no inline edit div elements found');
        return;
    }
    for (var i in divs) {
        var tmldiv, tml2htmldiv, topicInfo;
        if (tml2htmldivs[i]) {tml2htmldiv=tml2htmldivs[i]};
        if (twikiTopicStatedivs[i]) {topicInfo=twikiTopicStatedivs[i].innerHTML};

        if (typeof topicInfo == 'undefined')
            continue;
        if (typeof (divs[i]) == 'undefined')
            continue; //no HTML to anchor to

        var topicSectionObject = topicInfo.parseJSON();
        if (!topicSectionObject) {
            //alert(topicInfo);	//TODO: buggo - there are some section that don't get JSON parseable info.
			continue;
        }

        topicSectionObject.tml = tmldivs[i];
        topicSectionObject.HTMLdiv = divs[i];

        topicSectionObject.HTMLdiv.topicSectionObject = topicSectionObject;
        topicSectionObject.topicinfoSrc = topicInfo;

        //addEvent(topicSectionObject.HTMLdiv, 'mouseover', showSectionalEditButtons);
        //addEvent(topicSectionObject.HTMLdiv, 'mouseout', hideSectionalEditButtons);
        addEvent(topicSectionObject.HTMLdiv, 'dblclick', gotoEditModeFromEvent);

        //TODO: add an action for each applicable mini-editor, and other actions
        var span = document.createElement('div');
        span.innerHTML = "[edit] ";
        span.style.display='inline';
        jscss('add', span, 'showFloatRight');
        jscss('add', span, 'hoverUnderline');
        topicSectionObject.HTMLdiv.insertBefore(span, topicSectionObject.HTMLdiv.firstChild);
        addEvent(span, 'click', gotoEditModeFromEvent);

        topicSectionObject.TML2HTMLdiv = tml2htmldiv;

		topicSectionObject.index = topicSections.length;
        topicSections.push(topicSectionObject);
    }
}

showSectionalEditButtons = function(event) {
//TODO: this should be done using css class names
    var topicSectionObject = getTopicSectionObject(event);
    jscss('add', topicSectionObject.HTMLdiv, 'showBorder');
}
hideSectionalEditButtons = function(event) {
    var topicSectionObject = getTopicSectionObject(event);
    jscss('remove', topicSectionObject.HTMLdiv, 'showBorder');
}

gotoEditModeFromEvent = function(event) {
    var topicSectionObject = getTopicSectionObject(event);
    gotoEditMode(topicSectionObject);

    //add the save, cancel, add new section buttons
    if (!topicSectionObject.editDivSection.adorned) {
        topicSectionObject.editDivSection.adorned = 1;

        var pre = document.createElement('DIV');
        jscss('add', pre, ' showElementInline');
        var post = document.createElement('DIV');
        jscss('add', post, ' showElementInline');

        var add_above = '';
        //TODO: be more discriminating - only create add_ buttonset if there is not already one at that seperation
//topicSectionObject.index = topicSections.length;
		if ((topicSectionObject.index == 0)
		 || (topicSectionObject.newSection)
		 || (typeof(topicSections[topicSectionObject.index-1].editDivSection) == 'undefined')
		 ) {
		 	//TODO: replace with a dropdown selet and an add button (and right justify..)
			//got through the registered editors
        	for (var i=0;i<TWiki.InlineEditPlugin.editors.length;i++) {
            	var getTypeName = TWiki.InlineEditPlugin.editors[i]+'.getTypeName()';
            	var typeName = eval(getTypeName);

    	    	add_above = add_above + makeFormButton('add_above', 'Add '+typeName+' Above', 'addNewSection(event, 1, '+i+');');
			}
		}
       	pre.innerHTML = add_above;

        var add_below = '';
        add_below = add_below + makeFormButton('save', 'Save', 'saveEditMode(event);');
        add_below = add_below + makeFormButton('preview', 'Preview', 'previewMode(event);', 1);
        if (! topicSectionObject.newSection) {
            add_below = add_below + makeFormButton('cancel', 'Cancel', 'cancelEditMode(event);');
        }
        add_below = add_below + '&nbsp;|&nbsp;';
        add_below = add_below + makeFormButton('delete', 'Delete', 'deleteSection(event);');
        add_below = add_below + makeFormButton('moveup', 'Move Up', 'moveSectionUp(event);', 1);
        add_below = add_below + makeFormButton('movedown', 'Move Down', 'moveSectiondown(event);', 1);
		if ((topicSectionObject.index == topicSections.length-1) 
		 || (topicSectionObject.newSection)
		 || (typeof(topicSections[topicSectionObject.index+1].editDivSection) == 'undefined')
			) {
        	add_below = add_below + '&nbsp;|&nbsp;';
			//got through the registered editors
        	for (var i=0;i<TWiki.InlineEditPlugin.editors.length;i++) {
            	var getTypeName = TWiki.InlineEditPlugin.editors[i]+'.getTypeName()';
            	var typeName = eval(getTypeName);

    	    	add_below = add_below + makeFormButton('add_below', 'Add '+typeName+' Below', 'addNewSection(event, 1, '+i+');');
			}
		}

        post.innerHTML = add_below;

        topicSectionObject.editDivSection.insertBefore(pre, topicSectionObject.editDivSection.firstChild);
        topicSectionObject.editDivSection.insertBefore(post, topicSectionObject.editDivSection.elements[topicSectionObject.editDivSection.elements.length-1].nextSibling);
    }
}

function gotoEditMode(topicSectionObject) {
    topicSectionObject.modified = 1;    //TODO: make sure there really is a change..

    //for the delayed edit creation case (preffered)
    if ( typeof( topicSectionObject.editDivSection ) == "undefined" ) {

        //got through the registered editors, find the first applicable one, and instanciate it.
        for (var i=0;i<TWiki.InlineEditPlugin.editors.length;i++) {
            var appliesTo = TWiki.InlineEditPlugin.editors[i]+'.appliesToSection(topicSectionObject)';
            if (eval(appliesTo)) {
                var newEditor = 'new '+TWiki.InlineEditPlugin.editors[i]+'(topicSectionObject)';
                topicSectionObject.editSectionObject = eval(newEditor);
                topicSectionObject.editDivSection = topicSectionObject.editSectionObject.createEditSection();

                topicSectionObject.HTMLdiv.parentNode.insertBefore(topicSectionObject.editDivSection, topicSectionObject.HTMLdiv);
                break;
            }
        }
    }
    if (typeof( topicSectionObject.editDivSection ) == "undefined") {
        alert('sorry, no applicable inline editor registered');
    } else {
        jscss('add', topicSectionObject.editDivSection, 'showElementInline');
        jscss('remove', topicSectionObject.editDivSection, 'hideElement');
        jscss('add', topicSectionObject.HTMLdiv, 'hideElement');
        jscss('remove', topicSectionObject.HTMLdiv, 'showElementInline');
    }
}

hideEdit = function(topicSectionObject) {
        jscss('add', topicSectionObject.HTMLdiv, 'showElementInline');
        jscss('remove', topicSectionObject.HTMLdiv, 'hideElement');
        jscss('add', topicSectionObject.editDivSection, 'hideElement');
        jscss('remove', topicSectionObject.editDivSection, 'showElementInline');
}

addNewSection = function(event, putSectionAbove, sectionType, sectionTml) {
    var originatingTopicSectionObject = getTopicSectionObject(event);
    if (typeof originatingTopicSectionObject.newSectionName == 'undefined')
        originatingTopicSectionObject.newSectionName = 0;

    {//create new Section
//'<div class="inlineeditTopicTML" '.$hiddenStyle.'id="inlineeditTopicTML_'.$section.'" '.'>'.$tml.'</div>';
        var aboveBelow = new Array('below', 'above');
        var newSectionID = 'new'+originatingTopicSectionObject.topicSection+aboveBelow[putSectionAbove]+originatingTopicSectionObject.newSectionName;
        originatingTopicSectionObject.newSectionName++;

		var newTmlFunc = TWiki.InlineEditPlugin.editors[sectionType]+'.getDefaultTml()';
        var newTml = eval(newTmlFunc);

        //TODO: change the ids etc..
        var htmldiv=document.createElement('DIV');
        htmldiv.setAttribute("class", "inlineeditTopicHTML")
        htmldiv.setAttribute("id", 'inlineeditTopicHTML_'+newSectionID)
        htmldiv.innerHTML = newTml;
        var tml2htmldiv=document.createElement('DIV');
        htmldiv.setAttribute("class", "inlineeditTopicTML2HTML")
        htmldiv.setAttribute("id", 'inlineeditTopicTML2HTML_'+newSectionID)

        var topicInfo=originatingTopicSectionObject.topicinfoSrc;

//TODO: have to modify this topicInfo before we evaluate it

        var topicSectionObject = eval('('+topicInfo+')');
        topicSectionObject.topicSection = newSectionID;
        topicSectionObject.newSection = 1;  //don't give this section a Cancel button
        topicSectionObject.createdFromSectionName = originatingTopicSectionObject.sectionName;
        topicSectionObject.putSectionAbove = putSectionAbove;
        topicSectionObject.topicinfoSrc = topicInfo;
        topicSectionObject.HTMLdiv = htmldiv;
        topicSectionObject.HTMLdiv.topicSectionObject = topicSectionObject;

        topicSectionObject.HTMLdiv.TWikiInlineEditPluginonDblClickFunction = gotoEditModeFromEvent;
        XBrowserAddHandler(topicSectionObject.HTMLdiv, 'dblclick', 'TWikiInlineEditPluginonDblClickFunction');

        topicSectionObject.tml = newTml;
        topicSectionObject.TML2HTMLdiv = tml2htmldiv;
//        topicSectionObject.editDivSection = initialiseInlineEditDiv(topicSectionObject);

        //insert it..
        var topicSectionsArrayIndex;
        var hr=document.createElement('hr');
        if (putSectionAbove) {
            originatingTopicSectionObject.editDivSection.parentNode.insertBefore(topicSectionObject.HTMLdiv, originatingTopicSectionObject.editDivSection);
//            originatingTopicSectionObject.editDivSection.parentNode.insertBefore(hr, originatingTopicSectionObject.editDivSection);
            for (var i=0;i < topicSections.length;i++) {
                if (topicSections[i] == originatingTopicSectionObject) {
                    topicSectionsArrayIndex = i;
                    break;
                }
            }
        } else {
            var nextSibling = originatingTopicSectionObject.editDivSection.nextSibling.nextSibling
//            originatingTopicSectionObject.editDivSection.parentNode.insertBefore(hr, nextSibling);
            originatingTopicSectionObject.editDivSection.parentNode.insertBefore(topicSectionObject.HTMLdiv, nextSibling);
            for (var i=0;i < topicSections.length;i++) {
                if (topicSections[i] == originatingTopicSectionObject) {
                    topicSectionsArrayIndex = i+1;
                    break;
                }
            }
        }

        //topicSections.push(topicSectionObject);
        topicSections.splice(topicSectionsArrayIndex, 0, topicSectionObject);


//trigger a double click
var deferer = topicSectionObject.HTMLdiv;
if(document.createEvent){
var evt = document.createEvent("MouseEvents")
evt.initMouseEvent("dblclick",
false, //can bubble
true,
document.defaultView,
1,
findPosX(deferer), //screen x
findPosY(deferer), //screen y
findPosX(deferer), //client x
findPosY(deferer), //client y
false,
false,
false,
false,
1,
deferer);
topicSectionObject.HTMLdiv.dispatchEvent(evt);
}else{
var evt = document.createEventObject();
// Set an expando property on the event object. This will be used by the
// event handler to determine what element was clicked on.
evt.clientX = findPosX(deferer);
evt.clientY = findPosY(deferer);
topicSectionObject.HTMLdiv.fireEvent("ondblclick",evt);
evt.cancelBubble = true;
} 

    }
}

//hides all textareas and sends modified sections to twiki save
//TODO (3) send only diffs of modified sections
saveAllSections = function(event) {

    document.body.style.cursor = "wait";

    var data = '';
    var sectionOrderArray = [];
    for (var i in topicSections) {
        if (!topicSections[i].deleted) {
            sectionOrderArray.push(topicSections[i].topicSection);
            if (topicSections[i].modified) {
                data = data + topicSections[i].editSectionObject.getSaveData()+'####';
                topicSections[i].HTMLdiv.innerHTML = '<FONT color="red"><B>please Wait, sending your changes to the server.....</B></FONT><br />';
                hideEdit(topicSections[i]);
            }
        }
    }

        sectionOrder = sectionOrderArray.toJSONString();
        topicSectionalSaveUrl = topicSections[0].saveUrl;
        browserLogin = topicSections[0].browserLogin;

//TODO: change this so the parameters are initialised from the topicSectionalSaveUrl sent by the perl

    var callback = { 
	  success: function(o) {
	            var data = o.responseText;
                //protect against full html pages by only bringing in the body
                var startBodyTag = data.indexOf('<body');
                if (startBodyTag == -1) {
                    startBodyTag = data.indexOf('<BODY');
                }
                if (startBodyTag > -1) {
                    startBodyTag = data.indexOf('>', startBodyTag);
    
                    var endBodyTag = data.indexOf('</body');
                    if (endBodyTag == -1) {
                        endBodyTag = data.indexOf('</BODY');
                    }
                    if (endBodyTag > -1) {
                        data = data.substring(startBodyTag+1, endBodyTag-1);
                    }
                    document.body.style.cursor = "default";
                    window.location.reload();
                }
                data = '<div>' + data + '</div>';
                document.body.style.cursor = "default";
                window.location.reload();
	      }, 
	  failure: function(o) {alert('Error!\nStatusText='+o.statusText+'\nContents='+o.responseText);}
        ,argument: ['svenwashere'] 
	};
    //have to URI encode the data - to allow + signs in topic text..
	var postParams = 'replywitherrors=1;dataType=JSON;data='+encodeURIComponent(data)+';inlineeditsave=1;originalrev='+topicSections[0].topicRev+';sectionOrder='+sectionOrder+';forcenewrevision=1;username='+browserLogin;
	var transaction = YAHOO.util.Connect.asyncRequest('POST', topicSectionalSaveUrl, callback, postParams); 
}

cancelEditMode = function(event) {
    var topicSectionObject = getTopicSectionObject(event);
    hideEdit(topicSectionObject);
    topicSectionObject.modified = 0;
    topicSectionObject.deleted = 0;
}

saveEditMode = function(event) {
    saveAllSections();
}

//
deleteSection = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;          //tg should be a button
    var topicSectionObject = getTopicSectionObject(event);

    if (topicSectionObject.deleted) {
        topicSectionObject.deleted = 0;
        tg.value = 'Delete';
		topicSectionObject.editSectionObject.disableEdit(false);
        //topicSectionObject.editDivSection.elements.namedItem("text").disabled = false;
    } else {
        topicSectionObject.deleted = 1;
        tg.value = 'unDelete';
		topicSectionObject.editSectionObject.disableEdit(true);
        //topicSectionObject.editDivSection.elements.namedItem("text").disabled = true;
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Support Funcs

//from http://tuckey.org/textareasizer/
function countLines(strtocount, cols) {
    if (typeof(strtocount) == "undefined")
        return 0;
    if (strtocount == "")
        return 0;
    var hard_lines = 1;
    var last = 0;
    while ( true ) {
        last = strtocount.indexOf("\n", last+1);
        hard_lines ++;
        if ( last == -1 ) break;
    }
    var soft_lines = Math.round(strtocount.length / (cols-1));
    var hard = eval("hard_lines  " + unescape("%3e") + "soft_lines;");
    if ( hard ) soft_lines = hard_lines;
    return soft_lines;
}

//traverses downwards through parents to find the topicSectionObject
getTopicSectionObject = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;
    var p = tg;
    var topicSectionObject;
    while (( typeof( topicSectionObject ) == "undefined" ) && ( typeof( p ) != "undefined" )) {
        topicSectionObject = p.topicSectionObject;
        p = p.parentNode;
    }
    return topicSectionObject;
}

makeFormButton = function(id, value, onclick, disabled) {
    var text = '<input type="button"  ';
    if (onclick) {
        text = text + 'onclick="'+onclick+'" ';
    }
    text = text + 'name="action_'+id+'" id="'+id+'" ';
    text = text + 'value="'+value+'" ';
    if (disabled == 1) {
        text = text + ' disabled="TRUE"' +'class="twikiSubmitDisabled" ';
    } else {
        text = text + 'class="twikiSubmit" ';
    }
    text = text + ' />';

    return text;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//http://www.quirksmode.org/js/findpos.html
function findPosX(obj)
{
    var curleft = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
            curleft += obj.offsetLeft
            obj = obj.offsetParent;
        }
    }
    else if (obj.x)
        curleft += obj.x;
    return curleft;
}

//http://www.quirksmode.org/js/findpos.html
function findPosY(obj)
{
    var curtop = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
            curtop += obj.offsetTop
            obj = obj.offsetParent;
        }
    }
    else if (obj.y)
        curtop += obj.y;
    return curtop;
}

//from http://onlinetools.org/articles/unobtrusivejavascript/cssjsseparation.html
function jscss(a,o,c1,c2)
{
  switch (a){
    case 'swap':
      o.className=!jscss('check',o,c1)?o.className.replace(c2,c1):o.className.replace(c1,c2);
    break;
    case 'add':
      if(!jscss('check',o,c1)){o.className+=o.className?' '+c1:c1;}
    break;
    case 'remove':
      var rep=o.className.match(' '+c1)?' '+c1:c1;
      o.className=o.className.replace(rep,'');
    break;
    case 'check':
      return new RegExp('\\b'+c1+'\\b').test(o.className)
    break;
  }
}


