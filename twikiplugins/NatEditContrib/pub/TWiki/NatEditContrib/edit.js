// copied and adapted from phpBB
// copied and adapted from MediaWiki
// IE range selection adapted from http://twiki.org/cgi-bin/view/Plugins/SmartEditAddOn

var txtarea;

var isOpera=window.opera?1:0;

// apply tagOpen/tagClose to selection in textarea,
// use sampleText instead of selection if there is none
function natInsertTags(tagOpen, sampleText, tagClose) {
  // IE
  if (document.selection && !isOpera) {
    var theSelection = document.selection.createRange().text;

    if (!theSelection) {
      theSelection = sampleText;
    }

    txtarea.focus();

    if (theSelection.charAt(theSelection.length - 1) == " ") { 
      // exclude ending space char, if any
      theSelection = theSelection.substring(0, theSelection.length - 1);
      document.selection.createRange().text = tagOpen + theSelection + tagClose + " ";
    } else {
      document.selection.createRange().text = tagOpen + theSelection + tagClose;
    }

  // Mozilla
  } else if (txtarea.selectionStart || txtarea.selectionStart == '0') {
    var replaced = false;
    var startPos = txtarea.selectionStart;
    var endPos = txtarea.selectionEnd;
    var scrollTop = txtarea.scrollTop;
    var theSelection = (txtarea.value).substring(startPos, endPos);

    if (endPos - startPos > 0) {
      replaced = true;
    }
    if (!theSelection) {
      theSelection = sampleText;
    }
    if (theSelection.charAt(theSelection.length - 1) == " ") { 
      // exclude ending space char, if any
      subst = tagOpen + theSelection.substring(0, (theSelection.length - 1)) + tagClose + " ";
    } else {
      subst = tagOpen + theSelection + tagClose;
    }
    txtarea.value = 
      txtarea.value.substring(0, startPos) + subst +
      txtarea.value.substring(endPos, txtarea.value.length);

    txtarea.focus();

    //set new selection
    if (replaced) {
      var cPos = startPos + tagOpen.length + theSelection.length + tagClose.length;
      txtarea.selectionStart = cPos;
      txtarea.selectionEnd = cPos;
    } else {
      txtarea.selectionStart = startPos + tagOpen.length;
      txtarea.selectionEnd = startPos + tagOpen.length + theSelection.length;
    }
    txtarea.scrollTop = scrollTop;
  }

  if (txtarea.createTextRange) {
    txtarea.caretPos = document.selection.createRange().duplicate();
  }
}

// used for line oriented tags - like bulleted lists
// if you have a multiline selection, the tagOpen/tagClose is added to each line
// if there is no selection, select the entire current line
// if there is a selection, select the entire line for each line selected
function natInsertListTag(tagOpen, sampleText, tagClose) {
  var cursorPos = getCursorPosition();
  var startPos, endPos;
  startPos = cursorPos.startPos;
  endPos = cursorPos.endPos;

  // at this point we need to expand the selection to the \n before the startPos, and after the endPos
  var adjustedStartPos = txtarea.value.lastIndexOf('\n', startPos-1);
  if (adjustedStartPos == -1) {
    startPos = 0; // first line in textarea has no \n
  } else if (adjustedStartPos < startPos) {
    startPos = adjustedStartPos+1;
  }

  var adjustedEndPos = txtarea.value.indexOf('\n', endPos);
  if (adjustedEndPos == -1) {
    endPos = txtarea.value.length; // first line in textarea has no \n
  } else if ((adjustedEndPos > endPos) && 
    (txtarea.value.charAt(endPos) != '\n')  && 
    (txtarea.value.charAt(endPos) != '\r')) {
    endPos = adjustedEndPos;
  }
 
  var scrollTop = txtarea.scrollTop;
  var theSelection = (txtarea.value).substring(startPos, endPos);

  if (!theSelection) {
    theSelection = sampleText;
  }
    
  var pre = txtarea.value.substring(0, startPos);
  var post = txtarea.value.substring(endPos, txtarea.value.length);
    
  // test if it is a multi-line selection, and if so, add tagOpen&tagClose to each line
  var lines = theSelection.split(/\r?\n/);
  var modifiedSelection = '';
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    
    // special case - undent (remove 3 spaces, and bullet or numbered list if outdenting away)
    if ((tagOpen == '') && (sampleText == '') && (tagClose == '')) {
      subst = line.replace(/^   (\* |\d+ |\d+\. )?/, '');
    } else {
      if (line.match(/^(   )*(   (\*|\d+|\d+\.) )/) &&
          (tagOpen.match(/^(   )*(   (\*|\d+|\d+\.) )/))) {
        subst = line.replace(/   (\* |\d+ |\d+\. )/, tagOpen);
      } else {
        subst = tagOpen + line + tagClose;
      }
    }

    modifiedSelection = modifiedSelection + subst;
    if (i+1 < lines.length) 
      modifiedSelection = modifiedSelection + '\n';
  }

  txtarea.value = pre + modifiedSelection + post;

  if (document.selection && !isOpera) {
    //IE
    txtarea.focus();
    var range = txtarea.createTextRange();
    range.collapse(true);
             
    var ctrlR = pre.replace(/[^\r]/g, '');     //ranges don't seem to 'count' the \r chars :/
              
    range.moveStart("character", startPos-ctrlR.length);
    range.moveEnd("character", modifiedSelection.length);
    range.select();
  } else {
    txtarea.focus();
    //set new selection
    var cPos = startPos + modifiedSelection.length;
    txtarea.selectionStart = startPos;
    txtarea.selectionEnd = cPos;
    txtarea.scrollTop = scrollTop;
  }
}


function submitEditForm(script, action) {
  document.main.elements['action_preview'].value = '';
  document.main.elements['action_save'].value = '';
  document.main.elements['action_checkpoint'].value = '';
  document.main.elements['action_cancel'].value = '';
  document.main.elements['action_' + action].value = 'foobar';
  document.main.submit();
}

function getWindowHeight () {
  if( typeof( window.innerWidth ) == 'number' ) {
    //Non-IE
    return window.innerHeight;
  } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
    //IE 6+ in 'standards compliant mode'
    return document.documentElement.clientHeight;
  } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
    //IE 4 compatible
    return document.body.clientHeight;
  }
  return 0; // outch
}

function getWindowWidth () {
  if( typeof( window.innerWidth ) == 'number' ) {
    //Non-IE
    return window.innerWidth;
  } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
    //IE 6+ in 'standards compliant mode'
    return document.documentElement.clientWidth;
  } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
    //IE 4 compatible
    return document.body.clientWidth;
  }
  return 0; // outch
}

function fixHeightOfTheText() {
  window.onresize = null; /* disable onresize handler */
  var height = getWindowHeight();
  var offset;
  if (height) {
    offset = txtarea.offsetTop;
    height = height-offset-80;
    txtarea.style.height = height + "px";
  }
  setTimeout("establishOnResize()", 100); /* add a slight timeout not to DoS IE */
}

function establishOnResize() {
  window.onresize = fixHeightOfTheText;
}


function natEditInit() {
  if (txtarea) {
    //alert("txtarea is already "+txtarea);
  } else {
    if (document.main) { // patternskin
      txtarea = document.main.text;
    } else if (document.EditForm) { // natskin
      txtarea = document.EditForm.text;
    } else {
      // some alternate form? take the first one we can find
      var areas = document.getElementsByTagName('textarea');
      txtarea = areas[0];
    }
  }
  fixHeightOfTheText();
  establishOnResize();

  if (twiki.JQueryPluginEnabled) {

    // establish the table dialog
    $(function() { 
      // cache the question element 
      var natEditTableDialog = $('#natEditTableDialog')[0]; 
 
      // table button 
      $('#natEditTableButtonLink').href='';
      $('#natEditTableButtonLink').click(function() { 

       if (document.selection && !isOpera) {
          var cursorPos = getCursorPosition();
          $.startPos = cursorPos.startPos;
          $.endPos = cursorPos.endPos;

        } // end IE

        $.blockUI(natEditTableDialog, { width: '275px' }); 
        return false; 
      }); 
 
      // dialog buttons
      $('#yes').click(function() { 
        // read the rows&col's and create table to that spec
        var rows = $('#rows').val()
        var cols = $('#columns').val();
        $.unblockUI(); 
            
        var newTable = '\n';
        for (var i = 0; i < rows; i++) {
          newTable += '|';
          for (var j = 0; j < cols; j++) {
            if (i == 0) {
              newTable += ' ** ';
            } else {
              newTable += '   ';
            }
            newTable += ' |';
          }
          newTable += '\n';
        }
        txtarea.focus();
        //TODO: where in the table shall we place the cursor?
        // help IE out by re-selecting what was selected before :(
        if (document.selection && !isOpera) {          //IE
            ieSelect($.startPos, $.endPos);
         }
        natInsertTags('','',newTable);

        return false; 
      }); 
 
      $('#cancel').click(function() {
        $.unblockUI();
                
        txtarea.focus();
        // help IE out by re-selecting what was selected before :(
        if (document.selection && !isOpera) {          //IE
            ieSelect($.startPos, $.endPos);
         }
      }); 
    }); 
  }
  
  return true;
}

/* override twiki default one as it generates a null value error because
 * we don't have a signature box 
 */
function setEditBoxFontStyle(inFontStyle) {
  if (inFontStyle == EDITBOX_FONTSTYLE_MONO) {
    replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
    writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
  } else {
    replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
    writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
  }
}


function getCursorPosition() {
   var cursorPos = {};
   if (document.selection && !isOpera) {    // IE
    var originalRange = document.selection.createRange().duplicate();
    var mySelection = originalRange.text;

    if (mySelection != null) {
      cursorPos.endPos = mySelection.length;
    } else {
      cursorPos.endPos = 0;
    }

    { // SMELL: put that in a local function to prevent redundancy further down
      // nasty cursor stuff - as createRange stuff breaks when you don't have a selection
      txtarea.focus();
      var txtareaText = txtarea.value; // backup
      var c  = "\001";
      var sel = document.selection.createRange();
      var dul = sel.duplicate(); 
      dul.moveToElementText(txtarea);
      sel.text = c;
      // seems there is a problem with counting \r's IE
      var tempText = dul.text;
      sel.moveStart('character',-1);
      var tempText = tempText.substring(0, tempText.indexOf(c));
      cursorPos.startPos  = tempText.length;
      txtarea.value = txtareaText; // restore
    }
    cursorPos.endPos+= cursorPos.startPos;
    
    //alert(startPos+', '+endPos);
  } else { 
    // FF, opera safari, etc
 
    cursorPos.startPos = txtarea.selectionStart;
    cursorPos.endPos = txtarea.selectionEnd;
  }
  return cursorPos;
}

function ieSelect(startPos, endPos) {
   var range = txtarea.createTextRange();
   range.collapse(true);
   //adjust start&end for \r's
   var tempStart = txtarea.value.substring(0, startPos);
   tempStart = tempStart.replace(/[\r]/g, ''); 
   var temp = txtarea.value.substring(startPos, endPos);
   temp = temp.replace(/[\r]/g, ''); 

    range.moveStart("character", tempStart.length);
    range.moveEnd("character", temp.length);
    range.select();
}

addLoadEvent(natEditInit);
