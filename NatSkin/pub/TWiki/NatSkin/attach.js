/* toggle the attachment editor */
var lastElem;
function toggleAttachmentEditor(elem, state) {

  if (lastElem && lastElem != elem) {
    toggleAttachmentEditor(lastElem, 'off');
  }

  var $elemStep = $(elem).parents(".twikiFormStep"); 
  var $editor = $elemStep.find("#natAttachmentEditor");
  var $comment = $elemStep.find(".natAttachmentComment");
  var text = $editor.find("textarea").text();

  if (state == 'off') {
    $editor.slideUp('fast');
    if (!isEmptyComment($comment)) {
      $comment.show();
    }
    lastElem = '';
  } else {
    lastElem = elem;
    if ($editor.is(":visible")) {
      if (!isEmptyComment($comment)) {
        $comment.show();
      }
    } else {
      $comment.hide();
    }
    $editor.slideToggle('fast');
  }
}

/* check if the comment of an attachment is empty;
 * the core inserts an &nbsp; thats why this is a bit
 * more complicated
 */
function isEmptyComment ($comment) {
  var text = $comment.text();
  return text.length == 1 && text.charCodeAt(0) == 160;
}
