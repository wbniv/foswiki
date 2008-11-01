function beforeSubmitHandler(script, action) {
  //alert("called beforeSubmitHandler");
  var before = document.getElementById('beforetext');
  var after = document.getElementById('aftertext');
  var chapter = document.getElementById('topic');

  if (!before || !after || !chapter) 
    return;

  var chapterText = chapter.value;
  var lastChar = chapterText.substr(chapterText.length-1, 1);
  if (lastChar != '\n') {
    chapterText += '\n';
  }
  var text = document.getElementById('text');
  text.value = before.value+chapterText+after.value;
}

/* init gui */
if (true) {
  $(function() {
    $('.ecpHeading').each(function(){
      var $ecpEdit = $('.ecpEdit', this);
      if ($ecpEdit.length) {
        $(this).hover(
          function(event) {
            $(this).addClass('ecpHeadingHover');
            $ecpEdit.css('visibility','visible');
            event.stopPropagation();
          },
          function(event) {
            $(this).removeClass('ecpHeadingHover');
            $ecpEdit.css('visibility','hidden');
            event.stopPropagation();
          }
        ); 
      }
    });
  });
}
