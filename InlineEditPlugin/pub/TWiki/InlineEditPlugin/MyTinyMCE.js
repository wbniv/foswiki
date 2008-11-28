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

// not editor object created..
initialiseInlineEditDiv = function(topicSectionObject) {
    return tinyMCE;
}

//Called by inlineEdit generic functions
//please define in such a way that it initiates edit mode on the specifed section
function gotoEditMode(topicSectionObject) {
    var editor_id = "TEST_mce_editor_0";  //TODO: need to find out how to get the name of the just created one..
    var html_id = 'inlineeditTopicTML2HTML_1';
    //TODO: load the getEditableText into the hiddent text input - then add tineMCE..
    tinyMCE.innerTML2HTML = getEditableHTML(topicSectionObject);//TODO: need to make sure this processing is done only once..
    if (tinyMCE.isMSIE) {//TODO: work out what to really do ....
        tinyMCE.settings.height = '800';
        tinyMCE.settings.auto_resize = 'false';
    } else {
        tinyMCE.settings.height = topicSectionObject.HTMLdiv.Height;
        tinyMCE.settings.auto_resize = 'false';
    }
    topicSectionObject.HTMLdiv.style.display = 'none';
    tinyMCE.addMCEControl(topicSectionObject.TML2HTMLdiv, editor_id);
    var editor = tinyMCE.getInstanceById(editor_id);
}

var settings = {
        mode : "exact",
//      elements : "inlineeditTopicTML2HTML_1",//don't show editor on load
        theme : "advanced",
        plugins : "noneditable,table,save,advhr,advimage,advlink,emotions,iespell,insertdatetime,preview,zoom,flash,searchreplace,print,contextmenu,paste,directionality,fullscreen,noneditable",
        theme_advanced_buttons1_add_before : "save",
//        save_enablewhendirty : true,          //does not trigger when you programatically change the text - like popup component edit
        theme_advanced_buttons2_add_before: "cut,copy,paste,pastetext,pasteword,separator,search,replace,separator",
        theme_advanced_buttons2_add : "tablecontrols,separator",
//      theme_advanced_buttons3_add : "emotions,iespell,flash,advhr,separator,print,separator,ltr,rtl,separator,fullscreen",
        theme_advanced_toolbar_location : "top",
        theme_advanced_toolbar_align : "left",
        theme_advanced_path_location : "bottom",
//TODO: write some js to grab the css files from the parent and put them in here dynamically
        content_css : "",
//      plugin_insertdate_dateFormat : "%Y-%m-%d",
//      plugin_insertdate_timeFormat : "%H:%M:%S",
//TODO: add TWikispecific xml like elements (verbatim etc)
        extended_valid_elements : "a[name|href|target|title|onclick],img[class|src|border=0|alt|title|hspace|vspace|width|height|align|onmouseover|onmouseout|name],hr[class|width|size|noshade],font[face|size|color|style],span[class|align|style]",
        file_browser_callback : "fileBrowserCallBack",
        save_callback : "myCustomSaveContent",
        setupcontent_callback : "myCustomSetupContent",
        noneditable_noneditable_class: 'TMLvariable',   //don't allow partial editing of class TMLvariable
//      height : "300",
      auto_resize : false,
        width : "99%",  //TODO: make less foe IE6
//      onchange_callback : "onchange",
        remove_linebreaks : false,
        cleanup: false,                 //
        preformatted : true,        //tabs and spaces will be preserved
        auto_reset_designmode : true
};

// Intialize all components to load TinyMCE (called from template))
function loadTinyMCE(document){
    var css = '';
    //grab the stylesheets from the main document
    //TODO: maybe this will help wikiwyg too - these style links seem to succeed better when they are relative links
    var styles = document.styleSheets;

    for (var i = 0; i < styles.length; i++) {
        var style = styles[i];
        //mmm, this breaks down when you have url parameters    TODO: BUG in wikiwyg
        if (style.href == location.href) // skip inline styles
            continue;
        var relativeLink = style.href.substring(7+location.host.length, style.href.length);
        css = css + relativeLink + ',' ;
    }
    settings.content_css = css + settings.content_css;
    // To initiliazie TinyMCE
    tinyMCE.init(settings);
}

//put the edited html into the form input named text (so the POST uses it)
function myCustomSaveContent(element_id, html, body) {
	var elm = document.getElementById(element_id);
    elm.parentNode.elements.namedItem('text').value = html;
    return html;
}

//Set the Edit box to use our clever TML2HTML markup
function myCustomSetupContent(editor_id, body, doc) {
    var editor = tinyMCE.getInstanceById(editor_id);
    body.innerHTML = tinyMCE.innerTML2HTML;
    //add popup TWikiComponent edit
    if (typeof TWiki.ComponentEditPlugin.addComponentEditClick!="undefined") {
        TWiki.ComponentEditPlugin.addComponentEditClick(body);
    }
}

