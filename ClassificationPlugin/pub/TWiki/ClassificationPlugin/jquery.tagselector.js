/*
 * jQuery TagSelector plugin 1.0
 *
 * Copyright (c) 2008 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
(function($) {

  /***************************************************************************
   * plugin definition 
   */
  $.fn.tagSelector = function(options) {
    writeDebug("called tagSelector()");
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.tagSelector.defaults, options);
   
    // implementation ********************************************************
    return this.each(function() {
      $this = $(this);

      // build element specific options. 
      // note you may want to install the Metadata plugin
      var thisOpt = $.meta ? $.extend({}, opts, $this.data()) : opts;

      // get interface elements
      var $input = $(thisOpt.input, this);
      var $tagCloud = $(thisOpt.tagCloud, this);

      //writeDebug("input="+$input);
      //writeDebug("tagCloud="+$tagCloud);

      var initialTags;
      var doneHandleKeys = false;

      // key handler *********************************************************
      function handleKeys(ev) {
        writeDebug("called handleKey(), event type="+ev.type+" keyCode="+ev.keyCode);

        // key press
        if (ev.type == 'keypress') {
          if (ev.keyCode == 9) {
            handleTabKey();
            return false; // suppress default actions
          } else if (ev.keyCode == 13) {
            handleReturnKey();
            return false; // suppress default actions
          }
          return true;
        }

        doneHandleKeys = false;
        window.setTimeout(function() {
          _handleKeysJob(ev.keyCode)
        }, 100);

        if (ev.keyCode == 9 || ev.keyCode == 13) {
          //writeDebug("suppressing default action");
          return false; // suppress default actions
        } else {
          return true;
        }
      }

      // update selection, called by key handler
      function _handleKeysJob(keyCode) {
        if (doneHandleKeys) {
          return;
        }
        doneHandleKeys = true;
        //writeDebug("called _handleKeysJob()");
        // key up
        //writeDebug("keyCode="+keyCode);
        switch(keyCode) {
          case 37: // arrow keys
          case 38:
          case 39:
          case 40: 
            return;
          case 224:
          case 17:
          case 16:
          case 18: 
            return;
          case 46: // delete
          case 8: // backspace
          case 9: // tab
          case 13: // return
          case 27:
          case 32: // space
        }
        $("a", $tagCloud).removeClass('typed current');
        var selection = $input.val();
        //writeDebug("selection="+selection);
        var tmpValues = selection.split(/\s*,\s*/);
        var values = new Array();
        for (var i = 0; i < tmpValues.length; i++) {
          values.push(tmpValues[i].replace(/([^0-9A-Za-z_])/, '\\$1'));
        }
        var filter = "a#"+values.join(",a#");
        //writeDebug("filter="+filter);
        $(filter, $tagCloud).addClass("current");

        var last = tmpValues[tmpValues.length-1];
        if (last.match(/^ *$/)) {
          return;
        }
        $("a[id^="+last+"]", $tagCloud).each(function() {
          var id = $(this).attr('id');
          if (selection.indexOf(id) < 0) {
            $(this).addClass("typed");
          }
        });
      }

      // tab handler *********************************************************
      function handleTabKey() {
        //writeDebug("called handleTabKey()");
        var elem = $input.get(0);
        elem.focus();

        var currentTags = $input.val();
        //writeDebug("currentTags="+currentTags);
        var values = currentTags.split(/\s*,\s*/);
        var last = values.pop();
        var startPos = elem.selectionStart;
        var endPos = elem.selectionEnd;
        var origLast = last;

        if (last.match(/^ *$/)) {
          //writeDebug("no last");
          return;
        }
        
        if (startPos != endPos) {
          last = last.substring(0, last.length-endPos+startPos);
          //writeDebug("substracted selection, last="+last);
        }

        // find all matching tags
        var matchedTags = new Array();
        currentTags = values.join(", ");
        $("a[id^="+last+"]", $tagCloud).each(function() {
          var id = $(this).attr('id');
          if (currentTags.indexOf(id) < 0) {
            matchedTags.push(id);
          }
        });
        //writeDebug("matchedTags="+matchedTags);

        // decide which tag to use
        if (matchedTags.length == 0) {
          //writeDebug("no matched tags");
          return;
        }
        if (matchedTags.length == 1) {
          values.push(matchedTags[0]);
          setTags(values, false);
          startPos = endPos = $input.val().length;
        } else {
          setTags(values);

          currentTags = $input.val();
          var nextTag = matchedTags[0];
          var state = 0;
          for (var i = 0; i < matchedTags.length; i++) {
            if (matchedTags[i] == origLast) {
              state = 1;
            } else {
              if (state == 1) {
                nextTag = matchedTags[i];
                break;
              }
            }
          }
          //writeDebug("nextTag="+nextTag);
          startPos = currentTags.length+last.length;
          endPos = currentTags.length+nextTag.length;
          if (currentTags.length > 0) {
            startPos += 2;
            endPos += 2;
          }
          //writeDebug("1 - startPos="+startPos+" endPos="+endPos)

          if (currentTags.match(/^ *$/)) {
            currentTags = nextTag;
          } else {
            currentTags += ", "+nextTag;
          }
          $input.val(currentTags);
        }

        // set cursor and selection
        if (typeof(elem.setSelectionRange) == 'function') {
          elem.setSelectionRange(startPos, endPos);
          //writeDebug("using setSelectionRange");
        } else if (document.selection) { // IE
          //writeDebug("found document.selection");
        } else { // standard browsers
          elem.selectionStart = startPos;
          elem.selectionEnd = endPos;
        }
        var startPos = elem.selectionStart;
        var endPos = elem.selectionEnd;
        //writeDebug("2 - startPos="+startPos+" endPos="+endPos)
      }
      
      // return handler ******************************************************
      function handleReturnKey() {
        //writeDebug("called handleReturnKey()");
        var currentTags = $input.val();
        var values = currentTags.split(/\s*,\s*/);
        var newValues = new Object();

        // remove dupplicates
        for (var i = 0; i < values.length; i++) {
          newValues[values[i]] = 1;
        }
        values = new Array();
        for (var key in newValues) {
          values.push(key);
        }
        $input.val(values.sort().join(", "));

        var elem = $input.get(0);
        elem.focus();

        // set cursor
        var length = $input.val().length;
        if (typeof(elem.setSelectionRange) == 'function') {
          elem.setSelectionRange(length, length);
          //writeDebug("using setSelectionRange");
        } else if (document.selection) { // IE
          //writeDebug("found document.selection");
        } else { // browsers that don't have setSelectionRange
          elem.selectionStart = length;
          elem.selectionEnd = length;
        }
      }

      // toggle a tag in the input field and the cloud ***********************
      function toggleTag(tag) {
        //writeDebug("called toggleTag("+tag+")");

        var currentValues = $input.val() || '';
        currentValues = currentValues.split(/\s*,\s*/);
        var found = false;
        var newValues = new Array();
        for (var i = 0; i < currentValues.length; i++)  {
          var value = currentValues[i];
          if (!value) 
            continue;
          if (value == tag) {
            found = true;
          } else {
            if (value.indexOf(tag) != 0) {
              newValues.push(value);
            }
          }
        }

        if (!found) {
          newValues.push(tag)
        }
        //writeDebug("newValues="+newValues);

        setTags(newValues);
      }

      // add a tag to the selection ******************************************
      function setTags(tags, doSort) {
        //writeDebug("called setTags("+tags+")");

        clearSelection();
        var values;
        if (typeof(tags) == 'object') {
          values = tags;
        } else {
          values = tags.split(/\s*,\s*/);
        }
        if (!values.length) {
          return;
        }
        var tmpValues = new Array()
        for (var i = 0; i < values.length; i++) {
          tmpValues.push(values[i].replace(/([^0-9A-Za-z_])/, '\\$1'));
        }
        var filter = "#"+tmpValues.join(",#");
        //writeDebug("filter="+filter);
        $(filter, $tagCloud).addClass("current");
        if (doSort) {
          values = values.sort();
        }
        $input.val(values.join(", "));
      }

      // clear selection *****************************************************
      function clearSelection() {
        $input.val("");
        $("a", $tagCloud).removeClass('current typed');
      }
 
      // reset selection *****************************************************
      function resetSelection() {
        setTags(initialTags);
      }

      // init ****************************************************************
      function init() {
        // events 
        writeDebug("called init()");
        $input.keyup(handleKeys).keypress(handleKeys);
        $(thisOpt.clearButton, $this).click(function() {
          clearSelection();
          this.blur();
        });
        $(thisOpt.resetButton, $this).click(function() {
          resetSelection();
          this.blur();
        });

        initialTags = new Array();
        // tag cloud links
        $("a", $tagCloud).click(function() {
          writeDebug("click");
          this.blur(); 
          toggleTag($(this).attr('id'));
        }).filter(".current").each(function() {
          var term = $(this).attr('id');
          initialTags.push(term);
        });

        resetSelection();
      }

      init();
    });
  };

  /***************************************************************************
   * plugin defaults
   */
  $.fn.tagSelector.defaults = {
    debug: false,
    input: ".clsTagCloudInput",
    tagCloud: ".clsTagCloud",
    clearButton: ".clsClearButton",
    resetButton: ".clsResetButton"
  };

  /***************************************************************************
   * private static function for debugging using the firebug console
   */
  function writeDebug(msg) {
    if ($.fn.tagSelector.defaults.debug) {
      msg = "DEBUG: TagSelector - "+msg;
      if (window.console && window.console.log) {
        window.console.log(msg);
      } else { 
        //alert(msg);
      }
    }
  };
 
})(jQuery);
