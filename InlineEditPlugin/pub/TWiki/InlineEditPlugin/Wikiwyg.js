/*==============================================================================
TWiki WikiWyg client server wrapper

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

TWiki specific modifications Copyright (C) 2006 SvenDowideit@wikiring.com

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/
//create the TWiki.InlineEditPlugin.TextArea Class constructor
TWiki.InlineEditPlugin.Wikiwyg = function(topicSectionObject) {
    this.topicSectionObject = topicSectionObject;
}
TWiki.InlineEditPlugin.Wikiwyg.appliesToSection = function(topicSectionObject) {
    return true;    //TextArea is the fallback editor
}
TWiki.InlineEditPlugin.Wikiwyg.getDefaultTml = function() {
    return 'new Section';    //TextArea is the fallback editor
}
TWiki.InlineEditPlugin.Wikiwyg.getTypeName = function() {
    return "Text";
}

//register this inline editor component with the main factory
TWiki.InlineEditPlugin.Wikiwyg.register = function() {
    if ( typeof( TWiki.InlineEditPlugin.editors ) == "undefined" ) {
        TWiki.InlineEditPlugin.editors = [];
    }
    TWiki.InlineEditPlugin.editors.push('TWiki.InlineEditPlugin.Wikiwyg');
}


//Called by inlineEdit generic functions
//please define in such a way that it initiates edit mode on the specifed section
TWiki.InlineEditPlugin.Wikiwyg.prototype.OLDcreateEditSection = function() {
    topicSectionObject.editDivSection.editMode();
}

//ONLY one config for all wikiwygs
var config = {
    doubleClickToEdit: false,
    toolbar: {
        imagesLocation: '%PLUGINPUBURL%/Wikiwyg-0.12/images/'
    },
};


TWiki.InlineEditPlugin.Wikiwyg.prototype.createEditSection = function() {
    var wikiwyg = new Wikiwyg.ClientServer();
    wikiwyg.createWikiwygArea(this.topicSectionObject.HTMLdiv, config);
    wikiwyg.setTopicSectionObject(this.topicSectionObject);

	return wikiwyg;
}

//called after saveChanges has returned
//redirects to view (because replacing HTML in current doc fails)
showReply = function(reply) {
    if (reply == '') {
        document.body.style.cursor = "default";
        window.location.reload();
    } else {
        alert('Error saving, please take a copy of your changes for saftey, and try again (or see your TWikiAdmin)');
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//WikiWyg impl

proto = new Subclass('Wikiwyg.ClientServer', 'Wikiwyg');

proto.saveChanges = function() {
//TODO: looks like the TWikiVariable span striping is different now?
document.body.style.cursor = "wait";
//TODO: add save option to return success code
    this.current_mode.toHtml( function(html) { self.html = html });
    
    var postdata = 'replywitherrors=1;forcenewrevision=1;inlineeditsave=1;html2tml=1;section='+
            this.topicSectionObject.topicSection+';originalrev='+
            this.topicSectionObject.topicRevision+
            ';text=' + encodeURIComponent(self.html);

//TODO: redo this to use a rest api that does not return a view..
    Wikiwyg.liveUpdate(
        'POST',
       this.topicSectionObject.saveUrl,
        postdata,
        showReply
    );
}

proto.modeClasses = [
//    'Wikiwyg.Wikitext.ClientServer',
    'Wikiwyg.Wysiwyg',
//    'Wikiwyg.Preview'
];

//TODO:decide how best to de-wikiwyg this
proto.requestTopicState = function(restUrl, webDotTopic) {
    var url = restUrl;

    var postdata = 'rest=InlineEditPlugin.setTopicLock;topicName='+webDotTopic;
    Wikiwyg.liveUpdate(
        'GET',
        url,
        postdata,
        showTopicState
    );
}

// initialise and select edit mode
proto.editMode = function() { // See IE, below

    this.requestTopicState(this.topicSectionObject.authedRestUrl, this.topicSectionObject.topicName);

    this.current_mode = this.first_mode;

    var editableHTML =getEditableHTML(this.topicSectionObject);

    this.current_mode.fromHtml(editableHTML)
    this.toolbarObject.resetModeSelector();
    this.current_mode.enableThis();

    //add popup TWikiComponent edit
    if (typeof TWiki.ComponentEditPlugin.addComponentEditClick!="undefined") {
        TWiki.ComponentEditPlugin.addComponentEditClick(this.current_mode.get_edit_document());
    }
}

//set the topic state
proto.setTopicSectionObject = function(obj) {
    this.topicSectionObject = obj;
}

//not used at this point (stub from wikiwyg demo)
proto = new Subclass('Wikiwyg.Wikitext.ClientServer', 'Wikiwyg.Wikitext');

proto.convertWikitextToHtml = function(wikitext, func) {
    var postdata = 'inlineeditsave=1;html2tml=1;section='+
            this.topicSectionObject.topicSection+';rev='+
            this.topicSectionObject.topicRevision+
            ';content=' + encodeURIComponent(wikitext);
    Wikiwyg.liveUpdate(
        'POST',
        Wikiwyg.uri(),
        postdata,
        func
    );
}
