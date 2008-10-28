/* slidy.js

   Copyright (c) 2005 W3C (MIT, ERCIM, Keio), All Rights Reserved.
   W3C liability, trademark, document use and software licensing
   rules apply, see:

   http://www.w3.org/Consortium/Legal/copyright-documents
   http://www.w3.org/Consortium/Legal/copyright-software
*/

var ns_pos = (typeof window.pageYOffset!='undefined');
var khtml = ((navigator.userAgent).indexOf("KHTML") >= 0 ? true : false);
var opera = ((navigator.userAgent).indexOf("Opera") >= 0 ? true : false);

window.onload = startup; // equivalent to onload on body element

// IE only event handlers to ensure all slides are printed
// I don't yet know how to emulate these for other browsers
window.onbeforeprint = beforePrint;
window.onafterprint = afterPrint;

// hack to hide slides while loading
setTimeout(hideAll, 50);

function hideAll()
{
  if (document.body)
    document.body.style.visibility = "hidden";
  else
    setTimeout(hideAll, 50);
}

var slidenum = 0;     // integer slide count: 0, 1, 2, ...
var slides;           // set to array of slide div's
var slideNumElement;  // element containing slide number
var notes;            // set to array of handout div's
var backgrounds;      // set to array of background div's
var toolbar;          // element containing toolbar
var title;            // document title
var lastShown = null; // last incrementally shown item
var eos = null;       // span element for end of slide indicator
var toc = null;       // table of contents

var viewAll = 0;      // 1 to view all slides + handouts
var wantToolbar = 1;   // 0 if toolbar isn't wanted
var mouseClickEnabled = true;  // enables left click for next slide
var scrollhack = 0;   // IE work around for position: fixed

var helpAnchor;  // used for keyboard focus hack in showToolbar()
var helpPage = "http://www.w3.org/Talks/Tools/Slidy/help.html";
var helpText = "Navigate with mouse click, space bar, Cursor Left/Right, " +
               "or Pg Up and Pg Dn. Use S and B to change font size.";

var sizeIndex = 0;
var sizeAdjustment = 0;
var sizes = new Array("10pt", "12pt", "14pt", "16pt", "18pt", "20pt",
                      "22pt", "24pt", "26pt", "28pt", "30pt", "32pt");

var okayForIncremental = incrementalElementList();

// needed for efficient resizing
var lastWidth = 0;
var lastHeight = 0;

// Needed for cross browser support for relative width/height on
// object elements. The work around is to save width/height attributes
// and then to recompute absolute width/height dimensions on resizing
var objects;

/* general initialization */
function startup()
{
   document.body.style.visibility = "visible";
   title = document.title;
   toolbar = addToolbar();
   wrapImplicitSlides();
   slides = collectSlides();
   notes = collectNotes();
   objects = document.body.getElementsByTagName("object");
   backgrounds = collectBackgrounds();
   patchAnchors();
   slidenum = findSlideNumber(location.href);
   window.offscreenbuffering = true;
   sizeAdjustment = findSizeAdjust();
   hideImageToolbar();  // suppress IE image toolbar popup
   initOutliner();  // activate fold/unfold support

   if (slides.length > 0)
   {
      var slide = slides[slidenum];
      slide.style.position = "absolute";
   
      if (slidenum > 0)
      {
         setVisibilityAllIncremental("visible");
         lastShown = previousIncrementalItem(null);
         setEosStatus(true);
      }
      else
      {
         lastShown = null;
         setVisibilityAllIncremental("hidden");
         setEosStatus(!nextIncrementalItem(lastShown));
      }

      setLocation();
   }

   toc = tableOfContents();
   hideTableOfContents();

   // bind even handlers
   document.onclick = mouseButtonClick;
   document.onkeydown = keyDown;
   window.onresize  = resized;
   window.onscroll = scrolled;
   singleSlideView();

   setLocation();
   resized();
   showToolbar();
}

// suppress IE's image toolbar pop up
function hideImageToolbar()
{
  if (!ns_pos)
  {
    var images = document.getElementsByTagName("IMG");

    for (var i = 0; i < images.length; ++i)
      images[i].setAttribute("galleryimg", "no");
  }
}

// hack to persuade IE to compute correct document height
// as needed for simulating fixed positioning of toolbar
function ieHack()
{
   window.resizeBy(0,-1);
   window.resizeBy(0, 1);
}

// Firefox reload SVG bug work around
function reload(e)
{
   if (!e)
      var e = window.event;

   hideBackgrounds();
   setTimeout("document.reload();", 100);

   stopPropagation(e);
   e.cancel = true;
   e.returnValue = false;

   return false;
}

// Safari and Konqueror don't yet support getComputedStyle()
// and they always reload page when location.href is updated
function isKHTML()
{
   var agent = navigator.userAgent;
   return (agent.indexOf("KHTML") >= 0 ? true : false);
}

function resized()
{
   var width = 0;

   if ( typeof( window.innerWidth ) == 'number' )
      width = window.innerWidth;  // Non IE browser
   else if (document.documentElement && document.documentElement.clientWidth)
      width = document.documentElement.clientWidth;  // IE6
   else if (document.body && document.body.clientWidth)
      width = document.body.clientWidth; // IE4

   var height = 0;

   if ( typeof( window.innerHeight ) == 'number' )
      height = window.innerHeight;  // Non IE browser
   else if (document.documentElement && document.documentElement.clientHeight)
      height = document.documentElement.clientHeight;  // IE6
   else if (document.body && document.body.clientHeight)
      height = document.body.clientHeight; // IE4

   // IE fires onresize even when only font size is changed!
   // so we do a check to avoid blocking < and > actions
   if (width != lastWidth || height != lastHeight)
   {
      if (width >= 1100)
         sizeIndex = 5;    // 4
      else if (width >= 1000)
         sizeIndex = 4;    // 3
      else if (width >= 800)
         sizeIndex = 3;    // 2
      else if (width >= 600)
         sizeIndex = 2;    // 1
      else if (width)
         sizeIndex = 0;

      // add in font size adjustment from meta element e.g.
      // <meta name="font-size-adjustment" content="-2" />
      // useful when slides have too much content ;-)

      if (0 <= sizeIndex + sizeAdjustment &&
             sizeIndex + sizeAdjustment < sizes.length)
        sizeIndex = sizeIndex + sizeAdjustment;

      // enables cross browser use of relative width/height
      // on object elements for use with SVG and Flash media
      adjustObjectDimensions(width, height);

      document.body.style.fontSize = sizes[sizeIndex];

      lastWidth = width;
      lastHeight = height;

      // force reflow to work around Mozilla bug
      //if (ns_pos)
      {
         var slide = slides[slidenum];
         hideSlide(slide);
         showSlide(slide);
      }

      // force correct positioning of toolbar
      refreshToolbar(200);
   }
}

function scrolled()
{
   if (toolbar && !ns_pos)
   {
      // hide toolbar
      toolbar.style.display = "none";

      // make it reappear later
      if (scrollhack == 0 && !viewAll)
      {
         setTimeout(showToolbar, 1000);
         scrollhack = 1;
      }
   }
}

// used to ensure IE refreshes toolbar in correct position
function refreshToolbar(interval)
{
   hideToolbar();
   setTimeout(showToolbar, interval);
}

// restores toolbar after short delay
function showToolbar()
{
   if (wantToolbar)
   {
      if (!ns_pos)
      {
         // adjust position to allow for scrolling
         var xoffset = scrollXOffset();
         toolbar.style.left = xoffset;
         toolbar.style.right = xoffset;

         // determine vertical scroll offset
         //var yoffset = scrollYOffset();

         // bottom is doc height - window height - scroll offset
         //var bottom = documentHeight() - lastHeight - yoffset

         //if (yoffset > 0 || documentHeight() > lastHeight)
         //   bottom += 16;  // allow for height of scrollbar

         toolbar.style.bottom = 0; //bottom;
      }

      toolbar.style.display = "block";
      toolbar.style.visibility = "visible";
   }

   scrollhack = 0;


   // set the keyboard focus to the help link on the
   // toolbar to ensure that document has the focus
   // IE doesn't always work with window.focus()
   // and this hack has benefit of Enter for help

   try
   {
     helpAnchor.focus();
   }
   catch (e)
   {
   }
}

function test()
{
   var s = "docH: " + documentHeight() +
       " winH: " + lastHeight +
       " yoffset: " + scrollYOffset() +
       " toolbot: " + (documentHeight() - lastHeight - scrollYOffset());

   //alert(s);

   var slide = slides[slidenum];
   // IE getAttribute requires "class" to be "className"
   var name = ns_pos ? "class" : "className";
   var style = (slide.currentStyle ? slide.currentStyle["backgroundColor"] :
       document.defaultView.getComputedStyle(slide, '').getPropertyValue("background-color"));
   alert("class='" + slide.getAttribute(name) + "' backgroundColor: " + style);
}

function hideToolbar()
{
   toolbar.style.display = "none";
   toolbar.style.visibility = "hidden";
}

// invoked via F key
function toggleToolbar()
{
   if (!viewAll)
   {
      if (toolbar.style.display == "none")
      {
         toolbar.style.display = "block";
         toolbar.style.visibility = "visible";
         wantToolbar = 1;
      }
      else
      {
         toolbar.style.display = "none";
         toolbar.style.visibility = "hidden";
         wantToolbar = 0;
      }
   }
}

function scrollXOffset()
{
   if (window.pageXOffset)
      return self.pageXOffset;

   if (document.documentElement && 
             document.documentElement.scrollLeft)
      return document.documentElement.scrollLeft;

   if (document.body)
      return document.body.scrollLeft;

    return 0;
}


function scrollYOffset()
{
   if (window.pageYOffset)
      return self.pageYOffset;

   if (document.documentElement && 
             document.documentElement.scrollTop)
      return document.documentElement.scrollTop;

   if (document.body)
      return document.body.scrollTop;

    return 0;
}

// looking for a way to determine height of slide content
// the slide itself is set to the height of the window
function optimizeFontSize()
{
   var slide = slides[slidenum];

   //var dh = documentHeight(); //getDocHeight(document);
   var dh = slide.scrollHeight;
   var wh = getWindowHeight();
   var u = 100 * dh / wh;

   alert("window utilization = " + u + "% (doc "
      + dh + " win " + wh + ")");
}

function getDocHeight(doc) // from document object
{
  if (!doc)
    doc = document;

  if (doc && doc.body && doc.body.offsetHeight)
    return doc.body.offsetHeight;  // ns/gecko syntax

  if (doc && doc.body && doc.body.scrollHeight)
    return doc.body.scrollHeight;

  alert("couldn't determine document height");
}

function getWindowHeight()
{
  if ( typeof( window.innerHeight ) == 'number' )
    return window.innerHeight;  // Non IE browser

  if (document.documentElement && document.documentElement.clientHeight)
    return document.documentElement.clientHeight;  // IE6

  if (document.body && document.body.clientHeight)
    return document.body.clientHeight; // IE4
}



function documentHeight()
{
   var sh, oh;

   sh = document.body.scrollHeight;
   oh = document.body.offsetHeight;

   if (sh && oh)
   {
      return (sh > oh ? sh : oh);
   }

   // no idea!
   return 0;
}

function smaller()
{
   if (sizeIndex > 0)
   {
      --sizeIndex;
   }

   toolbar.style.display = "none";
   document.body.style.fontSize = sizes[sizeIndex];
   var slide = slides[slidenum];
   hideSlide(slide);
   showSlide(slide);
   setTimeout(showToolbar, 300);
}

function bigger()
{
   if (sizeIndex < sizes.length - 1)
   {
      ++sizeIndex;
   }

   toolbar.style.display = "none";
   document.body.style.fontSize = sizes[sizeIndex];
   var slide = slides[slidenum];
   hideSlide(slide);
   showSlide(slide);
   setTimeout(showToolbar, 300);
}

// enables cross browser use of relative width/height
// on object elements for use with SVG and Flash media
// with thanks to Ivan Herman for the suggestion
function adjustObjectDimensions(width, height)
{
   for( var i = 0; i < objects.length; i++ )
   {
      var obj = objects[i];
      var mimeType = obj.getAttribute("type");

      if (mimeType == "image/svg+xml" || mimeType == "application/x-shockwave-flash")
      {
         if ( !obj.initialWidth ) 
            obj.initialWidth = obj.getAttribute("width");

         if ( !obj.initialHeight ) 
            obj.initialHeight = obj.getAttribute("height");

         if ( obj.initialWidth && obj.initialWidth.charAt(obj.initialWidth.length-1) == "%" )
         {
            var w = parseInt(obj.initialWidth.slice(0, obj.initialWidth.length-1));
            var newW = width * (w/100.0);
            obj.setAttribute("width",newW);
         }

         if ( obj.initialHeight && obj.initialHeight.charAt(obj.initialHeight.length-1) == "%" )
         {
            var h = parseInt(obj.initialHeight.slice(0, obj.initialHeight.length-1));
            var newH = height * (h/100.0);
            obj.setAttribute("height", newH);
         }
      }
   }
}

function cancel(event)
{
  if (event)
  {
     event.cancel = true;
     event.returnValue = false;

    if (event.preventDefault)
      event.preventDefault();
  }

  return false;
}

//  See e.g. http://www.quirksmode.org/js/events/keys.html for keycodes
function keyDown(event)
{
    var key;

    if (!event)
      var event = window.event;

    // kludge around NS/IE differences 
    if (window.event)
       key = window.event.keyCode;
    else if (event.which)
       key = event.which;
    else
       return true; // Yikes! unknown browser

    // ignore event if key value is zero
    // as for alt on Opera and Konqueror
    if (!key)
       return true;

    // check for concurrent control/command/alt key
    // but are these only present on mouse events?

    if (event.ctrlKey || event.altKey)
       return true;

    // dismiss table of contents if visible
    hideTableOfContents();

    if (key == 34) // Page Down
    {
       nextSlide(false);
       return cancel(event);
    }
    else if (key == 33) // Page Up
    {
       previousSlide(false);
       return cancel(event);
    }
    else if (key == 32) // space bar
    {
       nextSlide(true);
       return cancel(event);
    }
    else if (key == 37) // Left arrow
    {
       previousSlide(true);
       return cancel(event);
    }
    else if (key == 36) // Home
    {
       firstSlide();
       return cancel(event);
    }
    else if (key == 35) // End
    {
       lastSlide();
       return cancel(event);
    }
    else if (key == 39) // Right arrow
    {
       nextSlide(true);
       return cancel(event);
    }
    else if (key == 188)  // < for smaller fonts
    {
       smaller();
       return cancel(event);
    }
    else if (key == 190)  // > for larger fonts
    {
       bigger();
       return cancel(event);
    }
    else if (key == 189 || key == 109)  // - for smaller fonts
    {
       smaller();
       return cancel(event);
    }
    else if (key == 187 || key == 191 || key == 107)  // = +  for larger fonts
    {
       bigger();
       return cancel(event);
    }
    else if (key == 83)  // S for smaller fonts
    {
       smaller();
       return cancel(event);
    }
    else if (key == 66)  // B for larger fonts
    {
       bigger();
       return cancel(event);
    }
    else if (key == 90)  // Z for last slide
    {
       lastSlide();
       return cancel(event);
    }
    else if (key == 70)  // F for toggle toolbar
    {
       toggleToolbar();
       return cancel(event);
    }
    else if (key == 65)  // A for toggle view single/all slides
    {
       toggleView();
       return cancel(event);
    }
    else if (key == 75)  // toggle action of left click for next page
    {
       mouseClickEnabled = !mouseClickEnabled;
       alert((mouseClickEnabled ? "enabled" : "disabled") +  " mouse click advance");
       return cancel(event);
    }
    else if (key == 84 || key == 67)  // T or C for table of contents
    {
       if (toc)
         showTableOfContents();

       return cancel(event);
    }
    //else alert("key code is "+ key);

    return true;
}

// right mouse button click is reserved for context menus
// it is more reliable to detect rightclick than leftclick
function mouseButtonClick(e)
{
   var rightclick = false;
   var leftclick = false;
   var middleclick = false;
   var target;

   if (!e)
      var e = window.event;

   if (e.target)
      target = e.target;
   else if (e.srcElement)
      target = e.srcElement;

   // work around Safari bug
   if (target.nodeType == 3)
      target = target.parentNode;

   if (e.which) // all browsers except IE
   {
      leftclick = (e.which == 1);
      middleclick = (e.which == 2);
      rightclick = (e.which == 3);
   }
   else if (e.button)
   {
      // Konqueror gives 1 for left, 4 for middle
      // IE6 gives 0 for left and not 1 as I expected

      if (e.button == 4)
        middleclick = true;

      // all browsers agree on 2 for right button
      rightclick = (e.button == 2);
   }
   else leftclick = true;

   // dismiss table of contents
   hideTableOfContents();

   // check if target is something that probably want's clicks
   // e.g. embed, object, input, textarea, select, option

   if (mouseClickEnabled && leftclick &&
        target.nodeName != "EMBED" &&
        target.nodeName != "OBJECT" &&
        target.nodeName != "INPUT" &&
        target.nodeName != "TEXTAREA" &&
        target.nodeName != "SELECT" &&
        target.nodeName != "OPTION")
   {
      nextSlide(true);
      stopPropagation(e);
      e.cancel = true;
      e.returnValue = false;
   }
}

function previousSlide(incremental)
{
   if (!viewAll)
   {
      var slide;

      if ((incremental || slidenum == 0) && lastShown != null)
      {
         lastShown = hidePreviousItem(lastShown);
         setEosStatus(false);
      }
      else if (slidenum > 0)
      {
         slide = slides[slidenum];
         hideSlide(slide);

         slidenum = slidenum - 1;
         slide = slides[slidenum];
         setVisibilityAllIncremental("visible");
         lastShown = previousIncrementalItem(null);
         setEosStatus(true);
         showSlide(slide);
      }

      setLocation();

      if (!ns_pos)
         refreshToolbar(200);
   }
}

function nextSlide(incremental)
{
   if (!viewAll)
   {
      var slide;

      if (incremental || slidenum == slides.length - 1)
         lastShown = revealNextItem(lastShown);

      if ((!incremental || lastShown == null) && slidenum < slides.length - 1)
      {
         slide = slides[slidenum];
         hideSlide(slide);

         slidenum = slidenum + 1;
         slide = slides[slidenum];
         lastShown = null;
         setVisibilityAllIncremental("hidden");
         showSlide(slide);
      }

      setLocation();

      setEosStatus(!nextIncrementalItem(lastShown));

      if (!ns_pos)
         refreshToolbar(200);
   }
}

// to first slide with nothing revealed
// i.e. state at start of presentation
function firstSlide()
{
   if (!viewAll)
   {
      var slide;

      if (slidenum != 0)
      {
         slide = slides[slidenum];
         hideSlide(slide);

         slidenum = 0;
         slide = slides[slidenum];
         lastShown = null;
         setVisibilityAllIncremental("hidden");
         showSlide(slide);
      }

      setEosStatus(!nextIncrementalItem(lastShown));
      setLocation();
   }
}


// to last slide with everything revealed
// i.e. state at end of presentation
function lastSlide()
{
   if (!viewAll)
   {
      var slide;

      lastShown = null; //revealNextItem(lastShown);

      if (lastShown == null && slidenum < slides.length - 1)
      {
         slide = slides[slidenum];
         hideSlide(slide);
         slidenum = slides.length - 1;
         slide = slides[slidenum];
         setVisibilityAllIncremental("visible");
         lastShown = previousIncrementalItem(null);

         showSlide(slide);
      }
      else
      {
         setVisibilityAllIncremental("visible");
         lastShown = previousIncrementalItem(null);
      }

      setEosStatus(true);
      setLocation();
   }
}

function setEosStatus(state)
{
   if (eos)
      eos.style.color = (state ? "rgb(240,240,240)" : "red");
}

function showSlide(slide)
{
   syncBackground(slide);
   window.scrollTo(0,0);
   slide.style.visibility = "visible";
   slide.style.display = "block";
}

function hideSlide(slide)
{
   slide.style.visibility = "hidden";
   slide.style.display = "none";
}

function beforePrint()
{
   showAllSlides();
   hideToolbar();
}

function afterPrint()
{
   if (!viewAll)
   {
      singleSlideView();
      showToolbar();
   }
}

function toggleView()
{
   if (viewAll)
   {
      singleSlideView();
      showToolbar();
      viewAll = 0;
   }
   else
   {
      showAllSlides();
      hideToolbar();
      viewAll = 1;
   }
}

// prepare for printing
function showAllSlides()
{
   var slide;

   for (var i = 0; i < slides.length; ++i)
   {
      slide = slides[i];

      slide.style.position = "relative";
      slide.style.borderTopStyle = "solid";
      slide.style.borderTopWidth = "thin";
      slide.style.borderTopColor = "black";

      try {
        if (i == 0)
          slide.style.pageBreakBefore = "avoid";
        else
          slide.style.pageBreakBefore = "always";
      }
      catch (e)
      {
        //do nothing
      }

      setVisibilityAllIncremental("visible");
      showSlide(slide);
   }

   var note;

   for (var i = 0; i < notes.length; ++i)
   {
      showSlide(notes[i]);
   }

   // no easy way to render background under each slide
   // without duplicating the background divs for each slide
   // therefore hide backgrounds to avoid messing up slides
   hideBackgrounds();
}

// restore after printing
function singleSlideView()
{
   var slide;

   for (var i = 0; i < slides.length; ++i)
   {
      slide = slides[i];

      slide.style.position = "absolute";

      if (i == slidenum)
      {
         slide.style.borderStyle = "none";
         showSlide(slide);
      }
      else
      {
         slide.style.borderStyle = "none";
         hideSlide(slide);
      }
   }

   setVisibilityAllIncremental("visible");
   lastShown = previousIncrementalItem(null);

   var note;

   for (var i = 0; i < notes.length; ++i)
   {
      hideSlide(notes[i]);
   }
}

// the string str is a whitespace separated list of tokens
// test if str contains a particular token, e.g. "slide"
function hasToken(str, token)
{
   if (str)
   {
      // define pattern as regular expression
      var pattern = /\w+/g;

      // check for matches
      // place result in array
      var result = str.match(pattern);

      // now check if desired token is present
      for (var i = 0; i < result.length; i++)
      {
         if (result[i] == token)
            return true;
      }
   }

   return false;
}

// wysiwyg editors make it hard to use div elements
// e.g. amaya loses the div when you copy and paste
// this function wraps div elements around implicit
// slides which start with an h1 element and continue
// up to the next heading or div element
function wrapImplicitSlides()
{
   var i, heading, node, next, div;
   var headings = document.getElementsByTagName("h1");

   if (!headings)
     return;

   for (i = 0; i < headings.length; ++i)
   {
      heading = headings[i];

      if (heading.parentNode != document.body)
         continue;

      node = heading.nextSibling;

      div = document.createElement("div");
      div.setAttribute((ns_pos ? "class" : "className"), "slide");
      document.body.replaceChild(div, heading);
      div.appendChild(heading);

      while (node)
      {
         if (node.nodeType == 1 &&    // an element
                  (node.nodeName == "H1" ||
                   node.nodeName == "h1" ||
                   node.nodeName == "DIV" ||
                   node.nodeName == "div"))
            break;

         next = node.nextSibling;
         node = document.body.removeChild(node);
         div.appendChild(node);
         node = next;
      } 
   }
}

// return new array of all slides
function collectSlides()
{
   var slides = new Array();
   var divs = document.body.getElementsByTagName("div");

   // IE getAttribute requires "class" to be "className"
   var name = ns_pos ? "class" : "className";

   for (var i = 0; i < divs.length; ++i)
   {
      div = divs.item(i);

      if (hasToken(div.getAttribute(name), "slide"))
      {
         // add slide to collection
         slides[slides.length] = div;

         // hide each slide as it is found
         div.style.display = "none";
         div.style.visibility = "hidden";

         // add dummy <br/> at end for scrolling hack
         var node1 = document.createElement("br");
         div.appendChild(node1);
         var node2 = document.createElement("br");
         div.appendChild(node2);
      }
      else if (hasToken(div.getAttribute(name), "background"))
      {  // work around for Firefox SVG reload bug
         // which otherwise replaces 1st SVG graphic with 2nd
         div.style.display = "block";
      }
   }

   return slides;
}

// return new array of all <div class="handout">
function collectNotes()
{
   var notes = new Array();
   var divs = document.body.getElementsByTagName("div");

   // IE getAttribute requires "class" to be "className"
   var name = ns_pos ? "class" : "className";

   for (var i = 0; i < divs.length; ++i)
   {
      div = divs.item(i);

      if (hasToken(div.getAttribute(name), "handout"))
      {
         // add slide to collection
         notes[notes.length] = div;

         // hide handout notes as they are found
         div.style.display = "none";
         div.style.visibility = "hidden";
      }
   }

   return notes;
}

// return new array of all <div class="background">
// including named backgrounds e.g. class="background titlepage"
function collectBackgrounds()
{
   var backgrounds = new Array();
   var divs = document.body.getElementsByTagName("div");

   // IE getAttribute requires "class" to be "className"
   var name = ns_pos ? "class" : "className";
   var background;

   for (var i = 0; i < divs.length; ++i)
   {
      div = divs.item(i);

      background = div.getAttribute(name);

      if (hasToken(background, "background"))
      {
         // add slide to collection
         backgrounds[backgrounds.length] = div;

         // hide named backgrounds as they are found
         // e.g. class="background epilog"
         if (background != "background")
         {
            div.style.display = "none";
            div.style.visibility = "hidden";
         }
      }
   }

   return backgrounds;
}

// show just the backgrounds pertinent to this slide
function syncBackground(slide)
{
   var background;
   var bgColor;

   if (slide.currentStyle)
      bgColor = slide.currentStyle["backgroundColor"];
   else if (document.defaultView)
   {
      var styles = document.defaultView.getComputedStyle(slide,null);

      if (styles)
          bgColor = styles.getPropertyValue("background-color");
      else // broken implementation probably due Safari or Konqueror
      {
          //alert("defective implementation of getComputedStyle()");
          bgColor = "transparent";
      }
   }
   else
      bgColor == "transparent";

   if (bgColor == "transparent")
   {
      // IE getAttribute requires "class" to be "className"
      var name = ns_pos ? "class" : "className";
      var slideClass = slide.getAttribute(name);
      var bgClass;

      for (var i = 0; i < backgrounds.length; i++)
      {
         background = backgrounds[i];

         bgClass = background.getAttribute(name);

         if (matchingBackground(slideClass, bgClass))
         {
            background.style.display = "block";
            background.style.visibility = "visible";
         }
         else
         {
            background.style.display = "none";
            background.style.visibility = "hidden";
         }
      }
   }
   else // forcibly hide all backgrounds
      hideBackgrounds();
}

function hideBackgrounds()
{
   for (var i = 0; i < backgrounds.length; i++)
   {
      background = backgrounds[i];
      background.style.display = "none";
      background.style.visibility = "hidden";
   }
}

// compare classes for slide and background
function matchingBackground(slideClass, bgClass)
{
   if (bgClass == "background")
      return true;

   // define pattern as regular expression
   var pattern = /\w+/g;

   // check for matches and place result in array
   var result = slideClass.match(pattern);

   // now check if desired name is present for background
   for (var i = 0; i < result.length; i++)
   {
      if (hasToken(bgClass, result[i]))
         return true;
   }

   return false;
}

// left to right traversal of root's content
function nextNode(root, node)
{
   if (node == null)
      return root.firstChild;

   if (node.firstChild)
      return node.firstChild;

   if (node.nextSibling)
      return node.nextSibling;

   for (;;)
   {
      node = node.parentNode;

      if (!node || node == root)
         break;

      if (node && node.nextSibling)
         return node.nextSibling;
   }

   return null;
}

// right to left traversal of root's content
function previousNode(root, node)
{
   if (node == null)
   {
      node = root.lastChild;

      if (node)
      {
         while (node.lastChild)
            node = node.lastChild;
      }

      return node;
   }

   if (node.previousSibling)
   {
      node = node.previousSibling;

      while (node.lastChild)
         node = node.lastChild;

      return node;
   }

   if (node.parentNode != root)
      return node.parentNode;

   return null;
}

// HTML elements that can be used with class="incremental"
// note that you can also put the class on containers like
// up, ol, dl, and div to make their contents appear
// incrementally. Upper case is used since this is what
// browsers report for HTML node names (text/html).
function incrementalElementList()
{
   var inclist = new Array();
   inclist["P"] = true;
   inclist["PRE"] = true;
   inclist["LI"] = true;
   inclist["BLOCKQUOTE"] = true;
   inclist["DT"] = true;
   inclist["DD"] = true;
   inclist["H2"] = true;
   inclist["H3"] = true;
   inclist["H4"] = true;
   inclist["H5"] = true;
   inclist["H6"] = true;
   inclist["SPAN"] = true;
   inclist["ADDRESS"] = true;
   inclist["TABLE"] = true;
   inclist["TR"] = true;
   inclist["TH"] = true;
   inclist["TD"] = true;
   inclist["IMG"] = true;
   inclist["OBJECT"] = true;
   return inclist;
}

function nextIncrementalItem(node)
{
   var slide = slides[slidenum];

   // IE getAttribute requires "class" to be "className"
   var classattr = ns_pos ? "class" : "className";


   for (;;)
   {
      node = nextNode(slide, node);

      if (node == null || node.parentNode == null)
         break;

      if (node.nodeType == 1)  // ELEMENT
      {
         if (node.nodeName == "BR")
           continue;

         if (hasToken(node.getAttribute(classattr), "incremental")
             && okayForIncremental[node.nodeName])
            return node;

         if (hasToken(node.parentNode.getAttribute(classattr), "incremental")
             && !hasToken(node.getAttribute(classattr), "non-incremental"))
            return node;
      }
   }

   return node;
}

function previousIncrementalItem(node)
{
   var slide = slides[slidenum];

   // IE getAttribute requires "class" to be "className"
   var classattr = ns_pos ? "class" : "className";


   for (;;)
   {
      node = previousNode(slide, node);

      if (node == null || node.parentNode == null)
         break;

      if (node.nodeType == 1)
      {
         if (node.nodeName == "BR")
           continue;

         if (hasToken(node.getAttribute(classattr), "incremental")
             && okayForIncremental[node.nodeName])
            return node;

         if (hasToken(node.parentNode.getAttribute(classattr), "incremental")
             && !hasToken(node.getAttribute(classattr), "non-incremental"))
            return node;
      }
   }

   return node;
}

// set visibility for all elements on current slide with
// a parent element with attribute class="incremental"
function setVisibilityAllIncremental(value)
{
   var node = nextIncrementalItem(null);

   while (node)
   {
      node.style.visibility = value;
      node = nextIncrementalItem(node);
   }
}

// reveal the next hidden item on the slide
// node is null or the node that was last revealed
function revealNextItem(node)
{
   node = nextIncrementalItem(node);

   if (node && node.nodeType == 1)  // an element
      node.style.visibility = "visible";

   return node;
}


// exact inverse of revealNextItem(node)
function hidePreviousItem(node)
{
   if (node && node.nodeType == 1)  // an element
      node.style.visibility = "hidden";

   return previousIncrementalItem(node);
}


/* set click handlers on all anchors */
function patchAnchors()
{
   var anchors = document.body.getElementsByTagName("a");

   for (var i = 0; i < anchors.length; ++i)
   {
      anchors[i].onclick = clickedAnchor;
   }
}

function clickedAnchor(e)
{
   if (!e)
      var e = window.event;

   // compare this.href with location.href
   // for link to another slide in this doc

   if (pageAddress(this.href) == pageAddress(location.href))
   {
      // yes, so find new slide number
      var newslidenum = findSlideNumber(this.href);

      if (newslidenum != slidenum)
      {
         slide = slides[slidenum];
         hideSlide(slide);
         slidenum = newslidenum;
         slide = slides[slidenum];
         showSlide(slide);
         setLocation();
      }
   }
   else if (this.target == null)
      location.href = this.href;

   this.blur();
   stopPropagation(e);
}

function pageAddress(uri)
{
   var i = uri.indexOf("#");

   // check if anchor is entire page

   if (i < 0)
      return uri;  // yes

   return uri.substr(0, i);
}

function showSlideNumber()
{
   slideNumElement.innerHTML = "slide " +
           (slidenum + 1) + "/" + slides.length;
}

function setLocation()
{
   var uri = pageAddress(location.href);

   if (slidenum > 0)
      uri = uri + "#(" + (slidenum+1) + ")";

   if (uri != location.href && !khtml)
      location.href = uri;

   document.title = title + " (" + (slidenum+1) + ")";
   //document.title = (slidenum+1) + ") " + slideName(slidenum);

   showSlideNumber();
}

// find current slide based upon location
// first find target anchor and then look
// for associated div element enclosing it
// finally map that to slide number
function findSlideNumber(uri)
{
   // first get anchor from page location

   var i = uri.indexOf("#");

   // check if anchor is entire page

   if (i < 0)
      return 0;  // yes

   var anchor = uri.substr(i+1);

   // now use anchor as XML ID to find target
   var target = document.getElementById(anchor);

   if (!target)
   {
      // does anchor look like "(2)" for slide 2 ??
      // where first slide is (1)
      var re = /\((\d)+\)/;

      if (anchor.match(re))
      {
         var num = parseInt(anchor.substring(1, anchor.length-1));

         if (num > slides.length)
            num = 1;

         if (--num < 0)
            num = 0;

         return num;
      }

      // accept [2] for backwards compatibility
      re = /\[(\d)+\]/;

      if (anchor.match(re))
      {
         var num = parseInt(anchor.substring(1, anchor.length-1));

         if (num > slides.length)
            num = 1;

         if (--num < 0)
            num = 0;

         return num;
      }

      // oh dear unknown anchor
      return 0;
   }

   // search for enclosing slide

   // IE getAttribute requires "class" to be "className"
   var name = ns_pos ? "class" : "className";

   while (true)
   {
      // browser coerces html elements to uppercase!
      if (target.nodeName.toLowerCase() == "div" &&
          target.getAttribute(name) == "slide")
      {
         // found the slide element
         break;
      }

      // otherwise try parent element if any

      target = target.parentNode;

      if (!target)
      {
         return 0;   // no luck!
      }
   };

   for (i = 0; i < slides.length; ++i)
   {
      if (slides[i] == target)
         return i;  // success
   }

   // oh dear still no luck
   return 0;
}

// find slide name from first h1 element
// default to document title + slide number
function slideName(index)
{
   var name = null;
   var slide = slides[index];

   var heading = findHeading(slide);

   if (heading)
     name = extractText(heading);

   if (!name)
     name = title + "(" + (index + 1) + ")";

   name.replace(/\&/g, "&amp;");
   name.replace(/\</g, "&lt;");
   name.replace(/\>/g, "&gt;");

   return name;
}

// find first h1 element in DOM tree
function findHeading(node)
{
  if (!node || node.nodeType != 1)
    return null;

  if (node.nodeName == "H1" || node.nodeName == "h1")
    return node;

  var child = node.firstChild;

  while (child)
  {
    node = findHeading(child);

    if (node)
      return node;

    child = child.nextSibling;
  }

  return null;
}

// recursively extract text from DOM tree
function extractText(node)
{
  if (!node)
    return "";

  // text nodes
  if (node.nodeType == 3)
    return node.nodeValue;

  // elements
  if (node.nodeType == 1)
  {
    node = node.firstChild;
    var text = "";

    while (node)
    {
      text = text + extractText(node);
      node = node.nextSibling;
    }

    return text;
  }

  return "";
}


// find copyright text from meta element
function findCopyright()
{
   var name, content;
   var meta = document.getElementsByTagName("meta");

   for (var i = 0; i < meta.length; ++i)
   {
      name = meta[i].getAttribute("name");
      content = meta[i].getAttribute("content");

      if (name == "copyright")
         return content;
   }

   return null;
}

function findSizeAdjust()
{
   var name, content, offset;
   var meta = document.getElementsByTagName("meta");

   for (var i = 0; i < meta.length; ++i)
   {
      name = meta[i].getAttribute("name");
      content = meta[i].getAttribute("content");

      if (name == "font-size-adjustment")
         return 1 * content;
   }

   return 0;
}

function addToolbar()
{
   var slideCounter, page;

   var toolbar = createElement("div");
   toolbar.setAttribute("class", "toolbar");

   if (ns_pos) // a reasonably behaved browser
   {
      var right = document.createElement("div");
      right.setAttribute("style", "float: right; text-align: right");

      slideCounter = document.createElement("div")
      slideCounter.innerHTML = "slide n/m";
      right.appendChild(slideCounter);
      toolbar.appendChild(right);

      var left = document.createElement("div");
      left.setAttribute("style", "text-align: left");

      // global end of slide indicator
      eos = document.createElement("span");
      eos.innerHTML = "* ";
      left.appendChild(eos);

      var help = document.createElement("a");
      help.setAttribute("href", helpPage);
      help.setAttribute("title", helpText);
      help.innerHTML = "help?";
      left.appendChild(help);
      helpAnchor = help;  // save for focus hack

      var gap1 = document.createTextNode(" ");
      left.appendChild(gap1);

      var contents = document.createElement("a");
      contents.setAttribute("href", "javascript:toggleTableOfContents()");
      contents.setAttribute("title", "table of contents");
      contents.innerHTML = "contents?";
      left.appendChild(contents);

      var gap2 = document.createTextNode(" ");
      left.appendChild(gap2);

      var i = location.href.indexOf("#");

      // check if anchor is entire page

      if (i > 0)
         page = location.href.substr(0, i);
      else
         page = location.href;

      var start = document.createElement("a");
      start.setAttribute("href", page);
      start.setAttribute("title", "restart presentation");
      start.innerHTML = "restart?";
      left.appendChild(start);

      var copyright = findCopyright();

      if (copyright)
      {
         var span = document.createElement("span");
         span.innerHTML = copyright;
         span.style.color = "black";
         span.style.marginLeft = "4em";
         left.appendChild(span);
      }

      toolbar.appendChild(left);
   }
   else // IE so need to work around its poor CSS support
   {
      toolbar.style.position = "absolute";
      toolbar.style.zIndex = "200";
      toolbar.style.width = "100%";
      toolbar.style.height = "1.2em";
      toolbar.style.top = "auto";
      toolbar.style.bottom = "0";
      toolbar.style.left = "0";
      toolbar.style.right = "0";
      toolbar.style.textAlign = "left";
      toolbar.style.fontSize = "60%";
      toolbar.style.color = "red";
      toolbar.borderWidth = 0;
      toolbar.style.background = "rgb(240,240,240)";

      // would like to have help text left aligned
      // and page counter right aligned, floating
      // div's don't work, so instead use nested
      // absolutely positioned div's.

      var sp = document.createElement("span");
      sp.innerHTML = "&nbsp;&nbsp;*&nbsp;";
      toolbar.appendChild(sp);
      eos = sp;  // end of slide indicator

      var help = document.createElement("a");
      help.setAttribute("href", helpPage);
      help.setAttribute("title", helpText);
      help.innerHTML = "help?";
      toolbar.appendChild(help);
      helpAnchor = help;  // save for focus hack

      var gap1 = document.createTextNode(" ");
      toolbar.appendChild(gap1);

      var contents = document.createElement("a");
      contents.setAttribute("href", "javascript:toggleTableOfContents()");
      contents.setAttribute("title", "table of contents");
      contents.innerHTML = "contents?";
      toolbar.appendChild(contents);

      var gap2 = document.createTextNode(" ");
      toolbar.appendChild(gap2);

      var i = location.href.indexOf("#");

      // check if anchor is entire page

      if (i > 0)
         page = location.href.substr(0, i);
      else
         page = location.href;

      var start = document.createElement("a");
      start.setAttribute("href", page);
      start.setAttribute("title", "restart presentation");
      start.innerHTML = "restart?";
      toolbar.appendChild(start);

      var copyright = findCopyright();

      if (copyright)
      {
         var span = document.createElement("span");
         span.innerHTML = copyright;
         span.style.color = "black";
         span.style.marginLeft = "2em";
         toolbar.appendChild(span);
      }

      slideCounter = document.createElement("div")
      slideCounter.style.position = "absolute";
      slideCounter.style.width = "auto"; //"20%";
      slideCounter.style.height = "1.2em";
      slideCounter.style.top = "auto";
      slideCounter.style.bottom = 0;
      slideCounter.style.right = "0";
      slideCounter.style.textAlign = "right";
      slideCounter.style.color = "red";
      slideCounter.style.background = "rgb(240,240,240)";

      slideCounter.innerHTML = "slide n/m";
      toolbar.appendChild(slideCounter);
   }

   // ensure that click isn't passed through to the page
   toolbar.onclick = stopPropagation;
   document.body.appendChild(toolbar);
   slideNumElement = slideCounter;
   setEosStatus(false);

   return toolbar;
}

function showTableOfContents()
{
  if (toc)
  {
    toc.style.visible = "visible";
    toc.style.display = "block";
  }
}

function hideTableOfContents()
{
  if (toc)
  {
    toc.style.visible = "hidden";
    toc.style.display = "none";

    try
    {
       helpAnchor.focus();
    }
    catch (e)
    {
    }
  }
}

function toggleTableOfContents()
{
  if (toc)
  {
     if (toc.style.visible != "visible")
       showTableOfContents();
     else
       hideTableOfContents();
  }
}

function gotoEntry(e)
{
   var target;

   if (!e)
      var e = window.event;

   if (e.target)
      target = e.target;
   else if (e.srcElement)
      target = e.srcElement;

   // work around Safari bug
   if (target.nodeType == 3)
      target = target.parentNode;

   if (target && target.nodeType == 1)
   {
     var uri = target.getAttribute("href");

     if (uri)
     {
        //alert("going to " + uri);
        var slide = slides[slidenum];
        hideSlide(slide);
        slidenum = findSlideNumber(uri);
        slide = slides[slidenum];
        lastShown = null;
        setLocation();
        setVisibilityAllIncremental("hidden");
        setEosStatus(!nextIncrementalItem(lastShown));
        showSlide(slide);
        //target.focus();

        try
        {
           helpAnchor.focus();
        }
        catch (e)
        {
        }
     }
   }

   hideTableOfContents(e);
   stopPropagation(e);
   return cancel(e);
}

// create div element with links to each slide
function tableOfContents()
{
  var toc = document.createElement("div");

  var heading = document.createElement("div");
  heading.innerHTML = "Table of Contents";
  heading.style.textAlign = "center";
  heading.style.margin = "0";
  heading.style.marginBottom = "0.2em";
  heading.style.padding = "0.2em";

  // work around for Gecko bug in heading width
  // when enclosing div has width: auto

  if (ns_pos)
    heading.style.width = "100%";

  toc.appendChild(heading);

  for (var i = 0; i < slides.length; ++i)
  {
    var a = document.createElement("a");
    a.setAttribute("href", "#(" + (i+1) + ")");

    var name = document.createTextNode(slideName(i));
    a.appendChild(name);
    a.onclick = gotoEntry;
    toc.appendChild(a);

    if (i < slides.length - 1)
    {
      var br = document.createElement("br");
      toc.appendChild(br);
    }
  }

  toc.onclick = hideTableOfContents;
  toc.style.position = "absolute";
  toc.style.zIndex = "180";
  toc.style.width = "auto";
  toc.style.height = "30em";
  toc.style.overflow = "auto";
  toc.style.top = "auto";
  toc.style.right = "auto";
  toc.style.left = "4em";
  toc.style.bottom = "4em";
  toc.style.padding = "1em";
  toc.style.background = "rgb(240,240,240)";
  toc.style.borderStyle = "solid";
  toc.style.borderWidth = "2px";
  toc.style.fontSize = "60%";
  //document.body.appendChild(toc);
  document.body.insertBefore(toc, document.body.firstChild);
  return toc;
}

function replaceByNonBreakingSpace(str)
{
   for (var i = 0; i < str.length; ++i)
      str[i] = 160;
}


function initOutliner()
{
  var items = document.getElementsByTagName("LI");

   // IE getAttribute requires "class" to be "className"
   var clsname = ns_pos ? "class" : "className";

  for (var i = 0; i < items.length; ++i)
  {
     var target = items[i];

     if (!hasToken(target.parentNode.getAttribute(clsname), "outline"))
        continue;

     target.onclick = outlineClick;

     if (!ns_pos)
     {
        target.onmouseover = hoverOutline;
        target.onmouseout = unhoverOutline;
     }

     if (foldable(target))
     {
       target.foldable = true;

       if (hasToken(target.getAttribute(clsname), "expand"))
         unfold(target);
       else
         fold(target);
     }
     else
     {
       var clsval = target.getAttribute(clsname);
       target.setAttribute(clsname, clsval + " nofold");
       target.visible = true;
       target.foldable = false;
     }
  }
}

function foldable(item)
{
   if (!item || item.nodeType != 1)
      return false;

   var node = item.firstChild;

   while (node)
   {
     if (node.nodeType == 1 && isBlock(node))
       return true;

      node = node.nextSibling;
   }

   return false;
}

function fold(item)
{
   // IE getAttribute requires "class" to be "className"
   var clsname = ns_pos ? "class" : "className";

   if (hasToken(item.getAttribute(clsname), "expand"))
      item.setAttribute(clsname, "expand folded");
   else
      item.setAttribute(clsname, "folded");

  var node = item ? item.firstChild : null;

  while (node)
  {
    if (node.nodeType == 1 && isBlock(node)) // element
    {
      node.display = getElementStyle(node, "display", "display");
      node.style.display = "none";
      node.style.visibility = "hidden";
    }

    node = node.nextSibling;
  }

  item.visible = false;
}

function unfold(item)
{
   // IE getAttribute requires "class" to be "className"
   var clsname = ns_pos ? "class" : "className";

   if (hasToken(item.getAttribute(clsname), "expand"))
      item.setAttribute(clsname, "expand unfolded");
   else
      item.setAttribute(clsname, "unfolded");

  var node = item ? item.firstChild : null;

  while (node)
  {
    if (node.nodeType == 1 && isBlock(node)) // element
    {
      if (node.display)
         node.style.display = node.display;

      node.style.visibility = "visible";
    }

    node = node.nextSibling;
  }

  item.visible = true;
}

function outlineClick(e)
{
   var rightclick = false;
   var target;

   if (!e)
      var e = window.event;

   if (e.target)
      target = e.target;
   else if (e.srcElement)
      target = e.srcElement;

   // work around Safari bug
   if (target.nodeType == 3)
      target = target.parentNode;

   while (target && target.visible == undefined)
      target = target.parentNode;

   if (!target)
      return true;

   if (e.which)
      rightclick = (e.which == 3);
   else if (e.button)
      rightclick = (e.button == 2);

   if (!rightclick && target.visible != undefined)
   {
      if (target.foldable)
      {
         if (target.visible)
           fold(target);
         else
           unfold(target);
      }

      stopPropagation(e);
      e.cancel = true;
      e.returnValue = false;
   }

   return false;
}

function hoverOutline(e)
{
   var target;

   if (!e)
      var e = window.event;

   if (e.target)
      target = e.target;
   else if (e.srcElement)
      target = e.srcElement;

   // work around Safari bug
   if (target.nodeType == 3)
      target = target.parentNode;

   while (target && target.visible == undefined)
      target = target.parentNode;

   if (target && target.foldable)
      target.style.cursor = "pointer";

   return true;
}

function unhoverOutline(e)
{
   var target;

   if (!e)
      var e = window.event;

   if (e.target)
      target = e.target;
   else if (e.srcElement)
      target = e.srcElement;

   // work around Safari bug
   if (target.nodeType == 3)
      target = target.parentNode;

   while (target && target.visible == undefined)
      target = target.parentNode;

   if (target)
     target.style.cursor = "default";

   return true;
}


function stopPropagation(e)
{
   if (window.event)
   {
      window.event.cancelBubble = true;
      //window.event.returnValue = false;
   }
   else if (e)
   {
      e.cancelBubble = true;
      e.stopPropagation();
      //e.preventDefault();
   }
}

/* can't rely on display since we set that to none to hide things */
function isBlock(elem)
{
   var tag = elem.nodeName;

   return tag == "OL" || tag == "UL" || tag == "P" ||
          tag == "LI" || tag == "TABLE" || tag == "PRE" ||
          tag == "H1" || tag == "H2" || tag == "H3" ||
          tag == "H4" || tag == "H5" || tag == "H6" ||
          tag == "BLOCKQUOTE" || tag == "ADDRESS"; 
}

function getElementStyle(elem, IEStyleProp, CSSStyleProp)
{
   if (elem.currentStyle)
   {
      return elem.currentStyle[IEStyleProp];
   }
   else if (window.getComputedStyle)
   {
      var compStyle = window.getComputedStyle(elem, "");
      return compStyle.getPropertyValue(CSSStyleProp);
   }
   return "";
}

// works with text/html and text/xhtml+xml with thanks to Simon Willison
function createElement(element)
{
   if (typeof document.createElementNS != 'undefined')
   {
      return document.createElementNS('http://www.w3.org/1999/xhtml', element);
   }

   if (typeof document.createElement != 'undefined')
   {
      return document.createElement(element);
   }

   return false;
}

// designed to work with both text/html and text/xhtml+xml
function getElementsByTagName(name)
{
   if (typeof document.getElementsByTagNameNS != 'undefined')
   {
      return document.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', name);
   }

   if (typeof document.getElementsByTagName != 'undefined')
   {
      return document.getElementsByTagName(name);
   }

   return null;
}

// clean alternative to innerHTML method, but on IE6
// it doesn't work with named entities like &nbsp;
// which need to be replaced by numeric entities
function insertText(element, text)
{
   if (element.textContent)  // DOM3 only
      element.textContent = text;
   else
   {
      if (element.firstChild)
      {
         // remove current children
         while (element.firstChild)
            element.removeChild(element.firstChild);
      }

      element.appendChild(document.createTextNode(text));
   }
}
