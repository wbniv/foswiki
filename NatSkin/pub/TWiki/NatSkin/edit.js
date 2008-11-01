// copied and adapted from phpBB
// copied and adapted from MediaWiki

var txtarea;

// apply tagOpen/tagClose to selection in textarea,
// use sampleText instead of selection if there is none
function natInsertTags(tagOpen, tagClose, sampleText) {
  // IE
  if (document.selection) {
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
    var myText = (txtarea.value).substring(startPos, endPos);

    if (endPos - startPos > 0) {
      replaced = true;
    }
    if (!myText) {
      myText = sampleText;
    }
    if (myText.charAt(myText.length - 1) == " ") { 
      // exclude ending space char, if any
      subst = tagOpen + myText.substring(0, (myText.length - 1)) + tagClose + " ";
    } else {
      subst = tagOpen + myText + tagClose;
    }
    txtarea.value = 
      txtarea.value.substring(0, startPos) + subst +
      txtarea.value.substring(endPos, txtarea.value.length);

    txtarea.focus();

    //set new selection
    if (replaced) {
      var cPos = startPos + tagOpen.length + myText.length + tagClose.length;
      txtarea.selectionStart = cPos;
      txtarea.selectionEnd = cPos;
    } else {
      txtarea.selectionStart = startPos + tagOpen.length;
      txtarea.selectionEnd = startPos + tagOpen.length + myText.length;
    }
    txtarea.scrollTop = scrollTop;
  }

  if (txtarea.createTextRange) {
    txtarea.caretPos = document.selection.createRange().duplicate();
  }
}

// button functions
function natEditBoldButtonAction() {
  natInsertTags('*', '*', 'Bold text');
}
function natEditItalicButtonAction() {
  natInsertTags('_', '_', 'Italic text');
}
function natEditUnderlinedButtonAction() {
  natInsertTags('<u>', '</u>', 'Underlined text');
}
function natEditStrikeButtonAction() {
  natInsertTags('<strike>', '</strike>', 'Strike through text');
} 
function natEditSubButtonAction() {
  natInsertTags('<sub>', '</sub>', 'Subscript text');
}
function natEditSupButtonAction() {
  natInsertTags('<sup>', '</sup>', 'Superscript text');
}

function natEditLeftButtonAction() {
  natInsertTags('<div style=\'text-align:left\'>\n','<\/div>\n','Align left');
}
function natEditRightButtonAction() {
  natInsertTags('<div style=\'text-align:right\'>\n','<\/div>\n','Align right');
}
function natEditJustifyButtonAction() {
  natInsertTags('<div style=\'text-align:justify\'>\n','<\/div>\n','Justify text');
}
function natEditCenterButtonAction() {
  natInsertTags('<center>\n','<\/center>\n','Center text');
}
function natEditExtButtonAction() {
  natInsertTags('[[http://...][',']]','link text');
}
function natEditIntButtonAction() {
  natInsertTags('[[',']]','web.topic][link text');
}
function natEditHeadlineButtonAction(level) {
  if (level == 2) {
    natInsertTags('\n---++ ','\n','Headline text');
  } else if (level == 3) {
    natInsertTags('\n---+++ ','\n','Headline text');
  } else if (level == 4) {
    natInsertTags('\n---++++ ','\n','Headline text');
  } else if (level == 5) {
    natInsertTags('\n---+++++ ','\n','Headline text');
  } else if (level == 6) {
    natInsertTags('\n---++++++ ','\n','Headline text');
  } else {
    natInsertTags('\n---+ ','\n','Headline text');
  }
}
function natEditImageButtonActionStandard() {
  natInsertTags('<img class=\'border alignleft\' src=\'%ATTACHURLPATH%/','\' title="Example" />','Example.jpg');
}
function natEditImageButtonActionImagePlugin() {
  natInsertTags('%IMAGE{"','|400px|Caption text|frame|center"}%','Example.jpg');
}
function natEditMathButtonAction() {
  natInsertTags('<latex title="Example">\n','\n</latex>','\\LaTeX'); // inline
}
function natEditVerbatimButtonAction() {
  natInsertTags('<verbatim>','<\/verbatim>','Insert non-formatted text here');
}
function natEditSignatureButtonAction(date, wikiUserName) {
  natInsertTags('=--= ',date,wikiUserName);
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
  var topBarHeight = document.getElementById("natTopLeftBarSizer").clientHeight || 0;
  var offset;
  if (height) {
    offset = txtarea.offsetTop;
    height = height-offset-80-topBarHeight;
    txtarea.style.height = height + "px";
  }
  //alert("height="+height+", offset="+offset+", topBarHeight="+topBarHeight);
  setTimeout("establishOnResize()", 100); /* add a slight timeout not to DoS IE */
}
function establishOnResize() {
  window.onresize = fixHeightOfTheText;
}

function natSetupEdit() {
  if (document.EditForm) {
    txtarea = document.EditForm.natEditTextArea;
  } else {
    // some alternate form? take the first one we can find
    //var areas = document.getElementsByTagName('textarea');
    txtarea = areas[0];
  }
  fixHeightOfTheText();
  establishOnResize();


  return true;
}

addLoadEvent(natSetupEdit);
