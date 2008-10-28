/**
 * TWiki setups wrt jQuery
 *
 * $Rev$
*/

twiki.JQueryPlugin = new function () {
  var self = this;
}

/**
  * Animate the target object.
  * This is called by a %TOGGLE% button
  * @public
  * @param target : (String or expression) jquery expression
  * @param effet : "fade|slide|fadeslide"
  * @return the target jquery object
*/
twiki.JQueryPlugin.toggle = function(target, effect) {
  switch (effect) {
    case "fade":
      $(target).animate(
        {height:'toggle', opacity:'toggle'},"fast"
      );
      break;
    case "slide":
      $(target).slideToggle("fast");
      break;
    case "ease":
      $(target).slideToggle({duration:500, easing:'easeinout'});
      break;
    case "bounce":
      if ($(target).is(":visible")) {
        $(target).slideUp({ duration:500, easing:'easeinout'});
      } else {
        $(target).slideDown({ duration:1000, easing:'bounceout'});
      }
      break;
    case "toggle":
    default:
      return $(target).toggle();
      break;
  }

  return $(target);
}

/**
 * make live easier with wrt rounded corners
 */
$.fn.extend({
  roundedCorners: function() {

    return this.each(function() {
      var cls = $(this).attr('class');

      var h2args = '';
      var divargs = '';
      var foundsize = false;
      var foundh2 = false;
      var foundcorner = false;

      if ($(this).children().is("h2")) foundh2 = true;

      if (cls.match(/\bsame-height\b/)) 
        divargs += " same-height";
      if (cls.match(/\bfixed-height\b/)) 
        divargs += " fixed-height";
      if (cls.match(/\btransparent\b/)) {
        h2args += " transparent";
        divargs += " transparent";
      }

      if (cls.match(/\btl\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tl";
          divargs += " none";
        } else
          divargs += " tl";
      }
      if (cls.match(/\btr\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tr";
          divargs += " none";
        } else
          divargs += " tr";
      }
      if (cls.match(/\bbl\b/)) {
        foundcorner = true;
        h2args += " none";
        divargs += " bl";
      }
      if (cls.match(/\bbr\b/))  {
        foundcorner = true;
        h2args += " none";
        divargs += " br";
      }
      if (cls.match(/\bbottom\b/)) {
        foundcorner = true;
        if (foundh2) 
          h2args += " none";
        divargs += " bottom";
      }

      if (cls.match(/\bleft\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tl";
          divargs += " bl";
        } else {
          divargs += " left";
        }
      }
      if (cls.match(/\btop\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " top";
          divargs += " none";
        } else {
          divargs += " top";
        }
      }
      if (cls.match(/\bright\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tr";
          divargs += " br";
        } else {
          divargs += " right";
        }
      }
      if (cls.match(/\bnone\b/)) {
        foundcorner = true;
        h2args += " none";
        divargs += " none";
      }
      if (cls.match(/\bsmall\b/)) { 
        h2args += " small"; 
        divargs += " small"; 
        foundsize = true; 
      }
      if (cls.match(/\bnormal\b/)) { 
        h2args += " normal"; 
        divargs += " normal"; 
        foundsize = true; 
      }
      if (cls.match(/\bbig\b/)) { 
        h2args += " big"; 
        divargs += " big"; 
        foundsize = true; 
      }
      if (!foundsize) { 
        h2args += " big"; 
        divargs += " big"; 
      }
      if (!foundcorner) {
        if (foundh2) {
          h2args += " top";
          divargs += " bottom";
        }
      }

      if (foundh2) {
        $("h2",this).nifty(h2args);
      }
      //$(this).nifty(divargs);
    });
  }
});

/* init */
$(function(){

  /********************************************************
   * treeview stuff
   */
  if (true) {
    $(".jqTreeview > ul").each(function(){
      var args = Array();
      var parentClass = $(this).parent().attr('class');
      args['speed'] = 'fast';
      if (parentClass.match(/\bopen\b/)) {
        args['collapsed'] = false;
      }
      if (parentClass.match(/\bclosed?\b/)) {
        args['collapsed'] = true;
      }
      if (parentClass.match(/\bunique\b/)) {
        args['unique'] = true;
      }
      $(this).Treeview(args);
    });
  }

  /********************************************************
   * shrink urls in TWikiTables lists
   */
  if (true) {
    $(".twikiTable a").shrinkUrls({size:25});
  }

  /********************************************************
   * jquery buttons using "unobstructive html"
   * disabled in favour of %BUTTON% tag
   */
  if (false) {
    $('.jqButton').each(function(){
      var b = $(this);
      var tt = b.text();
      b.text('').prepend('<i></i>').append(
        $('<span>').text(tt).append('<i></i><span></span>')
      );
    });
  }

  /********************************************************
   * tooltips 
   */
  if (true) { /* lazy initialization */
    $("body").one('mouseover',
      function(event) {
        $("a,span,input").Tooltip({
          delay:250,
          track:true,
          showURL:false,
          extraClass:'twiki',
          showBody:": "
        });//.css('background','pink');
      }
    );
  }

  /********************************************************
   * rounded corners using nifty 
   */
  if (true) {
    $(".jqRounded").roundedCorners();
  }

  /********************************************************
   * twikiToc stuff
   */

  /* add a toggle switch */

  if (false) {
    $(".twikiToc").each(function() { 
      $(this).prepend("<a class='twikiTocToggle'>[hide]</a>")
    });

    /* behaviour of the twiki toggle switch */
    $(".twikiTocToggle").
      css("float","right").
      click(function() {
        $("> ul",$(this).parent()).slideToggle({easing:'easeinout', duration:300});
        if($(this).text() == "[hide]") {
          $(this).text("[show]");
        } else {
          $(this).text("[hide]");
        }
      });
  }
  $(".jqTreeview").css('display', 'block');
});
