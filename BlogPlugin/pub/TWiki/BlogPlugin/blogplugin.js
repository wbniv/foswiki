// add/remove a tag in an input field
// theID: name of the input field
// theTag: the tag
function toggleTag(fieldName, theTag) {
    var inputField = document.EditFormular[fieldName];
    if (inputField) {
      var fieldValue = inputField.value;
      fieldValue = fieldValue.replace(/,/g,"");
      var tags = fieldValue.split(" ");
      var newTags = new Array();
      var found = false;
      for (var i = 0; i < tags.length; i++)  {
	var tag = tags[i];
	if (tag == theTag) {
	  found = true;
	} else {
	  newTags.push(tag);
	}
      }
      if (!found) {
	newTags.push(theTag)
      }
      newTags.sort();
      inputField.value = newTags.join(" ");
    /*
    } else {
      window.alert("Warning: field '"+fieldName+"' not found in the edit formular");
    */
    }
}
