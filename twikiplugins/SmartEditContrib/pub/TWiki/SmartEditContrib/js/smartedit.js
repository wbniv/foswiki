var clientPC = navigator.userAgent.toLowerCase(); // Get client info
var is_gecko = ((clientPC.indexOf('gecko')!=-1) && (clientPC.indexOf('spoofer')==-1)
                && (clientPC.indexOf('khtml') == -1) && (clientPC.indexOf('netscape/7.0')==-1));
var is_ie    = /MSIE/.test(navigator.userAgent);
var startIndex = -1;
var endIndex = -1;
var mySelection = "";
var textarea = "";
var old_length = 0;
var scrollTop=0;
var keypresscode = 0;
var shiftpressed = false;
var ctrlpressed = false;
var textsize = 1.0;
var textareasize = "";
var listtoinsert = false;
var listtodelete = false;
var listtoinserttype = "";
var	twikismartadjustmode = false;

function twikismartEdit(textareaid){
	twikismartSetToolbarStyle();
	if(textareaid == null || textareaid.length < 1){
		textareaid = "topic"; // Default TWiki textarea
	}
	textarea = document.getElementById(textareaid);
	textareasize = textarea.rows;
	// Tests	
	if( is_gecko)
		document.captureEvents( Event.KEYDOWN);
	document.onkeydown = twikismartFct_KeyPressed;
	document.onkeyup = twikismartFct_KeyUp;
	twikismartInsertCheatMode();
}


// This function prevents "flashes" during TAB and SHIFT+TAB events
function twikismartInsertCheatMode(){
	// Cheat mode for event TAB
	var d1 = document.createElement("input");
	d1.type = "text";
	d1.style.width = "0";
	d1.style.color = "white";
	d1.style.border = "1px solid white";
	var sign = document.getElementById("sig");
	sign.parentNode.insertBefore(d1,sign);
	// Cheat mode for event shift+TAB
	var com = document.getElementById("cheatItem");
	var d2 = document.createElement("input");
	d2.type = "text";
	d2.style.width = "0";
	d2.style.color = "white";
	d2.style.border = "1px solid white";
	com.appendChild(d2);
}

// Activate or no the adjust mode
function twikismartAdjustMode(){
	twikismartadjustmode = !twikismartadjustmode;
	if(twikismartadjustmode){
		twikismartAdjust();
	}
	else{
		textarea.rows = textareasize;
	}
}

// Called when a key is pressed
function twikismartFct_KeyPressed(e){
	if( is_gecko){
		//alert(e.keyCode);
		if(e.keyCode == 9){
			twikismartInitSelectionProperties();
			keypresscode = 1;
		}
		else{
			if(e.keyCode == 16){
				shiftpressed = true;
			}
			else{
				if(e.keyCode == 17){
					ctrlpressed = true;
				}
				else{
					if(e.keyCode == 13){
						// Touche entree
						twikismartDetectListContext();
						if(twikismartadjustmode){
							twikismartAdjust();
						}
					}
				}
			}
		}
	}
	else{
		//alert(event.keyCode);
		if(event.keyCode == 9){	
			// TAB
			textarea.focus();
			twikismartInitSelectionProperties();
			keypresscode = 1;
		}
		else{
			if(event.keyCode == 16){
				shiftpressed = true;
			}
			else{
				if(event.keyCode == 17){
					ctrlpressed = true;
				}
				else{
					if(event.keyCode == 13){
						// Touche entree
						twikismartDetectListContext();
						if(twikismartadjustmode){
							twikismartAdjust();
						}
					}
				}
			}
		}
	}
}

// Called by "key presses" function when you have to detect is a bullet list is on the last line
function twikismartDetectListContext(){
	twikismartInitSelectionProperties();
	var textBefore = textarea.value.substring(0,startIndex);
	if(is_gecko){
		var index = textBefore.lastIndexOf("\n");
		var currentLine = textBefore.substring(index+1,startIndex);
		var indexbullet = twikismartIndexOfBullet(currentLine);
		if(indexbullet >= 0){
			listtoinsert = true;
		}
	}
	else{
		var index = textBefore.lastIndexOf("\n");
		var currentLine = textBefore.substring(index+1,startIndex);
		var indexbullet = twikismartIndexOfBullet(currentLine);
		if(indexbullet >= 0){
			listtoinsert = true;
		}
	}
}

// Called on a key up event
function twikismartFct_KeyUp(e){
	if(keypresscode != 0 && shiftpressed == false){
		if(keypresscode == 1){
			twikismartIndent();
			keypresscode = 0;
		}
	}
	else{
		if(shiftpressed){
			if(keypresscode == 1){
				twikismartOutdent();
				if(!is_gecko){
					shiftpressed = false;
				}
				keypresscode = 0;
			}
		}
	}
	if(listtoinsert){
		listtoinsert = false;
		textarea.value = textarea.value.substring(0,endIndex+1)+listtoinserttype+textarea.value.substring(endIndex+1,textarea.value.length);
		//alert(""+startIndex+" and "+endIndex+" and "+listtoinserttype.length+"->"+textarea.value.substring(startIndex,(startIndex+listtoinserttype.length)));
		if(is_gecko){
			textarea.selectionStart = startIndex+(listtoinserttype.length)+1;
			textarea.selectionEnd = startIndex+(listtoinserttype.length)+1;
		}
		else{
			var nb = twikismartNbLinesBefore(startIndex);
			twikismartSetSelectionRange(textarea,startIndex+(listtoinserttype.length)-nb+1,startIndex+(listtoinserttype.length)-nb+1);
		}
		listtoinserttype = "";
	}
	if(listtodelete){
		listtodelete = false;
		//alert("list to delete");
		var toreplace = textarea.value.substring(0,endIndex);
		if(is_gecko){
			var i = toreplace.lastIndexOf("\n");
			toreplace = toreplace.substring(0,(i+1));//+toreplace.substring((i+1+listtoinserttype.length),toreplace.length);
			//alert(toreplace);
			var dif = textarea.value.substring(0,endIndex).length - toreplace.length;
			textarea.value = toreplace+textarea.value.substring(endIndex,textarea.value.length);
			textarea.selectionStart = endIndex-dif+1;
			textarea.selectionEnd = endIndex-dif+1;
		}
		else{
			var i = toreplace.lastIndexOf("\n");
			toreplace = toreplace.substring(0,(i+1));//+toreplace.substring((i+1+listtoinserttype.length),toreplace.length);
			//alert(toreplace);
			var dif = textarea.value.substring(0,endIndex).length - toreplace.length;
			textarea.value = toreplace+textarea.value.substring(endIndex,textarea.value.length);
			var nb = twikismartNbLinesBefore(startIndex);
			twikismartSetSelectionRange(textarea,startIndex-nb,startIndex-nb);
		}
		//alert(toreplace);
	}
	if(is_gecko){
		if(e.keyCode == 16){
			shiftpressed = false;
		}
		else{
			if(e.keyCode == 17){
				ctrlpressed = false;
			}
		}
	}
	else{
		if(event.keyCode == 16){
			shiftpressed = false;
		}
		else{
			if(event.keyCode == 17){
				ctrlpressed = false;
			}
		}
	}
}

// Give the index of the bullet item in a line (this function count all 3 spaces before the item)

function twikismartIndexOfBullet(text){
	var result = -1;
	var stringres = "";
	//alert(text);
	if(text.indexOf("   1 ") >= 0){
		while(text.indexOf("   ") == 0){
			text = text.substring(3,text.length);
			result++;
			stringres+="   ";	
		}
		stringres+="1 ";
		if(text.length == 2 || (text.length > 2 && twikismartIsEmptyString(text.substring(2,text.length)))){
			listtodelete = true;
			return -1;
		}
		
	}
	else{
		if(text.indexOf("   * ") >= 0){
			while(text.indexOf("   ") == 0){
				text = text.substring(3,text.length);
				result++;
				stringres+="   ";
			}
			stringres+="* ";
			if(text.length == 2 || (text.length > 2 && twikismartIsEmptyString(text.substring(2,text.length)))){
				listtodelete = true;
				return -1;
			}
		}
	}
	listtoinserttype = stringres;
	//alert(result);
	return result;
}

// Set the default toolbar style
function twikismartSetToolbarStyle(){
	var tool = document.getElementById("smarttoolbar");
	if(navigator.userAgent.toLowerCase().indexOf("opera")== -1){
		if(!is_gecko){
			tool.style.marginBottom = "-20px";
		}
		else{
			tool.style.marginBottom = "-2px";
		}
	}
	tool.style.borderTop = "1px solid #60a0e0";
	tool.style.borderLeft = "1px solid #60a0e0";
	tool.style.borderRight = "1px solid #60a0e0";
	var images = document.getElementsByTagName("IMG");
	if(images!=null && images.length > 0){
		for(var i=0;i<images.length;i++){
			twikismartSetButtonStyle(images[i]);
		}
	}
	var tds = document.getElementsByTagName("TD");
	if(tds!=null && tds.length > 0){
		for(var i=0;i<tds.length-1;i++){
			tds[i].width = "25px";
		}
	}
	
	var select = document.getElementById("twikismartselect");
	select.style.fontFamily = "Verdana";
	select.style.fontSize = "0.7em";
	
	var select2 = document.getElementById("twikismartselectcommon");
	select2.style.fontFamily = "Verdana";
	select2.style.fontSize = "0.7em";
	
	var select3 = document.getElementById("twikismartadjustmode");
	select3.parentNode.style.fontFamily = "Arial";
	select3.parentNode.style.fontSize = "0.7em";	
	
}

// Set the default button style
function twikismartSetButtonStyle(button){
	button.onmouseover = function (){ twikismartMover(button);};
	button.onmouseout = function (){ twikismartMout(button);};
	button.style.marginLeft = "5px";
	button.style.borderRight = "2px solid white";
	button.style.borderBottom = "1px solid white";
}

// Set the default button style on mouse over
function twikismartMover(element){
	element.style.borderRight = "2px solid #c0e0ff";
	element.style.borderBottom = "1px solid gray";
	//element.style.backgroundColor = "#c0ffff";
}

// Set the default button style on mouse out
function twikismartMout(element){
	element.style.borderRight = "2px solid white";
	element.style.borderBottom = "1px solid white";
	element.style.backgroundColor = "";
}

// Called to intitialize all values linked to the selection
function twikismartInitSelectionProperties(){
	if(keypresscode == 0){
		var txtarea = textarea;
		endIndex = 0;
		startIndex = 0;
		mySelection = "";
		if(document.selection  && !is_gecko) {
			mySelection = document.selection.createRange().text;
			if(mySelection != null){
				endIndex = startIndex+mySelection.length;
			}
			startIndex = twikismartCursorPosition(txtarea);
			endIndex+=startIndex;
			document.selection.createRange().text = mySelection;
			if(startIndex == endIndex && startIndex == -1){
				startIndex = txtarea.value.length - 1;
				endIndex = startIndex;
				mySelection = txtarea.value.substring(startIndex,endIndex);
			}
		}
		else if(txtarea.selectionStart || txtarea.selectionStart == '0') {
			startIndex = txtarea.selectionStart;
			endIndex = txtarea.selectionEnd;
			scrollTop = txtarea.scrollTop;
			mySelection = (txtarea.value).substring(startIndex, endIndex);
		}
		if(mySelection.length == 0 || (mySelection.length == 1 && mySelection.indexOf(" ") != -1)){
			mySelection = "";
		}
		if(startIndex == -1){
			startIndex = (textarea.value.length-mySelection.length);
			endIndex = startIndex+mySelection.length;
		}
		if(twikismartIsEmptyString(mySelection)){
			mySelection = "";
		}
		//alert("Selection = "+mySelection+"- start:"+startIndex+" -end:"+endIndex+" -length:"+mySelection.length);
	}
}

// Give the cursor position
function twikismartCursorPosition(node) { 
	node.focus();  
	/* without node.focus() IE will returns -1 when focus is not on node */ 
	if(node.selectionStart) 
		return node.selectionStart;
	else if(!document.selection)
		return 0;
	var c  = "\001";
	var sel = document.selection.createRange();
	var dul = sel.duplicate(); 
	var len = 0;
	dul.moveToElementText(node);
	sel.text = c;
	len  = (dul.text.indexOf(c));
	sel.moveStart('character',-1);
	sel.text = "";
	return len;
}

// Get all lines for firefox (lines are separated by \n )
function twikismartGetFirefoxLines(){
	var text = mySelection;
	var myarray = twikismartIndexsOf(text,"\n");
	var textarray = new Array();
	if(myarray != null && myarray.length > 0){
		textarray.push(text.substring(0,myarray[0]));
		for(var i=0;i<myarray.length-1;i++){
			textarray.push(text.substring(myarray[i],myarray[i+1]));
		}
		textarray.push(text.substring(myarray[myarray.length-1],text.length));
	}
	else{ // No line detected
		textarray.push(text);
	}
	return textarray;
}

// Get all lines for Microsoft Internet Explorer (lines are separated by \r\n )
function twikismartGetIELines(){
	var text = mySelection;
	var myarray = twikismartIndexsOf(text,"\r\n");
	var textarray = new Array();
	if(myarray != null && myarray.length > 0){
		textarray.push(text.substring(0,myarray[0]));
		for(var i=0;i<myarray.length-1;i++){
			if(myarray[i]+1 != myarray[i+1]){
				textarray.push(text.substring(myarray[i]+1,myarray[i+1])); // ici
			}
		}
		textarray.push(text.substring(myarray[myarray.length-1]+1,text.length)); // ici
	}
	else{ // No line detected
		textarray.push(text);
	}
	return textarray;
}


// Returns indexes of "tosearch" strings in a given "text" -> Used by getLines() function
function twikismartIndexsOf(text, tosearch){
	var result = new Array();
	var result2 = new Array();
	if(text != null && text.length > 0){
		var index = text.lastIndexOf(tosearch);
		if(index != -1){
			while(index != -1 && text.length > 0){
				result2.push(index);
				text = text.substring(0,index);
				index = text.lastIndexOf(tosearch);
			}
			if(result2.length > 0){
				for(var i=result2.length-1;i>=0;i--){
					result.push(result2[i]);
				}
			}
		}
	}
	return result;
}

// Insert bold tags over the selection or over the default text
function twikismartInsertBold(){
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "Bold Text";
	}
	if(is_gecko){
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				//finaltext+=lines[i];
				if(i==0){
					endSelect = lines[i].length;
				}
				if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
					if(i==0 && lines[i].indexOf("\n") == -1){
						tmp+=" *"+lines[i]+"* ";
					}
					else{
						if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
							tmp+=lines[i].substring(0,1)+" *"+lines[i].substring(1,lines[i].length)+"* ";
						}
						else{
							tmp+=lines[i];
						}
					}
				}
				else{
					tmp+=lines[i];
				}
			}
			finaltext = tmp;
		}
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		textarea.focus();
		textarea.selectionStart = startIndex+2;
		textarea.selectionEnd = startIndex+endSelect+2;
		textarea.scrollTop = scrollTop;
	}
	else{
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				if(i==0 && lines[i].indexOf("\n\r") == -1){
					finaltext+=" *"+lines[i]+"* ";
					pl+=4;
				}
				else{
					if(lines[i].length == 1){
						finaltext+=lines[i];
					}
					else{
						if(lines[i].length > 0){
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								finaltext+=lines[i].substring(0,1)+" *"+lines[i].substring(1,lines[i].length)+"* ";
								pl+=4;
							}
							else{
								finaltext+=lines[i];
							}
						}
						else{
							finaltext+=lines[i];
						}
					}
				}
			}
		}
		var newl = (textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
		if((newl - old_length - pl) != 0){
			//alert("-"+(newl - old_length - pl)+"-"+mySelection.length);
			//finaltext+="\r";
		}	
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+2),(startIndex+finaltext.length-twikismartNbLinesBefore-2));
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndex+finaltext.length-2));
		}
	}
}

// Insert fixed tags over the selection or over the default text
function twikismartInsertFixed(){
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "Formatted";
	}
	if(is_gecko){
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				//finaltext+=lines[i];
				if(i==0){
					endSelect = lines[i].length;
				}
				if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
					if(i==0 && lines[i].indexOf("\n") == -1){
						tmp+=" ="+lines[i]+"= ";
					}
					else{
						if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
							tmp+=lines[i].substring(0,1)+" ="+lines[i].substring(1,lines[i].length)+"= ";
						}
						else{
							tmp+=lines[i];
						}
					}
				}
				else{
					tmp+=lines[i];
				}
			}
			finaltext = tmp;
		}
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		textarea.focus();
		textarea.selectionStart = startIndex+2;
		textarea.selectionEnd = startIndex+endSelect+2;
		textarea.scrollTop = scrollTop;
	}
	else{
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				if(i==0 && lines[i].indexOf("\n\r") == -1){
					finaltext+=" ="+lines[i]+"= ";
					pl+=4;
				}
				else{
					if(lines[i].length == 1){
						finaltext+=lines[i];
					}
					else{
						if(lines[i].length > 0){
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								finaltext+=lines[i].substring(0,1)+" ="+lines[i].substring(1,lines[i].length)+"= ";
								pl+=4;
							}
							else{
								finaltext+=lines[i];
							}
						}
						else{
							finaltext+=lines[i];
						}
					}
				}
			}
		}
		var newl = (textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
		if((newl - old_length - pl) != 0){
			//alert("-"+(newl - old_length - pl)+"-"+mySelection.length);
			//finaltext+="\r";
		}	
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+2),(startIndex+finaltext.length-twikismartNbLinesBefore-2));
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndex+finaltext.length-2));
		}
	}
}

// Insert italic tags over the selection or over the default text
function twikismartInsertItalic(){
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "Italic Text";
	}
	if(is_gecko){
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				//finaltext+=lines[i];
				if(i==0){
					endSelect = lines[i].length;
				}
				if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
					if(i==0 && lines[i].indexOf("\n") == -1){
						tmp+=" _"+lines[i]+"_ ";
					}
					else{
						if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
							tmp+=lines[i].substring(0,1)+" _"+lines[i].substring(1,lines[i].length)+"_ ";
						}
						else{
							tmp+=lines[i];
						}
					}
				}
				else{
					tmp+=lines[i];
				}
			}
			finaltext = tmp;
		}
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		textarea.focus();
		textarea.selectionStart = startIndex+2;
		textarea.selectionEnd = startIndex+endSelect+2;
		textarea.scrollTop = scrollTop;
	}
	else{
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(lines != null && lines.length > 0){
			for(var i=0;i<lines.length;i++){
				if(i==0 && lines[i].indexOf("\n\r") == -1){
					finaltext+=" _"+lines[i]+"_ ";
					pl+=4;
				}
				else{
					if(lines[i].length == 1){
						finaltext+=lines[i];
					}
					else{
						if(lines[i].length > 0){
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								finaltext+=lines[i].substring(0,1)+" _"+lines[i].substring(1,lines[i].length)+"_ ";
								pl+=4;
							}
							else{
								finaltext+=lines[i];
							}
						}
						else{
							finaltext+=lines[i];
						}
					}
				}
			}
		}
		var newl = (textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
		if((newl - old_length - pl) != 0){
			//alert("-"+(newl - old_length - pl)+"-"+mySelection.length);
			//finaltext+="\r";
		}	
		textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+2),(startIndex+finaltext.length-twikismartNbLinesBefore-2));
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndex+finaltext.length-2));
		}
	}
}

// Insert bullet tags on line start // No context !!!!!!!!!!!
function twikismartInsertBulletList(){
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "";
	}
	if(is_gecko){
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
			textarea.value = textarea.value.substring(0,indice+1)+"   * "+textarea.value.substring(indice+1,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice,startIndex)+lines[i];
						startIndex = indice;
						endSelect = lines[i].length;
					}
					if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
						if(i==0 && lines[i].indexOf("\n") == -1){
							tmp+="   * "+lines[i];
						}
						else{
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								tmp+=lines[i].substring(0,1)+"   * "+lines[i].substring(1,lines[i].length);
							}
							else{
								tmp+=lines[i];
							}
						}
					}
					else{
						tmp+=lines[i];
					}
				}
				finaltext = tmp;
			}
			textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		textarea.focus();
		textarea.selectionStart = startIndex+5;
		textarea.selectionEnd = startIndex+endSelect+5;
		textarea.scrollTop = scrollTop;
	}
	else{
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
			if(indice == -1){
				indice = -2;
			}
			textarea.value = textarea.value.substring(0,indice+2)+"   * "+textarea.value.substring(indice+2,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0 && lines[i].indexOf("\n\r") == -1){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice+2,startIndex)+lines[i];
						startIndex = indice;
						pl+=5;
						if(indice != 0){
							finaltext+="\r\n   * "+lines[i];
						}
						else{
							finaltext+="   * "+lines[i];
						}
					}
					else{
						if(lines[i].length == 1){
							finaltext+=lines[i];
						}
						else{
							if(lines[i].length > 0){
								if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
									finaltext+=lines[i].substring(0,1)+"   * "+lines[i].substring(1,lines[i].length);
									pl+=5;
								}
								else{
									finaltext+=lines[i];
								}
							}
							else{
								finaltext+=lines[i];
							}
						}
					}
				}
			}
			var newl = (textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
			if((newl - old_length - pl) != 0){
				//alert("-"+(newl - old_length - pl)+"-"+mySelection.length);
				//finaltext+="\r";
			}	
			textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+2),(startIndex+finaltext.length-twikismartNbLinesBefore-2));
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndex+finaltext.length-2));
		}
	}
}

// Insert num list tags on line start // No context !!!!!!!!!!!
function twikismartInsertNumList(){
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "";
	}
	if(is_gecko){
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
			textarea.value = textarea.value.substring(0,indice+1)+"   1 "+textarea.value.substring(indice+1,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice,startIndex)+lines[i];
						startIndex = indice;
						endSelect = lines[i].length;
					}
					if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
						if(i==0 && lines[i].indexOf("\n") == -1){
							tmp+="   1 "+lines[i];
						}
						else{
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								tmp+=lines[i].substring(0,1)+"   1 "+lines[i].substring(1,lines[i].length);
							}
							else{
								tmp+=lines[i];
							}
						}
					}
					else{
						tmp+=lines[i];
					}
				}
				finaltext = tmp;
			}
			textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		textarea.focus();
		textarea.selectionStart = startIndex+5;
		textarea.selectionEnd = startIndex+endSelect+5;
		textarea.scrollTop = scrollTop;
	}
	else{
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
			if(indice == -1){
				indice = -2;
			}
			textarea.value = textarea.value.substring(0,indice+2)+"   1 "+textarea.value.substring(indice+2,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0 && lines[i].indexOf("\n\r") == -1){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice+2,startIndex)+lines[i];
						startIndex = indice;
						pl+=5;
						if(indice != 0){
							finaltext+="\r\n   1 "+lines[i];
						}
						else{
							finaltext+="   1 "+lines[i];
						}
					}
					else{
						if(lines[i].length == 1){
							finaltext+=lines[i];
						}
						else{
							if(lines[i].length > 0){
								if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
									finaltext+=lines[i].substring(0,1)+"   1 "+lines[i].substring(1,lines[i].length);
									pl+=5;
								}
								else{
									finaltext+=lines[i];
								}
							}
							else{
								finaltext+=lines[i];
							}
						}
					}
				}
			}
			var newl = (textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
			if((newl - old_length - pl) != 0){
				//alert("-"+(newl - old_length - pl)+"-"+mySelection.length);
				//finaltext+="\r";
			}	
			textarea.value = textarea.value.substring(0,startIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+2),(startIndex+finaltext.length-twikismartNbLinesBefore-2));
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndex+finaltext.length-2));
		}
	}
}

// Insert 3 spaces on line start // No context !!!!!!!!!!!
function twikismartIndent(){
	textarea.focus();
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "";
	}
	if(is_gecko){ // Firefox ou mozilla
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		var starteIndex = startIndex;
		var nblines = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
			textarea.value = textarea.value.substring(0,indice+1)+"   "+textarea.value.substring(indice+1,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice,startIndex)+lines[i];
						starteIndex = indice;
						endSelect = lines[i].length;
					}
					if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
						if(i==0 && lines[i].indexOf("\n") == -1){
							tmp+="   "+lines[i];
							nblines++;
						}
						else{
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								tmp+=lines[i].substring(0,1)+"   "+lines[i].substring(1,lines[i].length);
								nblines++;
							}
							else{
								tmp+=lines[i];
							}
						}
					}
					else{
						tmp+=lines[i];
					}
				}
				finaltext = tmp;
			}
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		//alert(startIndex);
		textarea.selectionStart = (startIndex+3);
		if(mySelection.length > 0){
			textarea.selectionEnd = endIndex+nblines*3;
		}
		else{
			textarea.selectionEnd = (startIndex+3);
		}
		textarea.scrollTop = scrollTop;
	}
	else{ // IE ou Opera
		var starteIndex = startIndex;
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
			if(indice == -1){
				indice = -2;
			}
			textarea.value = textarea.value.substring(0,indice+2)+"   "+textarea.value.substring(indice+2,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0 && lines[i].indexOf("\n\r") == -1){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
						if(indice == -1){
							indice = -2;
						}
						lines[i] = textarea.value.substring(indice+2,startIndex)+lines[i];
						starteIndex = indice;
						pl+=3;
						if(indice != -2){
							finaltext+="\r\n   "+lines[i];
							
						}
						else{
							finaltext+="   "+lines[i];
						}
					}
					else{
						if(lines[i].length == 1){
							finaltext+=lines[i];
						}
						else{
							if(lines[i].length > 0){
								if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
									finaltext+=lines[i].substring(0,1)+"   "+lines[i].substring(1,lines[i].length);
									pl+=3;
								}
								else{
									finaltext+=lines[i];
								}
							}
							else{
								finaltext+=lines[i];
							}
						}
					}
				}
			}
			var newl = (textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		var nbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			//  IE
			//alert("IE :"+mySelection.length);
			if(mySelection.length == 0){
				twikismartSetSelectionRange(textarea,(startIndex+3-nbLinesBefore),(startIndex+3-nbLinesBefore));
			}
			else{
				//alert("start : "+startIndex+" et apres "+endIndex);
				if(mySelection != null && mySelection.indexOf("\r\n") == -1){
					twikismartSetSelectionRange(textarea,(startIndex+3-nbLinesBefore),(endIndex+3-nbLinesBefore));
				}
				else{
					twikismartSetSelectionRange(textarea,(startIndex+3-nbLinesBefore),(startIndex+3-nbLinesBefore));
				}
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+3),(startIndex+finaltext.length+3));
		}
	}
}

// No need ...
function twikismartStartsWith(text, tag){
	if(text != null && text.length > 0 && tag != null && tag.length > 0){
		return (text.indexOf(tag) == 0);
	}
	return false;
}

// Return true if a given text is null or has just blanks
function twikismartIsEmptyString(text){
	count = 0;
	if(text != null && text.length > 0){
		while(text.charAt(count) == " "){
			count++;
		}
		if(count == text.length){
			return true;
		}
	}
	return false;
}

// For Internet Explorer ... we need to know how many lines we have before a given index to debug selection indexes
function twikismartNbLinesBefore(index){
	var text = textarea.value;
	var ind = twikismartIndexsOf(text,"\r\n");
	var nb = 0;
	if(ind != null && ind.length > 0){
		for(var i=0;i<ind.length;i++){
			if(ind[i] < index){
				nb++;
			}
		}
	}
	return nb;
}

// Set the selection ... works with all brothers but it seems not very "stable"
function twikismartSetSelectionRange(input, start, end) {
	if (is_gecko) {
		input.setSelectionRange(start, end);
		input.focus();
		
	} else {
		// assumed IE
		var range = input.createTextRange();
		range.collapse(true);
		range.moveStart("character", start);
		range.moveEnd("character", end - start);
		range.select();
	}
}

// Delete 3 spaces on given lines
function twikismartOutdent(){
	textarea.focus();
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "";
	}
	if(is_gecko){ // Firefox ou mozilla
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		var starteIndex = startIndex;
		var nblines = lines.length;
		var changed = false;
		var total = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
			if(textarea.value.substring(indice+1,textarea.value.length).indexOf("   ") == 0){
				textarea.value = textarea.value.substring(0,indice+1)+textarea.value.substring(indice+4,textarea.value.length);
				changed = true;
				total +=3;
			}
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice,startIndex)+lines[i];
						starteIndex = indice;
						endSelect = lines[i].length;
					}
					if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
						if(i==0 && lines[i].indexOf("\n") == -1){
							if(lines[i].indexOf("   ") == 0){
								lines[i] = lines[i].substring(3,lines[i].length);
								changed = true;
								total +=3;
							}
							tmp+=lines[i];
						}
						else{
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								if(lines[i].indexOf("   ") == 1){
									lines[i] = lines[i].substring(0,1)+lines[i].substring(4,lines[i].length);
									changed = true;
									total +=3;
								}
								tmp+=lines[i];
							}
							else{
								tmp+=lines[i];
							}
						}
					}
					else{
						tmp+=lines[i];
					}
				}
				finaltext = tmp;
			}
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		//alert(startIndex);
		textarea.selectionStart = (startIndex-3);
		if(mySelection.length > 0){
			if(changed){
				textarea.selectionEnd = startIndex+mySelection.length-total;
			}
			else{
				textarea.selectionEnd = endIndex;
				textarea.selectionStart = textarea.selectionStart+3;
			}
		}
		else{
			//alert(changed);
			if(changed){
				textarea.selectionEnd = (startIndex-3);
			}
			else{
				textarea.selectionStart = (startIndex);
				textarea.selectionEnd = (startIndex);
			}
		}
		textarea.scrollTop = scrollTop;
	}
	else{ // IE ou Opera
		var starteIndex = startIndex;
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;		
		var nblines = lines.length;
		var changed = false;
		var total = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
			if(indice == -1){
				indice = -2;
			}
			if(textarea.value.substring(indice+2,textarea.value.length).indexOf("   ") == 0){
				textarea.value = textarea.value.substring(0,indice+2)+textarea.value.substring(indice+5,textarea.value.length);
				changed = true;
				total+=3;
			}
		}
		else{
			if(lines != null && lines.length > 0 && false){
				for(var i=0;i<lines.length;i++){
					if(i==0 && lines[i].indexOf("\n\r") == -1){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
						if(indice == -1){
							indice = -2;
						}
						lines[i] = textarea.value.substring(indice+2,startIndex)+lines[i];
						starteIndex = indice;
						pl+=3;
						alert(lines[i].indexOf("   "));
						if(indice != -2){
							if(lines[i].indexOf("   ") == 0){
								lines[i] = lines[i].substring(2,lines[i].length);
								changed = true;
								total+=3;
							}
							finaltext+="\r\n"+lines[i];
						}
						else{
							if(lines[i].indexOf("   ") == 0){
								lines[i] = lines[i].substring(2,lines[i].length);
								changed = true;
								total+=3;
							}
							finaltext+=lines[i];
						}
					}
					else{
						if(lines[i].length == 1){
							finaltext+=lines[i];
						}
						else{
							if(lines[i].length > 0){
								if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
									if(lines[i].indexOf("   ") == 1){
										lines[i] = lines[i].substring(0,1)+lines[i].substring(3,lines[i].length);
										changed = true;
										total+=3;
									}
									finaltext+=lines[i];
									pl+=3;
								}
								else{
									finaltext+=lines[i];
								}
							}
							else{
								finaltext+=lines[i];
							}
						}
					}
				}
			}
			else{
				alert("No multiline with internet explorer");
				finaltext = mySelection;
			}
			var newl = (textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		var nbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			//  IE
			//alert("IE :"+mySelection.length);
			if(mySelection.length == 0){
				if(changed){
					twikismartSetSelectionRange(textarea,(startIndex-3-nbLinesBefore),(startIndex-3-nbLinesBefore));
				}
				else{
					twikismartSetSelectionRange(textarea,(startIndex-nbLinesBefore),(startIndex-nbLinesBefore));
				}
			}
			else{
				//alert("start : "+startIndex+" et apres "+endIndex);
				if(mySelection != null && mySelection.indexOf("\r\n") == -1){
					twikismartSetSelectionRange(textarea,(startIndex-3-nbLinesBefore),(startIndex-3-nbLinesBefore));
				}
				else{
					twikismartSetSelectionRange(textarea,(startIndex-3-nbLinesBefore),(startIndex-3-nbLinesBefore));
				}
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+3),(startIndex+finaltext.length+3));
		}
	}
}

// Insert signature
function twikismartSign(){
	twikismartInitSelectionProperties();
	var sign = document.getElementById("sig");
	if(sign != null){
		textarea.value = (textarea.value).substring(0,startIndex)+sign.value+(textarea.value).substring(endIndex,textarea.value.length);
		textarea.focus();
		var nbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			if(is_gecko){
				twikismartSetSelectionRange(textarea,(startIndex),startIndex+sign.value.length);
				textarea.scrollTop = scrollTop;
			}
			else{
				twikismartSetSelectionRange(textarea,(startIndex-nbLinesBefore),(startIndex+sign.value.length-2));
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndexsign.value.length-2));
		}
		
		
		//txtarea.selectionStart = startIndex;
		//txtarea.selectionEnd = startIndex+mySelection.length+sign.value.length;
	}
}

// Insert date
function twikismartInsertGMTDate(){
	twikismartInitSelectionProperties();
	var date = new Date();
	var sign = document.getElementById("sig");
	
		textarea.value = (textarea.value).substring(0,startIndex)+date.toGMTString()+(textarea.value).substring(endIndex,textarea.value.length);
		textarea.focus();
		var nbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			if(is_gecko){
				twikismartSetSelectionRange(textarea,(startIndex),startIndex+date.toGMTString().length);
				textarea.scrollTop = scrollTop;
			}
			else{
				twikismartSetSelectionRange(textarea,(startIndex-nbLinesBefore),(startIndex+date.toGMTString().length-2));
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2),(startIndexsign.value.length-2));
		}
}

// Insert nop tag
function twikismartNop(){
	twikismartInitSelectionProperties();
	
		textarea.value = (textarea.value).substring(0,startIndex)+"<nop>"+mySelection+(textarea.value).substring(endIndex,textarea.value.length);
		textarea.focus();
		var nbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			if(is_gecko){
				twikismartSetSelectionRange(textarea,(startIndex+"<nop>".length),startIndex+"<nop>".length+mySelection.length);
				textarea.scrollTop = scrollTop;
			}
			else{
				twikismartSetSelectionRange(textarea,(startIndex-nbLinesBefore+"<nop>".length),(startIndex+"<nop>".length+mySelection.length-2));
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2+"<nop>".length),(startIndexs+"<nop>".length+mySelection.length-2));
		}
		
		
		//txtarea.selectionStart = startIndex;
		//txtarea.selectionEnd = startIndex+mySelection.length+sign.value.length;
	
}

// Insert verbatim tags
function twikismartVerbatim(){
	twikismartInitSelectionProperties();
	
		textarea.value = (textarea.value).substring(0,startIndex)+"\n<verbatim>\n"+mySelection+"\n</verbatim>\n"+(textarea.value).substring(endIndex,textarea.value.length);
		textarea.focus();
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			if(is_gecko){
				twikismartSetSelectionRange(textarea,(startIndex+"\n</verbatim>\n".length),startIndex+"\n</verbatim>\n".length+mySelection.length);
				textarea.scrollTop = scrollTop;
			}
			else{
				twikismartSetSelectionRange(textarea,(startIndex-twikismartNbLinesBefore+"\n</verbatim>\n".length),(startIndex-twikismartNbLinesBefore+"\n</verbatim>\n".length+mySelection.length));
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+2+"\n</verbatim>\n".length),(startIndex+"\n</verbatim>\n".length+mySelection.length-2));
		}
}

// Insert external link tag
function twikismartExlink(){
	twikismartInitSelectionProperties();
	if(mySelection.length == 0){
		mySelection = "Your text";
	}
	textarea.value = (textarea.value).substring(0,startIndex)+"[[http://www.yoursite.com]["+mySelection+"]]"+(textarea.value).substring(endIndex,textarea.value.length);
	textarea.focus();
	var nbLinesBefore = twikismartNbLinesBefore(startIndex);
	if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
		if(is_gecko){
			twikismartSetSelectionRange(textarea,(startIndex+"[[http://www.yoursite.com][".length),startIndex+"[[http://www.yoursite.com][".length+mySelection.length);
			textarea.scrollTop = scrollTop;
		}
		else{
			twikismartSetSelectionRange(textarea,(startIndex-nbLinesBefore+"[[http://www.yoursite.com][".length),(startIndex-nbLinesBefore+"[[http://www.yoursite.com][".length+mySelection.length));
		}
	}
	else{ // Pour Opera ... ce n'est pas pareil pour la sélection
		twikismartSetSelectionRange(textarea,(startIndex+2+"[[http://www.yoursite.com][".length),(startIndex+"[[http://www.yoursite.com][".length+mySelection.length-2));
	}
}

// Insert horizontal bar tag
function twikismartInsertHR(){
	twikismartInitSelectionProperties();
	if(startIndex > 0){
		if((textarea.value).charAt(startIndex-1) == "\n" || (textarea.value).charAt(startIndex-1) == "\r"){
			if((textarea.value).charAt(startIndex+1) == "\n" || (textarea.value).charAt(startIndex+1) == "\r"){
				textarea.value = textarea.value.substring(0,startIndex)+"---"+textarea.value.substring(startIndex,(textarea.value).length);
			}
			else{
				textarea.value = textarea.value.substring(0,startIndex)+"---\r"+textarea.value.substring(startIndex,(textarea.value).length);
			}
		}
		else{
			if((textarea.value).charAt(startIndex+1) == "\n" || (textarea.value).charAt(startIndex+1) == "\r"){
				textarea.value = textarea.value.substring(0,startIndex)+"\r---"+textarea.value.substring(startIndex,(textarea.value).length);
			}
			else{
				textarea.value = textarea.value.substring(0,startIndex)+"\r---\r"+textarea.value.substring(startIndex,(textarea.value).length);
			}
		}
	}
	if(is_gecko){
		textarea.scrollTop = scrollTop;
	}
	textarea.focus();
}

// Insert basic table of content tag (%TOC%)
function twikismartInsertSimpleTOC(){
	twikismartInitSelectionProperties();
	if(startIndex > 0){
		if((textarea.value).charAt(startIndex-1) == "\n" || (textarea.value).charAt(startIndex-1) == "\r"){
			if((textarea.value).charAt(startIndex+1) == "\n" || (textarea.value).charAt(startIndex+1) == "\r"){
				textarea.value = textarea.value.substring(0,startIndex)+"%TOC%"+textarea.value.substring(startIndex,(textarea.value).length);
			}
			else{
				textarea.value = textarea.value.substring(0,startIndex)+"%TOC%\r"+textarea.value.substring(startIndex,(textarea.value).length);
			}
		}
		else{
			if((textarea.value).charAt(startIndex+1) == "\n" || (textarea.value).charAt(startIndex+1) == "\r"){
				textarea.value = textarea.value.substring(0,startIndex)+"\r%TOC%"+textarea.value.substring(startIndex,(textarea.value).length);
			}
			else{
				textarea.value = textarea.value.substring(0,startIndex)+"\r%TOC%\r"+textarea.value.substring(startIndex,(textarea.value).length);
			}
		}
	}
	if(is_gecko){
		textarea.scrollTop = scrollTop;
	}
	textarea.focus();
}

// Called by the 2nd select element
function twikismartCommon(){
	var select = document.getElementById("twikismartselectcommon");
	var value = select.value;
		if(value == 1){
		twikismartSign();
	}
	else{
		if(value == 2){
			twikismartInsertGMTDate();
		}
		else{
			if(value == 3){
				// TOC
				twikismartInsertSimpleTOC();
			}
		}
	}
	select.value = 0;
}

// Called by the 1st select element
function twikismartInsertFormat(){
	var select = document.getElementById("twikismartselect");
	var value = select.value;
	//alert("value :"+value);
	if(value == 0){
		twikismartInsertFixed();
	}
	else{
		if(value == 1){
			twikismartFormatText("---+ ");
		}
		else{
			if(value == 2){
				twikismartFormatText("---++ ");
			}
			else{
				if(value == 3){
					twikismartFormatText("---+++ ");
				}
				else{
					if(value == 4){
						twikismartFormatText("---++++ ");
					}
					else{
						if(value == 5){
							twikismartFormatText("---+++++ ");
						}
						else{
							if(value == 6){
								twikismartFormatText("---++++++ ");
							}
							else{
								if(value == 7){
									twikismartFormatText(" \n");
								}
								else{
									if(value == 10){
										twikismartVerbatim();
									}
								}
							}
						}
					}
				}
			}
		}
	}
	select.value = 9;
}

// Insert given format to the selection
function twikismartFormatText(tag){
	textarea.focus();
	twikismartInitSelectionProperties();
	var finaltext = "";
	//alert(startIndex+"-"+endIndex);
	var dg = 0;
	var dd = 0;
	if(mySelection.length == 0){
		mySelection = "";
	}
	if(is_gecko){ // Firefox ou mozilla
		var lines = twikismartGetFirefoxLines();
		finaltext = "";
		var tmp = "";
		var endSelect = 0;
		var starteIndex = startIndex;
		var nblines = lines.length;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
			textarea.value = textarea.value.substring(0,indice+1)+tag+textarea.value.substring(indice+1,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\n");
						if(indice == -1){
							indice = 0;
						}
						lines[i] = textarea.value.substring(indice,startIndex)+lines[i];
						starteIndex = indice;
						endSelect = lines[i].length;
					}
					if(lines[i].length != 0 && !(lines[i].length == 1 && lines[i].indexOf("\n") == 0)){
						if(i==0 && lines[i].indexOf("\n") == -1){
							tmp+=tag+lines[i];
						}
						else{
							if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
								tmp+=lines[i].substring(0,1)+tag+lines[i].substring(1,lines[i].length);
							}
							else{
								tmp+=lines[i];
							}
						}
					}
					else{
						tmp+=lines[i];
					}
				}
				finaltext = tmp;
			}
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		//alert(startIndex);
		textarea.selectionStart = (startIndex+tag.length);
		if(mySelection.length > 0){
			textarea.selectionEnd = startIndex+(tag.length)*nblines+mySelection.length;
		}
		else{
			textarea.selectionEnd = (startIndex+tag.length);
		}
		textarea.scrollTop = scrollTop;
	}
	else{ // IE ou Opera
		var starteIndex = startIndex;
		old_length = textarea.value.length;
		var lines = twikismartGetIELines();
		finaltext = "";
		var pl = 0;
		if(mySelection.length == 0){
			var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
			if(indice == -1){
				indice = -2;
			}
			textarea.value = textarea.value.substring(0,indice+2)+tag+textarea.value.substring(indice+2,textarea.value.length);
		}
		else{
			if(lines != null && lines.length > 0){
				for(var i=0;i<lines.length;i++){
					if(i==0 && lines[i].indexOf("\n\r") == -1){
						var indice = (textarea.value.substring(0,startIndex)).lastIndexOf("\r\n");
						if(indice == -1){
							indice = -2;
						}
						lines[i] = textarea.value.substring(indice+2,startIndex)+lines[i];
						starteIndex = indice;
						pl+=tag.length;
						if(indice != -2){
							finaltext+="\r\n"+tag+lines[i];
							
						}
						else{
							finaltext+=tag+lines[i];
						}
					}
					else{
						if(lines[i].length == 1){
							finaltext+=lines[i];
						}
						else{
							if(lines[i].length > 0){
								if(!twikismartIsEmptyString(lines[i].substring(1,lines[i].length))){
									finaltext+=lines[i].substring(0,1)+tag+lines[i].substring(1,lines[i].length);
									pl+=tag.length;
								}
								else{
									finaltext+=lines[i];
								}
							}
							else{
								finaltext+=lines[i];
							}
						}
					}
				}
			}
			var newl = (textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length)).length;
			textarea.value = textarea.value.substring(0,starteIndex)+finaltext+textarea.value.substring(endIndex,textarea.value.length);
		}
		var twikismartNbLinesBefore = twikismartNbLinesBefore(startIndex);
		if(navigator.userAgent.toLowerCase().indexOf("opera") == -1){
			//  IE
			//alert("IE :"+mySelection.length);
			if(mySelection.length == 0){
				twikismartSetSelectionRange(textarea,(startIndex+3-twikismartNbLinesBefore),(startIndex+3-twikismartNbLinesBefore));
			}
			else{
				//alert("start : "+startIndex+" et apres "+endIndex);
				if(mySelection != null && mySelection.indexOf("\r\n") == -1){
					twikismartSetSelectionRange(textarea,(startIndex+tag.length-twikismartNbLinesBefore),(endIndex+tag.length-twikismartNbLinesBefore));
				}
				else{
					twikismartSetSelectionRange(textarea,(startIndex+tag.length-twikismartNbLinesBefore),(startIndex+tag.length-twikismartNbLinesBefore));
				}
			}
		}
		else{ // Pour Opera ... ce n'est pas pareil pour la sélection
			twikismartSetSelectionRange(textarea,(startIndex+tag.length),(startIndex+finaltext.length+tag.length));
		}
	}
}

// Enlarge textarea rows value
function twikismartZoomIn(){
	textareasize = textarea.rows+1;
	textarea.rows = textarea.rows+1;
}

function twikismartZoomOut(){
	textareasize = textarea.rows-1;
	textarea.rows = textarea.rows-1;
}

// Set the textarea rows value to the number of lines in the text
function twikismartAdjust(){
	if(is_gecko){
		var temp = mySelection;
		mySelection = textarea.value;
		var lines = twikismartGetFirefoxLines();
		if(lines != null && lines.length > 0){
			textarea.rows = lines.length;
		}
		mySelection = temp;
	}
	else{
		var temp = mySelection;
		mySelection = textarea.value;
		var lines = twikismartGetIELines();
		if(lines != null && lines.length > 0){
			textarea.rows = lines.length;
		}
		mySelection = temp;
	}
}