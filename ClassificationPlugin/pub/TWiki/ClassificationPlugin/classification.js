
var prevHiliteElements = new Array();
function hiliteElements (elemNames, className) {
  setClassOfNames(prevHiliteElements,'');
  elemNames = elemNames.split(/\s*,\s*/);
  prevHiliteElements = elemNames;
  setClassOfNames(elemNames, className);
}

function setClassOfNames(elemNames, className) {
  if (!elemNames)
    return;
  for (var i = 0; i < elemNames.length; i++) {
    if (elemNames[i]) {
      var elems = document.getElementsByName(elemNames[i]);
      if (elems) {
        setClassOfElems(elems, className);
      }
    }
  }
}

function setClassOfElems(elems, className) {
  if (!elems)
    return;
  for (var i = 0; i < elems.length; i++) {
    elems[i].className = className;
  }
}

/* TODO: this is only used by the category editor; so make the category editor
 * a proper jquery plugin like the jquery.tagselector component
 */
function toggleValue(fieldName, theValue, selector) {
  writeDebug("toggleValue("+fieldName+","+theValue+","+selector+")");

  var values = $("input#"+fieldName).val() || '';
  writeDebug("values="+values);
  values = values.split(/\s*,\s*/);

  clsClearSelection(fieldName, selector, values);

  var found = false;
  var newValues = new Array();
  for (var i = 0; i < values.length; i++)  {
    var value = values[i];
    if (!value)
      continue;
    if (value == theValue) {
      found = true;
    } else {
      newValues.push(value);
    }
  }

  if (!found) {
    newValues.push(theValue)
  }

  clsSetSelection(fieldName, selector, newValues);
}
function clsSetSelection(fieldName, selector, values) {
  if (typeof(values) == 'string') {
    values = values.split(/\s*,\s*/);
  }

  for (var i = 0; i < values.length; i++) {
    if (values[i]) {
      $("#"+selector+" a."+values[i]).addClass("current");
    }
  }
  $("input#"+fieldName).val(values.sort().join(", "));
}
function clsClearSelection(fieldName, selector, values) {
  /*$("#"+selector+" input#"+fieldName).val("");
  $("#"+selector+" a").removeClass('current');
  $("#"+selector+" a").removeClass('typed');*/
  writeDebug("clsClearSelection("+fieldName+","+selector+","+values+")");

  if (typeof(values) == 'undefined') {
    $("#"+selector+" a").removeClass('current hover typed');
  } else {
    for (var i = 0; i < values.length; i++) {
      $("#"+selector+" a."+values[i]).removeClass("current hover typed");
    }
  }
  $("#"+selector+" input#"+fieldName).val("");
}

var clsDebug = 0;
function writeDebug(msg) {
  if (clsDebug) {
    msg = "DEBUG: ClassSelector - "+msg;
    if (window.console && window.console.log) {
      window.console.log(msg);
    } else { 
      //alert(msg);
    }
  }
};

