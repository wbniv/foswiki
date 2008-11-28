/*
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

//create the TWiki namespace if needed
if ( typeof( TWiki ) == "undefined" ) {
    TWiki = {};
}

/**********************************************************************************/
//create the TWiki.ComponentEditPlugin namespace if needed
if ( typeof( TWiki.ComponentEditPlugin ) == "undefined" ) {
    TWiki.ComponentEditPlugin = {};
}

//used to add a ComponentEdit Click handler to document
TWiki.ComponentEditPlugin.addComponentEditClick = function(body) {
    body.TWikiComponentEditPluginonClickFunction = TWiki.ComponentEditPlugin.onClickFunction;
    XBrowserAddHandler(body, 'click', 'TWikiComponentEditPluginonClickFunction');

    //TODO: make keypress see if its within a TMLVariable area and pop up cleverness
//    this.current_mode.get_edit_document().addEventListener('keypress', function(e) {var tg = (e.target) ? e.target : e.srcElement;alert(tg);}, false);
}

TWiki.ComponentEditPlugin.onClickFunction = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;
    if (tg.className=='TMLvariable') {
        TWiki.ComponentEditPlugin.sourceTarget = tg;
        TWiki.ComponentEditPlugin.popupEdit(event, tg.innerHTML);
    } else {
        //if we're not in a TMLVariable element, then we have to be careful to parse and replace only the parsed bit..
    }
}

TWiki.ComponentEditPlugin.popupEdit = function(event, tml) {
    if ((tml) && (tml != '')) {
        if (tml.indexOf('SEARCH') > -1) {
//TODO: need to get rid of the getting rid of %'s
//tml = '%'+tml+'%';
            TWiki.JSPopupPlugin.openPopup(event, 'Please wait, requesting data from server');
            TWiki.JSPopupPlugin.ajaxCall(event, TWiki.ComponentEditPlugin.restUrl, 'tml='+tml);
        } else {
    	    var showControl = document.getElementById('componenteditplugindiv');
        	var showControlText = document.getElementById('componentedittextarea');

	        var dialogtext = showControl.innerHTML;
    	    //replace COMPONENTEDITPLUGINTML with tml
	        dialogtext = dialogtext.replace(/COMPONENTEDITPLUGINTML/, tml);
            //remove COMPONENTEDITPLUGINCUSTOM (its for inserting inputs above the textarea like SEARCH)
            dialogtext = dialogtext.replace(/COMPONENTEDITPLUGINCUSTOM/, '');
	        TWiki.JSPopupPlugin.openPopup(event, dialogtext);
        }

        //try { showControlText.focus(); } catch (er) {alert(er)}
    } else {
        TWiki.JSPopupPlugin.closePopup(event);
    }
}

TWiki.ComponentEditPlugin.saveClick = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;
    var result = tg.form.elements.namedItem("componentedit").value;

    if (TWiki.ComponentEditPlugin.sourceTarget.className=='TMLvariable') {
        TWiki.ComponentEditPlugin.sourceTarget.innerHTML = result;
        TWiki.ComponentEditPlugin.popupEdit(event, null);
    } else {
        //if we're not in a TMLVariable element, then we have to be careful to parse and replace only the parsed bit..
        var pre = '';
        var post = '';

        var splitByPercents = TWiki.ComponentEditPlugin.sourceTarget.value.split('%');
        for (var i=0;i<TWiki.ComponentEditPlugin.startIdx-1;i++) {
            pre = pre+splitByPercents[i] + '%';
        }
        pre = pre+splitByPercents[i];
        for (var i=TWiki.ComponentEditPlugin.stopIdx+1;i<splitByPercents.length-1;i++) {
             post = post+splitByPercents[i] + '%';
        }
        post = post+splitByPercents[i];

        //TODO: arge - i'm embedding the assumption of textarea here
        TWiki.ComponentEditPlugin.sourceTarget.value = pre + result + post;
        TWiki.ComponentEditPlugin.popupEdit(event, null);
    }
}

TWiki.ComponentEditPlugin.inputFieldModified = function(event) {
//iterate over all input fields, and any that are different from the default, put into the textarea TWMLVariable
//can optimise by only changing that attr that triggered the event
    var tg = (event.target) ? event.target : event.srcElement;

    var tml = ''+tg.form.elements.namedItem("twikitagname").value+'{';

    for (i=0; i < tg.form.elements.length; i++) {
        elem = tg.form.elements[i];
        if (elem.name == 'twikitagname') {continue;};
        if (elem.name == 'componentedit') {continue;};
        if (elem.name == 'action_save') {continue;};
        if (elem.name == 'action_cancel') {continue;};

        if ((elem.type == 'radio') && (!elem.checked)) {continue;};

        var defaultval = elem.getAttribute('twikidefault');
        if ((typeof( defaultval ) != "undefined") && (elem.value == defaultval)) {continue;};

        tml = tml + elem.name +'="'+elem.value+'" ';
    }

    tml = tml+'}';

    tg.form.elements.namedItem("componentedit").value = '%'+tml+'%';
}
