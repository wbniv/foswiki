/*  
	Extension:	TWiki formatting toolbar and context menu for Mozilla based browsers
	Author: 	The TWiki Community, http://twiki.org
	Based on:	wikipedia extension of Bananeweizen, http://www.bananeweizen.de
*/

var wbPrefs=null;
var twiki_stringBundle;
var twiki_Document = null;
var scrollTop;
var scrollHeight;
var currentBox;
var menuCreated=false;

var twiki = {
    init: function() {
	twiki_setupDocument(document);
	//		twiki.checkLabelVisibility();
	try{
	    var menu = document.getElementById('contentAreaContextMenu');
	    menu.addEventListener('popupshowing', twiki.showHide, false);
	}catch (e){
	    //Foobar!
	}
    },
	
    showHide: function() {
	var kind=0;
	var activate=true;
	var condition= "edit";
	try {
	    wbPrefs=getPreferences();
	    kind=wbPrefs.getIntPref("activation.kind");
	    condition=wbPrefs.getCharPref("activation.condition");
	    if (kind==1) {
		activate=(window.content.location.toString().indexOf(condition)>=0);
	    }
	}
	catch (e) {
	}
	// load dynamic menu on first showing
	if (activate) {
	    generateMenuTemplates();
	}
//	document.getElementById('context-twiki').hidden = document.getElementById('context-undo').hidden || !activate;
//  if the option to make the toolbar context sensitive has been selected, then the following line will make the toolbar appear/disappear according to context when the right-hand
// mouse button is clicked, i.e. when the context menu is triggered. original line is above.
//	document.getElementById('context-twiki').hidden = document.getElementById('twiki-toolbar').collapsed = document.getElementById('context-undo').hidden || !activate;
	document.getElementById('context-twiki').hidden = document.getElementById('context-undo').hidden || !activate;
	document.getElementById('twiki-toolbar').collapsed = !activate;
// the above pair of lines functions like the single line which precedes them.
    },

// getClipboard does not seem to be referenced anywhere in this app - left over from wikipedia?
    getClipboard: function() {
	var clip = Components.classes["@mozilla.org/widget/clipboard;1"].createInstance(Components.interfaces.nsIClipboard);
	if (!clip){
	    return "";
	}
		
	var trans = Components.classes["@mozilla.org/widget/transferable;1"].createInstance(Components.interfaces.nsITransferable);
	if (!trans){
	    return "";
	}

	trans.addDataFlavor("text/unicode");
	clip.getData(trans,clip.kGlobalClipboard);

	var str_clipboard=new Object();
	var strLength=new Object();
	try{
	    trans.getTransferData("text/unicode",str_clipboard,strLength);
	    if (str_clipboard){
		str_clipboard=str_clipboard.value.QueryInterface(Components.interfaces.nsISupportsString);
	    }
	}catch (e){
	    //alert("No text in the clipboard, please copy something first.");
	}
	return str_clipboard;
    },
	
    getSelection: function() {
	currentBox = document.commandDispatcher.focusedElement;
	scrollTop = currentBox.scrollTop;
	scrollHeight = currentBox.scrollHeight;
	//Get Selected text (if selected)
	var selStartPos = currentBox.selectionStart;
	var selEndPos = currentBox.selectionEnd;
	str = currentBox.value.substring(selStartPos, selEndPos);
	return str;
    },

// the following function is not yet implemented - it is intended for future use
    getSelectionOrLine: function() {
	currentBox = document.commandDispatcher.focusedElement;
	scrollTop = currentBox.scrollTop;
	scrollHeight = currentBox.scrollHeight;
//alert( "scrollTop="+scrollTop+", scrollHeight="+scrollHeight );

	//Get Selected text (if selected)
	var selStartPos = currentBox.selectionStart;
	var selEndPos = currentBox.selectionEnd;
//alert( "selStartPos="+selStartPos+", selEndPos="+selEndPos );
//var next=currentBox.value.substr(selStartPos, 1);
//alert( "next letter="+next );
	// if text selected, return it...
	if (selStartPos!=selEndPos) {
		selected = currentBox.value.substring(selStartPos, selEndPos);	
		return selected;
	}
	// if no text selected, return all of current line...
	var start=selStartPos;
	if (currentBox.value.substr(start, 1)=='\n') {
		start--;		// special treatment if cursor is at end of line - this will probably give problems if current line is empty
					// in that case, shld probably return nothing, then perhaps do forced selection, or put up alert (options?)
		if (currentBox.value.substr(start, 1)=='\n') {
			empty = "";	
			return empty;	// special treatment if line is empty - return nothing
		}
	}
	while ((start>=0) && (currentBox.value.substr(start, 1)!='\n')) {
		start --;
	}
	var end=selEndPos;
	while ((end>=0) && (currentBox.value.substr(end, 1)!='\n')) {
		end ++;
	}
//alert( "start="+start+", end="+end );
	var currentLine=currentBox.value.substring(start+1, end);
//alert( "current line="+line );
	return currentLine;
// probably need to reset values of currentBox.selectionStart, currentBox.selectionEnd, so as to reinsert processed text in right place
    },

    getSelectionAll: function() {
	currentBox.setSelectionRange(0,currentBox.value.length-1);
	return twiki.getSelection();
    },
	
    getForcedSelection: function(format) {
	var str = twiki.getSelection();
	if (str==null || str=="") {
	    str=twiki.getInput("twiki.input."+format);
	}
	return str;
    },

    insert: function(someText) {
	twiki.getSelection();
	twiki.insertAtCursor(someText);
    },
    	
    surroundBlock: function(format, left, right) {
	var target=twiki.getForcedSelection(format);
	target=left+target+right
	twiki.insertAtCursor(target);
    },
    	
    surround: function(format, left, right) {
	var rightStr=twiki.getForcedSelection(format);
	var leftStr="";
	var str="";
	var n=0;
	var leftTrim="";
	var rightTrim=""
	while (rightStr.length>0) {
	    n=0;
	    while (rightStr.substring(0,1) == '\n') {
		leftStr=leftStr+'\n';
		rightStr=rightStr.substring(1,rightStr.length);
	    }
	    while ((n<rightStr.length) && (rightStr.substring(n,n+1) != '\n')) {
		n++;
	    }
	    str=rightStr.substring(0,n);
	    rightStr=rightStr.substring(n,rightStr.length);
	    leftTrim="";
	    while ((str.length>0) && (str.substring(0,1) == ' ')) {
		leftTrim=leftTrim+" ";
		str=str.substring(1,str.length);
	    }
	    rightTrim="";
	    while ((str.length>0) && (str.substring(str.length-1,str.length) == ' ')) {
		rightTrim=rightTrim+" ";
		str=str.substring(0,str.length-1);
	    }

	    if (str.length>0) {
		leftStr=leftStr+leftTrim+left+str+right+rightTrim;
	    }
	    else {
		leftStr=leftStr+leftTrim+rightTrim;
	    }
	}
	twiki.insertAtCursor(leftStr);
    },
	
    bold: function() {
	twiki.surround('bold', '*', '*');
    },

    bolditalic: function() {
	twiki.surround('bolditalic', '__', '__');
    },

    italic: function() {
	twiki.surround('italic', '_', '_');
    },

    underline: function() {
	twiki.surround('underline','<u>','</u>');
    },

    strike: function() {
	twiki.surround('strike','<strike>','</strike>');
    },

    fixed: function() {
	twiki.surround('fixed','=','=');
    },

    boldfixed: function() {
	twiki.surround('boldfixed','==','==');
    },

    pre: function() {
	twiki.surroundBlock('pre','\n<pre>\n','\n</pre>\n');
    },
    
    verbatim: function() {
	twiki.surroundBlock('verbatim','\n<verbatim>\n','\n</verbatim>\n');
    },
	
    red: function() {
	twiki.surround('red', '%RED% ', ' %ENDCOLOR%');
    },

    blue: function() {
	twiki.surround('blue', '%BLUE% ', ' %ENDCOLOR%');
    },

    green: function() {
	twiki.surround('green', '%GREEN% ', ' %ENDCOLOR%');
    },

    wikify: function( str ) {
	apostrophe=/\'/g;		// apostrophe
	nonWord=/\W/g;		        // not alphanumeric
	str=str.replace(apostrophe,"");	// remove apstrophes
	str=str.replace(nonWord," ");	// replace non-word chars
	var words=str.split( " " ) ;
	var wikiword="";
	for (var i=0; i < words.length; i++) {
	    var firstChar=words[i].substr(0,1);
	    firstChar=firstChar.toUpperCase();
	    var rest=words[i].substr(1);
	    rest=rest.toLowerCase();
	    wikiword=wikiword+firstChar+rest;
        }
	if (wikiword.length==0) {
	    wikiword="Garbage in, garbage out!";
	    return wikiword;
	} 
	if (words.length==1) {
	    wikiword=wikiword+"Page";
	} 
	return wikiword;
    },
    
    insertAnchor: function(borderLeft, borderRight, separator) {
	var str=twiki.getForcedSelection('anchor');
        var ok = [false];
        var left=blankLeft(str);
        var right=blankRight(str);
	str=twiki.trim(str);
	if (str.length==0) {
	    return;		// nothing to do
	}
	var wikiword=twiki.wikify( str ) ;
	var params = [wikiword,str,0,0,0,0,0,0];
	var prefix="";
        window.openDialog("chrome://twiki/content/anchor.xul", "WikiAnchor","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var target=twiki.trim(params[0]);
	    var label=twiki.trim(params[1]);
	    if (target.length==0) {
	        return;		// nothing to do
	    }
	    var headlevel=params[2];
	    var prefix="";
	    if (headlevel>0) {
	    	var prefix="---";
	    }		
	    while (headlevel>0) {
	        prefix=prefix+"+";
		headlevel--;
            }
//    	    prefix=prefix+" ";    

	    var link=borderLeft+target;
	    if (label!="") {
		link=link+separator+prefix+label;
	    }
	    link=link+borderRight;
	    twiki.insertAtCursor(left+link+right);
        }
    },

    anchor: function() {
	twiki.insertAnchor("\n#", "", "\n");
    },

    makeWikiWord: function() {
	var str=twiki.getForcedSelection('makeWikiWord');
        var left=blankLeft(str);
        var right=blankRight(str);
	str=twiki.trim(str);
	if (str.length==0) {
	    return;		// nothing to do
	}
	var wikiword=twiki.wikify(str);
	twiki.insertAtCursor(left+wikiword+right);
    },
    
    paragraph: function(format,markup) {
	var str=twiki.trim(twiki.getForcedSelection(format));
	twiki.insertAtCursor("\n" + markup + " " + str + "\n");
    },
	
    changeParagraphs: function(change) {
	var str=twiki.getSelection();
	if (str=="") {
	    str=twiki.getSelectionAll();
	}
	var lines=str.split("\n");
	var insert="";
	for (i=0;i<lines.length;i=i+1) {
	    var line=lines[i];
	    if (line.indexOf("---+")==0) {
		if (change==1) {
		    line = line.replace(new RegExp ('^---(\\++)', 'gi'), '---+$1') ;
		}
		else {
		    line = line.replace(new RegExp ('^---\\+(\\++)', 'gi'), '---$1') ;
		}
	    }
	    if (i>0) {
		insert=insert+"\n";
	    }
	    insert=insert+line;
	}
	twiki.insertAtCursor(insert);
    },

    insertSignature: function() {
	var trailing="";
	twiki.getSelection();
	var selStartPos = currentBox.selectionStart;
	if (selStartPos>0) {
	    var before = currentBox.value.substring(selStartPos-1, selStartPos);
	    if ((before!=' ') && (before!='\n')) {
		trailing=" ";
	    }
	}
	twiki.insert(trailing+'--~~~~');
    },
  
    insertAtCursor: function(aText) {
	try {
	    var command = "cmd_insertText";
	    var controller = document.commandDispatcher.getControllerForCommand(command);
	    if (controller && controller.isCommandEnabled(command)) {
		controller = controller.QueryInterface(Components.interfaces.nsICommandController);
		var params = Components.classes["@mozilla.org/embedcomp/command-params;1"];
		params = params.createInstance(Components.interfaces.nsICommandParams);
		params.setStringValue("state_data", aText);
		controller.doCommandWithParams(command, params);
				
		//restore position
		var nHeight = currentBox.scrollHeight - scrollHeight;
		currentBox.scrollTop = scrollTop + nHeight;
	    }
	}catch (e) {
	    dump("Can't do cmd_insertText! ");
	    dump(e+"\n")
	}
    },

// insert heading using heading.xul based on list.xul
    insertHeadingFancy: function() {
        var ok = [false];
//        var params = ["",listSign,0,0,0,0,0,0];
//        window.openDialog("chrome://twiki/content/link.xul", "WikiLink","chrome,modal,centerscreen",ok,params);
//        var params = [imageName,imageDesc,true,false,false,false,0,false,false,false,0,0,0,0,0,0,0,0,0];
///        var params = ["",listSign,true,false,false,false,false,0,false];
///        window.openDialog("chrome://twiki/content/list.xul", "WikiList","chrome,modal,centerscreen",ok,params);
//        var params = [false,0,0,false,false,false,0,0,0,0,0,0,0,0,0];
        var params = ["",false,false,false,false,false,false,0,0,false,false,false,0,0,0,0,0,0,0,0,0];
        window.openDialog("chrome://twiki/content/heading.xul", "WikiHeading","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var headinglevel=params[0]+1;	
	    var prefix="---";
	    while (headinglevel>0) {
	        prefix=prefix+"+";
		headinglevel--;
            }
    	    prefix=prefix+" ";
	    twiki.surround('heading', prefix, '');
	}
    },

// insertlist using list.xul based on image.xul
    insertListFancy: function(listSign) {
        var ok = [false];
//        var params = ["",listSign,0,0,0,0,0,0];
//        window.openDialog("chrome://twiki/content/link.xul", "WikiLink","chrome,modal,centerscreen",ok,params);
//        var params = [imageName,imageDesc,true,false,false,false,0,false,false,false,0,0,0,0,0,0,0,0,0];
///        var params = ["",listSign,true,false,false,false,false,0,false];
///        window.openDialog("chrome://twiki/content/list.xul", "WikiList","chrome,modal,centerscreen",ok,params);
        var params = ["",false,false,false,false,false,false,0,0,false,false,false,0,0,0,0,0,0,0,0,0];
        window.openDialog("chrome://twiki/content/list.xul", "WikiList","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var file=twiki.trim(params[0]);
	    var bulleted=params[1];		// asterisk
	    var arabic=params[2];		// 1.
	    var letterA=params[3];		// A.
	    var lettera=params[4];		//a.
	    var romanI=params[5];		//I.
	    var romani=params[6];		//i.
	    var pixels=params[7];
	    var alignment=params[8];
////	    var pixels=params[6];
////	    var alignment=params[7];

	    if (bulleted) {
		listType="*";
	    }
	    else if (arabic) {
		listType="1.";
	    }
	    else if (letterA) {
		listType="A.";
	    }
	    else if (lettera) {
		listType="a.";
	    }
	    else if (romanI) {
		listType="I.";
	    }
	    else if (romani) {
		listType="i.";
	    }
	    var nestlevel=alignment+1;
	    var prefix="";
	    while (nestlevel>0) {
	        prefix=prefix+"   ";
		nestlevel--;
            }
    	    prefix=prefix + listType + " ";
	    twiki.surround('list', prefix, '');
	}
    },

// basic insert list
// this works well enough, but wld be better if it (a) extended start of selection to start of relevant line, (b) wld work on empty selections
    insertList: function(listSign) {
    	var prefix="   " + listSign + " ";
	twiki.surround('list', prefix, '');
    },

/*
// original insert list
    insertList: function(listSign) {
	var str=twiki.getSelection();
	var lines=str.split("\n");
	var insert="";
	for (i=0;i<lines.length;i=i+1) {
	    if (i>0) {
		insert = insert + "\n";
	    }
	    if (twiki.trim(lines[i])!="") {
		insert = insert + "   " + listSign + " " + lines[i];
	    }
	}
	for (i=lines.length;i<3;i=i+1) {
	    insert = insert + "\n" + "   " + listSign + " ";
	}
	twiki.insertAtCursor(insert);
    },
*/

    insertDefinitionList: function() {
	var topic=twiki.getString("twiki.default.definitiontopic");
	var definition=twiki.getString("twiki.default.definitiondescription");
	var def = "   $ " + topic + ": " + definition + "\n";
	twiki.insertAtCursor(def+def);
    },

    indentMore: function() {
	var target=twiki.getSelection();
	target="\n"+target;					// eliminate special case of 1st line
	indent=/\n   /g;
	target=target.replace(indent, "\n      ");		// increase 3 leading spaces to 6
	overIndent=/(\n {18}) +/g;
	target=target.replace(overIndent, "$1");		// reduce super-maximal indents to permissable maximum of 6 indents (18 spaces)
	target=target.substr(1);				// reinstate 1st line
	twiki.insertAtCursor(target);
    },
    
    indentLess: function() {
	var target=twiki.getSelection();
	target="\n"+target;					// eliminate special case of 1st line
	indent=/\n      /g;
	target=target.replace(indent, "\n   ");			// reduce 6 leading spaces to 3
	target=target.substr(1);				// reinstate 1st line
	twiki.insertAtCursor(target);
    },
        	
    removeList: function() {
	var target=twiki.getSelection();
	target="\n"+target;					// eliminate special case of 1st line
	bullet=/\n  *\* /g;
	arabic=/\n  *1\. /g;
	letterA=/\n  *A\. /g;
	lettera=/\n  *a\. /g;
	romanI=/\n  *I\. /g;
	romani=/\n  *i\. /g;
	target=target.replace(bullet, "\n");
	target=target.replace(arabic, "\n");
	target=target.replace(letterA, "\n");
	target=target.replace(lettera, "\n");
	target=target.replace(romanI, "\n");
	target=target.replace(romani, "\n");
	target=target.substr(1);				// reinstate 1st line
	twiki.insertAtCursor(target);
    },

/*  
// original remove list	
    removeList: function() {
	var lines=twiki.getSelection().split("\n");
	for (i=0;i<lines.length;i=i+1) {
	    if (lines[i].length>0) {
		if ("   * " == lines[i].substring(0,5)) {
		    lines[i]=lines[i].substr(5,lines[i].length-5);
		} else if ("   1. " == lines[i].substring(0,6)) {
		    lines[i]=lines[i].substr(6,lines[i].length-6);
		}
	    }
	}
	var insert=lines[0];
	for (i=1;i<lines.length;i=i+1) {
	    insert=insert+"\n"+lines[i];
	}
	twiki.insertAtCursor(insert);
    },
*/
	
    insertTable: function() {
	var str=twiki.getSelection();
        var ok = [false];
        var params = [0,0,twiki.trim(str),false,false,0,0,0,0,0,0];
        window.openDialog("chrome://twiki/content/table.xul", "WikiTable","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var rows=Math.round(params[0]);
	    var columns=Math.round(params[1]);
	    var content=params[2];
	    var usePlugin=params[3];
	    var border=params[4];
	    var headline=params[5];
	    var caption=twiki.trim(params[6]);
	    var alignment=params[7];
	    var color=params[8];
       	
	    if (headline) {
		rows=1+rows;
	    }
	    var table="";
	    if (usePlugin) {
		// TODO: The TablePlugin attributes need to be implemented. (usePlugin is disabled in twikiOverlay.xul)
        	if (border) {
		    table=table+" border=1";
        	}
        	switch (alignment) {
		case 1: 
		    table=table+" align=left";
		    break;
		case 2: 
		    table=table+" align=center";
		    break;
		case 3: 
		    table=table+" align=right";
		    break;
        	}
        	table=table+"\n";
        	if (caption!="") {
		    table=table+"|+"+caption+"\n";
        	}
	    }
	    for (r=0;r<rows;r=r+1) {
		var cellStart="|";
		//        		if (headline && (r==0)) {
		//        			cellStart="!";
		//        		}
		for (c=0;c<columns;c=c+1) {
		    table=table+cellStart+content;
		}
		table=table+"|\n";
	    }
	    table=table+"\n";
	    twiki.insertAtCursor(table);
        }
    },
	
    insertImage: function() {
	var str=twiki.trim(twiki.getSelection());
        var ok = [false];
        // use selected string as either image name or description
        var imageName="";
        var imageDesc="";
        if (str.indexOf(".")>=0) {
	    imageName=str;
        }
        else {
	    imageDesc=str;
        }
        // call dialog
//        var params = [imageName,imageDesc,true,false,false,false,0,false,false,false,0,0,0,0,0,0,0,0,0];
// following is an experiment to see if the dialog works just as well with only the 8 params which are actually referenced in the code. previopus line is the original
        var params = [imageName,imageDesc,true,false,false,false,0,false];
        window.openDialog("chrome://twiki/content/image.xul", "WikiImage","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var file=twiki.trim(params[0]);
	    var description=twiki.trim(params[1]);
	    var thumb=params[2];
	    var thumbsized=params[3];
	    var framed=params[4];
	    var full=params[5];
	    var pixels=params[6];
	    var alignment=params[7];
	    var image="<img src=\"" + file + "\"";
	    if (framed) {
		image=image + " border=\"1\"";
	    }
	    else if (thumb) {
		//        		image=image+"|thumb";
	    }
	    else if (thumbsized) {
		//        		image=image+"|thumb|"+pixels+"px";
	    }
	    switch (alignment) {
	    case 1: 
		image=image + " align=\"left\"";
		break;
	    case 2:
		//	        		image=image+"|none";
		break;
	    case 3:
		image=image + " align=\"right\"";
		break;
	    }
	    image = image + " alt=\"" + description + "\"";
	    image = image + " />"
        	if (alignment==2) {
		    image="<center>"+image+"</center>";
        	}
	    twiki.insertAtCursor(image);
        }
    },

    insertLink: function(borderLeft, borderRight, separator) {
	var str=twiki.getSelection();
        var ok = [false];
        var left=blankLeft(str);
        var right=blankRight(str);
	str=twiki.trim(str);
        var params = [str,"",0,0,0,0,0,0];
        window.openDialog("chrome://twiki/content/link.xul", "WikiLink","chrome,modal,centerscreen",ok,params);
        if (ok[0]){
	    var target=twiki.trim(params[0]);
	    var label=twiki.trim(params[1]);
	    if (target.length==0) {
	        return;		// nothing to do
	    }
	    var link=borderLeft+target;
	    if (label!="") {
		link=link+separator+label;
	    }
	    link=link+borderRight;
	    var headlevel=params[2];
	    var prefix="";
	    if (headlevel>0) {
	    	var prefix="---";
	    }		
	    while (headlevel>0) {
	        prefix=prefix+"+";
		headlevel--;
            }
//    	    prefix=prefix+" ";
	    left=prefix+left;

	    twiki.insertAtCursor(left+link+right);
        }
    },
	
    trim: function(s) {
	if (s==null || s=="") {
	    return "";
	}
	while (s.substring(0,1) == ' ') {
	    s = s.substring(1,s.length);
	}
	while (s.substring(s.length-1,s.length) == ' ') {
	    s = s.substring(0,s.length-1);
	}
	return s;
    },

    insertForcedLink: function() {
	twiki.insertLink("[[", "]]", "][");
    },
	
// // checkLabelVisibility is inactivated - see init - presumably left over from wikipedia toolbar
    checkLabelVisibility: function() {
	/*	
	  var element = document.getElementById("LabelsButtonItem");
	  alert(element);
	  alert(element.getAttribute("checked"));
	  if (element.getAttribute("checked") == "true") {
	  twiki.toolbarLabelsOn();
	  }
	  else {
	  twiki.toolbarLabelsOff();
	  }
	*/
    },
	
// toolbarLabelsOn is inactivated - see checkLabelVisibility
    toolbarLabelsOn: function()
    {
	var container = document.getElementById("twiki-buttons");
	var containerButtons = container.getElementsByTagName("toolbarbutton");
	for (var i = 0; i < containerButtons.length; i++) {
	    containerButtons[i].setAttribute("label", containerButtons[i].getAttribute("buttonlabel"));
	    updateElementClass(containerButtons[i], 0, "button-labeled");
	}
    },
	
// toolbarLabelsOff is inactivated - see checkLabelVisibility
    toolbarLabelsOff: function()
    {
	var container = document.getElementById("twiki-buttons");
	var containerButtons = container.getElementsByTagName("toolbarbutton");
	for (var i = 0; i < containerButtons.length; i++) {
	    containerButtons[i].removeAttribute("label");
	    updateElementClass(containerButtons[i], 0, containerButtons[i].getAttribute("buttonclass"));
	}
    },

// getUsername is not referenced in this application - presumably left over from wikipedia toolbar
    getUsername: function() {
	var username="";
	try {
	    username=getPreferences().getCharPref("username");
	}
	catch(e) {
	}
	if (username=="") {
	    alert(twiki.getString("twiki.settings.username.undefined"));
	    twiki.toolbarOptions();
	}
	return getPreferences().getCharPref("username");		
    },
	
// setLocation is not referenced in this script, but is referenced in twikiOverlay.xul. The case 'twiki' seems to be unused - presumably left over from wikipedia toolbar
    setLocation: function(name) {
	var url="";
	switch (name) {
	case 'twiki':
	    url='twiki.org';
	    break;
	case 'toolbar':
	    url='twiki.org/cgi-bin/view/Plugins/FirefoxExtensionAddOn';
	    break;
	}
	if (url!="") {
	    window._content.document.location='http://'+url;
	}
    },

	
    toolbarOptions: function() {
	var ok = [false];
	var params = [];
	window.openDialog("chrome://twiki/content/prefDialog.xul", "WikiOptions","chrome,modal,centerscreen",ok,params);
    },
	
    initOptions: function() {
	var option_activation_kind="activation.kind";
	var option_activation_condition="activation.condition";
	var option_twiki_language="language";
	var language="en";
	language=twiki.getString("twiki.language");
	var prefService = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService);
	wbPrefs = prefService.getBranch("twiki."); // preferences twiki node
	try{
	    try {
		wbPrefs.getIntPref(option_activation_kind);
	    }
	    catch (e) {
		wbPrefs.setIntPref(option_activation_kind,0);
	    }
	    try {
		wbPrefs.getCharPref(option_activation_condition);
	    }
	    catch (e) {
		wbPrefs.setCharPref(option_activation_condition, "edit");
	    }
	    try {
		wbPrefs.getCharPref(option_twiki_language);
	    }
	    catch (e) {
		wbPrefs.setCharPref(option_twiki_language,language);
	    }
	    try {
		wbPrefs.getCharPref("username");
	    }
	    catch (e) {
		wbPrefs.setCharPref("username","");
	    }
	} catch (e){
	    dump(e);
	}           
    },
	
    getString:function(name) {
	if (twiki_stringBundle==null) {
	    twiki_stringBundle = document.getElementById("twikistrings");
	}
	return twiki_stringBundle.getString(name);
    },
	
    getInput: function(textId) {
	var dialogText=twiki.getString(textId);
	var newtext = prompt(dialogText);
	return newtext;
    },
}

function blankLeft(s) {
	if (s==null || s=="") {
		return "";
	}
	var r="";
	while (s.substring(0,1) == ' ') {
		r=r+s.substring(0,1);
		s = s.substring(1,s.length);
	}
	return r;
}

function blankRight(s) {
	if (s==null || s=="") {
		return "";
	}
	var r="";
	while (s.substring(s.length-1,s.length) == ' ') {
		r = s.substring(s.length-1,s.length);
		s = s.substring(0,s.length-1);
	}
	return r;
}

function getPreferences() {
	if (!wbPrefs) {
		try {
			twiki.initOptions();
			var prefService = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService);
			wbPrefs = prefService.getBranch("twiki."); // preferences twiki node
		} catch (e) {
			alert(e);
		}
	}
	return wbPrefs;
}
//May not be needed, but just in case.
function twiki_setupDocument(aDoc)
{
	twiki_Document = aDoc;
	twiki_stringBundle = aDoc.getElementById("twikistrings");
}

function readFile(str_Filename)
{
	try{
		var obj_File = Components.classes["@mozilla.org/file/local;1"].createInstance(Components.interfaces.nsILocalFile);
		obj_File.initWithPath(str_Filename);
		
		var obj_InputStream = Components.classes["@mozilla.org/network/file-input-stream;1"].createInstance(Components.interfaces.nsIFileInputStream);
		obj_InputStream.init(obj_File,0x01,0444,null);
		
		var obj_ScriptableIO = Components.classes["@mozilla.org/scriptableinputstream;1"].createInstance(Components.interfaces.nsIScriptableInputStream);
		obj_ScriptableIO.init(obj_InputStream);
	} catch (e) {
		alert(e);
	}
	
	try {
		var str = obj_ScriptableIO.read(obj_File.fileSize-1);
	} catch (e) {
		dump(e);
	}
	
	obj_ScriptableIO.close();
	obj_InputStream.close();
	return str;
}

function getContentsFromURL(aURL){
	var ioService=Components.classes["@mozilla.org/network/io-service;1"].getService(Components.interfaces.nsIIOService);
	var scriptableStream=Components.classes["@mozilla.org/scriptableinputstream;1"].getService(Components.interfaces.nsIScriptableInputStream);
	
	var channel=ioService.newChannel(aURL,null,null);
	var input=channel.open();
	scriptableStream.init(input);
	var str=scriptableStream.read(input.available());
	scriptableStream.close();
	input.close();
	return str;
}

function generateMenuTemplates(){
	if (false==menuCreated) {
		try {
			var d = document;
			var popup1 = d.getElementById('popupTemplates1');
			var popup2 = d.getElementById('popupTemplates2');
			var content = getContentsFromURL("chrome://twiki/locale/templates.xml");
			
			var uConv = Components.classes['@mozilla.org/intl/scriptableunicodeconverter'].createInstance(Components.interfaces.nsIScriptableUnicodeConverter);
			uConv.charset = "UTF-8";
			var content = uConv.ConvertToUnicode(content);
			
			var parser = new DOMParser();
			var domtree = parser.parseFromString(content, "text/xml");
			var nodes = document.evaluate("/templates/template",domtree,null,0,null);
			var nodelist = new Array();
			var xpathnode = nodes.iterateNext();
			while (xpathnode) {
				nodelist.push(xpathnode);
				xpathnode = nodes.iterateNext();
			}
			for(var i=0; i < nodelist.length; i++) {
				node=nodelist[i];
				var label = document.evaluate("label/text()",node,null,0,null);
				label = label.iterateNext().nodeValue;
				var insert = document.evaluate("insert/text()",node,null,0,null);
				insert = insert.iterateNext().nodeValue;
				var tooltip = document.evaluate("tooltip/text()",node,null,0,null);
				tooltip = tooltip.iterateNext().nodeValue;
		
				var newElement = d.createElement('menuitem');
				newElement.setAttribute('id', 'template'+i);
				newElement.setAttribute('label', label);
				newElement.setAttribute('oncommand', 'twiki.insert(\''+insert+'\')');
				newElement.setAttribute('tooltiptext', tooltip);
				popup1.appendChild(newElement);
				var newElement = d.createElement('menuitem');
				newElement.setAttribute('id', 'template'+i);
				newElement.setAttribute('label', label);
				newElement.setAttribute('oncommand', 'twiki.insert(\''+insert+'\')');
				newElement.setAttribute('tooltiptext', tooltip);
				popup2.appendChild(newElement);
			}

			var popup = d.getElementById('popupQuotations');
			var content = getContentsFromURL("chrome://twiki/locale/quotations.xml");
			var parser = new DOMParser();
			var domtree = parser.parseFromString(content, "text/xml");
			var nodes = document.evaluate("/quotations/quotation",domtree,null,0,null);
			var nodelist = new Array();
			var xpathnode = nodes.iterateNext();
			while (xpathnode) {
				nodelist.push(xpathnode);
				xpathnode = nodes.iterateNext();
			}
			for(var i=0; i < nodelist.length; i++) {
				node=nodelist[i];

				var label = document.evaluate("label/text()",node,null,0,null);
				label = label.iterateNext().nodeValue;
				var marks = document.evaluate("left/text()",node,null,2,null);
/*				
				alert(marks);
				marks = marks.iterateNext().nodeValue;
				alert(marks);
		
				var newElement = d.createElement('menuitem');
				newElement.setAttribute('id', 'quotation'+i);
				newElement.setAttribute('label', label);
				newElement.setAttribute('oncommand', 'twiki.insert(\''+marks+'\')');
				popup.appendChild(newElement);
*/				
			}

		} catch (e) {
			dump(e);
		}
		menuCreated=true;
	}
	return true;
}

//Make sure twiki loads on start-up of browser.
window.addEventListener('load', twiki.init, false);
