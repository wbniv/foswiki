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

//from http://www.webfx.nu/dhtml/mozInnerHTML/mozInnerHtml.html
setInnerHTML = function(self, str) {
   var r = self.ownerDocument.createRange();
   r.selectNodeContents(self);
   r.deleteContents();
   var df = r.createContextualFragment(str);
   self.appendChild(df);
}
setOuterHTML = function(self, str) {
   var r = self.ownerDocument.createRange();
   r.setStartBefore(self);
   var df = r.createContextualFragment(str);
   self.parentNode.replaceChild(df, self);
}

//TODO: change it to re-size dependant on the number of lines in the textarea.. with minimum

//create the TWiki.InlineEditPlugin.TextArea Class constructor
TWiki.InlineEditPlugin.TextArea = function(topicSectionObject) {
    this.topicSectionObject = topicSectionObject;
}
TWiki.InlineEditPlugin.TextArea.appliesToSection = function(topicSectionObject) {
    return true;    //TextArea is the fallback editor
}
TWiki.InlineEditPlugin.TextArea.getDefaultTml = function() {
    return 'new Section';    //TextArea is the fallback editor
}
TWiki.InlineEditPlugin.TextArea.getTypeName = function() {
    return "Text";
}

//register this inline editor component with the main factory
TWiki.InlineEditPlugin.TextArea.register = function() {
    if ( typeof( TWiki.InlineEditPlugin.editors ) == "undefined" ) {
        TWiki.InlineEditPlugin.editors = [];
    }
    TWiki.InlineEditPlugin.editors.push('TWiki.InlineEditPlugin.TextArea');
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TWiki.InlineEditPlugin.TextArea CLASS functions
TWiki.InlineEditPlugin.TextArea.prototype.getSaveData = function() {
    var serialzationObj = {};
    
    //seems Safari does not like HTMLInputCollection.namedItem
    var textInput;
    for(var idx=0;idx<this.topicSectionObject.editDivSection.elements.length;idx++) {
        if (this.topicSectionObject.editDivSection.elements[idx].name == 'text') {
            textInput = this.topicSectionObject.editDivSection.elements[idx];
            break;
        }
    }

    serialzationObj.topicSection = textInput.topicSection;
    serialzationObj.value = "\n"+textInput.value;
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        serialzationObj.value = "\n\n"+serialzationObj.value+"\n\n";
    }
    return serialzationObj.toJSONString();

//TODO: recode as object so each editor sends the object it thinks it should
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        textInput.value = "\n\n"+textInput.value+"\n\n";
    }
    return textInput.toJSONString(1);
}

TWiki.InlineEditPlugin.TextArea.prototype.createEditSection = function() {
        var newForm = document.createElement('FORM');
        newForm.topicSectionObject = this.topicSectionObject;
        newForm.name = "componenteditpluginform";
        newForm.method = "post";
        newForm.action = this.topicSectionObject.HTMLdiv.parentNode.action;

        var numberOfLines = this.topicSectionObject.tml.split("\n").length;
        if (numberOfLines < 4) {numberOfLines = 4};
        if (numberOfLines > 12) {numberOfLines = 12};

        var defaultNumberOfCols = 60;
        var defaultNumberOfRows = countLines(this.topicSectionObject.tml, defaultNumberOfCols);
        if (defaultNumberOfRows < 4) {defaultNumberOfRows = 4};
        if (defaultNumberOfRows > 12) {defaultNumberOfRows = 12};

//Don't use innerHTML - it does not work in Mozilla
var newTextarea = document.createElement('TEXTAREA');
newTextarea.name = 'text';
newTextarea.id = "componentedittextarea";
newTextarea.onkeyup = "TWiki.InlineEditPlugin.TextArea.TextAreaResize(this)";
newTextarea.onclick = "TWiki.InlineEditPlugin.TextArea.showComponentEdit(event)";
newTextarea.rows = defaultNumberOfRows;
newTextarea.cols = defaultNumberOfCols;
newTextarea.value = this.topicSectionObject.theTml;
newTextarea.wrap = 'hard';
var hr1 = document.createElement('HR');
newForm.appendChild(hr1);
newForm.appendChild(newTextarea);
var hr2 = document.createElement('HR');
newForm.appendChild(hr2);

        newTextarea.topicSection =this.topicSectionObject.topicSection;

        //TODO: ***************************************make sure we're using this everwhere we should
        if (( typeof( getComputedStyle ) != "undefined" )) {
            //forks for firefox
            var s = getComputedStyle(this.topicSectionObject.HTMLdiv, "");
            newTextarea.style.width = s.width;
        } else {
            //IE
            newTextarea.style.width = this.topicSectionObject.HTMLdiv.offsetWidth;
        }
        this.topicSectionObject.editForm = newForm;
    return newForm;
}

TWiki.InlineEditPlugin.TextArea.prototype.disableEdit = function(disable) {
    var textInput;
    for(var idx=0;idx<this.topicSectionObject.editDivSection.elements.length;idx++) {
        if (this.topicSectionObject.editDivSection.elements[idx].name == 'text') {
            textInput = this.topicSectionObject.editDivSection.elements[idx];
            break;
        }
    }
    
    textInput.disabled = disable;
}


TWiki.InlineEditPlugin.TextArea.TextAreaResize = function(tg) {
    tg.rows = Math.max(1, tg.rows);
    tg.cols = Math.max(20, tg.cols);

    //resize the textarea to fit the text - assume that width is fixed.
    var letterCount = tg.value.length;
    var neededRows = countLines(tg.value, tg.cols)+1;
    if (tg.rows >= neededRows) {
        return;
    }

    tg.rows = Math.min(neededRows, 60);
}

TWiki.InlineEditPlugin.TextArea.showComponentEdit = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;

    var selectionArray = twikismartCursorPosition(tg);
    var splitByPercents = tg.value.split('%');
    var characterCount = 0;
    var i=0;
    //TODO: what if the section starts or ends in a %
    for (;i<splitByPercents.length;i++) {
        characterCount = characterCount+splitByPercents[i].length+1;//1 for the removed %
        if (selectionArray[0]<characterCount) {
            break;
        }
    }
    if ((i==0) || (i>=splitByPercents.length-1)) {
        return;
    }
    selectionIdx = i;
    
    //TODO: need to see if the found TMLVariable has {}'s - if so, have to find the matching pair'
    var openCount = 0;
    var closedCount = 0;
    var openTMLRegex = new RegExp("^[A-Z][A-Z0-9]*{");
    var open = (-1 != splitByPercents[i].search(openTMLRegex));
    if (open) {openCount++;}
    var close = ('}' == splitByPercents[i].charAt(splitByPercents[i].length-1));
    if (close) {closedCount++;}
    while (openCount != closedCount) {
        //need to find the matching set
        if (openCount > closedCount) {
            i++;
        }
        if (openCount < closedCount) {
            i--;
        }
        if ((i<0) || (i>=splitByPercents.length)) {
            return;//not fully symetric variable
        }
        open = (-1 != splitByPercents[i].search(openTMLRegex));
        if (open) {openCount++;}
        close = ('}' == splitByPercents[i].charAt(splitByPercents[i].length-1));
        if (close) {closedCount++;}
    }
    var startIdx = Math.min(selectionIdx, i);
    var stopIdx = Math.max(selectionIdx, i);
    var selectedTml = '%';
    for (i = startIdx;i<=stopIdx;i++) {
        selectedTml = selectedTml + splitByPercents[i] + '%';
    }
    var fullTMLRegex = new RegExp("^%[A-Z][A-Z0-9]*{.*}%$");
    if ((startIdx != stopIdx) && (0 != selectedTml.search(fullTMLRegex))) {
        return;//what a long way to come only to realise we're outside a variable, but surrounded by them
    }

    selectionArray[2] = selectedTml;
    //TODO: update selection start and end so save can do its thing
    
    TWiki.ComponentEditPlugin.sourceTarget = tg;
    TWiki.ComponentEditPlugin.selectionArray = selectionArray;
    TWiki.ComponentEditPlugin.startIdx = startIdx
    TWiki.ComponentEditPlugin.stopIdx = stopIdx
    TWiki.ComponentEditPlugin.popupEdit(event, selectionArray[2]);
}

// Give the cursor position
function twikismartCursorPosition(node) { 
//from http://the-stickman.com/web-development/javascript/finding-selection-cursor-position-in-a-textarea-in-internet-explorer
if (document.selection) {
    // The current selection
    var range = document.selection.createRange();
    // We'll use this as a 'dummy'
    var stored_range = range.duplicate();
    // Select all text
    stored_range.moveToElementText( node );
    // Now move 'dummy' end point to end point of original range
    stored_range.setEndPoint( 'EndToEnd', range );
    // Now we can calculate start and end points
    node.selectionStart = stored_range.text.length - range.text.length;
    node.selectionEnd = node.selectionStart + range.text.length;
    node.selectedText = range.text;
} else {
        node.selectedText = node.value.substring(node.selectionStart, node.selectionEnd);
}

    return [node.selectionStart, node.selectionEnd, node.selectedText];
}
