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

//create the TWiki.InlineEditPlugin.TableEdit Class constructor
TWiki.InlineEditPlugin.TableEdit = function(topicSectionObject) {
    this.topicSectionObject = topicSectionObject;
}
//register this inline editor component with the main factory
TWiki.InlineEditPlugin.TableEdit.register = function() {
    if ( typeof( TWiki.InlineEditPlugin.editors ) == "undefined" ) {
        TWiki.InlineEditPlugin.editors = [];
    }
    TWiki.InlineEditPlugin.editors.push('TWiki.InlineEditPlugin.TableEdit');
}
TWiki.InlineEditPlugin.TableEdit.getDefaultTml = function() {
    return "||||\n||||\n||||";
}
TWiki.InlineEditPlugin.TableEdit.getTypeName = function() {
    return "Table";
}

//returns true if the section can be edited by this editor
TWiki.InlineEditPlugin.TableEdit.appliesToSection = function(topicSectionObject) {
//TODO: deal with \ and other special cases
//foreach line make sure it starts and ends with a |
    var lines = topicSectionObject.tml.split("\n");
    for (var i=0; i< lines.length;i++) {
		//allow blank lines after the table
        if ((lines[i] != '') && ( ! lines[i].match(/^\s*\|(.*)\|\s*$/))) {
            return false;
        }
    }
    return true;
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TWiki.InlineEditPlugin.TableEdit CLASS functions
TWiki.InlineEditPlugin.TableEdit.prototype.getSaveData = function() {
    var serialzationObj = {};

    serialzationObj.topicSection = this.topicSectionObject.topicSection;
    var reconstitutedTable ='|';
    var elementAddress;//[0] == section [1] == line [2] = row
    var line;
    for (var i=0;i<this.topicSectionObject.editDivSection.elements.length;i++) {
        if (this.topicSectionObject.editDivSection.elements[i].name != 'text') {
            continue;
        }
        elementAddress = this.topicSectionObject.editDivSection.elements[i].id.split(",");
        if (line == undefined) {
            line = elementAddress[1];
        }
        if (elementAddress[1] != line) {
            reconstitutedTable = reconstitutedTable + '\n|';
            line = elementAddress[1];
        }

        var cellValue = this.topicSectionObject.editDivSection.elements[i].value;
        //escape linefeeds
        cellValue = cellValue.replace(/\r/g, '');
        cellValue = cellValue.replace(/\n/g, '<br>');
        reconstitutedTable = reconstitutedTable + cellValue;
        reconstitutedTable = reconstitutedTable + '|';
        //if end of row, add new line and a new |
    }

    serialzationObj.value = reconstitutedTable;
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        serialzationObj.value = "\n\n"+serialzationObj.value+"\n\n";
	}

    //need to add a leading \n to stop the different browsers doing different things - see http://twiki.org/cgi-bin/view/Codev/SomeBrowsersLoseInitialNewlineInTextArea
    serialzationObj.value = "\n"+serialzationObj.value + this.topicSectionObject.editDivSection.postLines;
	
    return serialzationObj.toJSONString();
}

TWiki.InlineEditPlugin.TableEdit.prototype.createEditSection = function() {
    var newForm = document.createElement('FORM');
    newForm.topicSectionObject = this.topicSectionObject;
    newForm.name = "componenteditpluginform";
    newForm.method = "post";
    newForm.action = this.topicSectionObject.HTMLdiv.parentNode.action;

    var innerHTML = '';
    var lines = this.topicSectionObject.tml.split("\n");
    var maxColumns = 0;
	newForm.postLines = '';	//don't lose the empty lines on the end of the section
    for (var i=0; i< lines.length;i++) {
		if (lines[i].length == 0) {
			//must be in the post table empty lines
			newForm.postLines = newForm.postLines + lines[i] + "\n"; 
			continue;
		}
//        innerHTML = innerHTML + '<tr>';
//        innerHTML = innerHTML + '<td>'+makeFormButton('add_row', '+', 'addRow(event);', 1);
//        innerHTML = innerHTML + makeFormButton('delete_row', '-', 'deleteRow(event);', 1) +'</td>';
        var cells = lines[i].split('|');
        if (cells.length > maxColumns) {
            maxColumns = cells.length;
        }
        var largestLength = 0;
        var largestIndex = 1;
        for (var j=1; j< cells.length-1;j++) {
            if (cells[j].length > largestLength) {
                largestLength = cells[j].length;
                largestIndex = j;
            }
        }
        var defaultNumberOfCols = 20;
        var defaultNumberOfRows = countLines(cells[largestIndex], defaultNumberOfCols);
        for (var j=1; j< cells.length-1;j++) {
            //escape linefeeds
            var cellValue = cells[j];
            cellValue = cellValue.replace(/<br>/gi, "\n");

            innerHTML = innerHTML + '<td><textarea rows="'+defaultNumberOfRows+'" cols="'+defaultNumberOfCols+'" onkeyup="TWiki.InlineEditPlugin.TableEdit.TextAreaResize(event)" onclick="TWiki.InlineEditPlugin.TextArea.showComponentEdit(event)" id="'+this.topicSectionObject.topicSection+','+i+','+j+'" name="text" width="99%" >'+cellValue+'</textarea></td>';
//            innerHTML = innerHTML + '<td>'+cells[j]+'</td>';
        }
        innerHTML = innerHTML + '</tr>';
    }
    //add colunm manipulation buttons
//    var columnActions = '';
//    columnActions = columnActions+ '<tr>';
//    columnActions = columnActions + '<td>'+makeFormButton('add_row', '+', 'addRow(event);', 1);
//    columnActions = columnActions +'</td>';
//    for (var j=1; j< maxColumns-1;j++) {
//        columnActions = columnActions + '<td align="center">'+makeFormButton('add_row', '+', 'addRow(event);', 1);
//        columnActions = columnActions + makeFormButton('delete_row', '-', 'deleteRow(event);', 1) +'</td>';
//    }
//    columnActions = columnActions + '</tr>';
//    innerHTML = columnActions + innerHTML;

    innerHTML = '<table border="1">' + innerHTML + '</table>';

    newForm.innerHTML = innerHTML;

    return newForm;
}

TWiki.InlineEditPlugin.TableEdit.prototype.disableEdit = function(disable) {
    for (var i=0;i<this.topicSectionObject.editDivSection.elements.length;i++) {
        if (this.topicSectionObject.editDivSection.elements[i].name != 'text') {
            continue;
        }
        this.topicSectionObject.editDivSection.elements[i].disabled = disable;
	}
}


TWiki.InlineEditPlugin.TableEdit.TextAreaResize = function(event) {
    var tg = (event.target) ? event.target : event.srcElement;

    elementAddress = tg.id.split(",");

    tg.rows = Math.max(1, tg.rows);
    tg.cols = Math.max(20, tg.cols);

    //resize the textarea to fit the text - assume that width is fixed.
    var letterCount = tg.value.length;
    var neededRows = countLines(tg.value, tg.cols);
    if (tg.rows >= neededRows) {
        return;
    }

    for (var i=1;;i++) {
        var EDITBOX_ID = elementAddress[0]+','+elementAddress[1]+','+i;
        var textarea = document.getElementById(EDITBOX_ID);
        if (textarea == null) {
            break;
        }
        textarea.rows = Math.min(neededRows, 60);
    }
}
