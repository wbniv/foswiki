/*
 * Copyright (C) 2006 Crawford Currie http://c-dot.co.uk
 * Derived from code Copyright (C) ILOG 2005
 * Which was derived from code Copyright (C) Peter Thoeny and TWiki
 * Contributors 2001-2005
 */

/*
 * Convertor class for translating TML (TWiki Meta Language) into HTML
 * The design goal was to support round-trip conversion from well-formed
 * TML to XHTML1.0 and back to identical TML. Notes that some deprecated
 * TML syntax is not supported.
 */
function TML2HTML() {
  
  /* Constants */
  var startww = "(^|\\s|\\()";
  var endww = "($|(?=[\\s\\,\\.\\;\\:\\!\\?\\)]))";
  var PLINGWW =
    new RegExp(startww+"!([\\w*=])", "gm");
  var TWIKIVAR =
    new RegExp("^%(<nop(?:result| *\\/)?>)?([A-Z0-9_:]+)({.*})?$", "");
  var MARKER =
    new RegExp("\u0001([0-9]+)\u0001", "");
  var protocol = "(file|ftp|gopher|https|http|irc|news|nntp|telnet|mailto)";
  var ISLINK =
    new RegExp("^"+protocol+":|/");
  var HEADINGDA =
    new RegExp('^---+(\\++|#+)(.*)$', "m");
  var HEADINGHT =
    new RegExp('^<h([1-6])>(.+?)</h\\1>', "i");
  var HEADINGNOTOC =
    new RegExp('(!!+|%NOTOC%)');
  var wikiword = "[A-Z]+[a-z0-9]+[A-Z]+[a-zA-Z0-9]*";
  var WIKIWORD =
    new RegExp(wikiword);
  var webname = "[A-Z]+[A-Za-z0-9_]*(?:(?:[\\./][A-Z]+[A-Za-z0-9_]*)+)*";
  var WEBNAME =
    new RegExp(webname);
  var anchor = "#[A-Za-z_]+";
  var ANCHOR =
    new RegExp(anchor);
  var abbrev = "[A-Z]{3,}s?\\b";
  var ABBREV =
    new RegExp(abbrev);
  var ISWIKILINK =
    new RegExp( "^(?:("+webname+")\\.)?("+wikiword+")("+anchor+")?");
  var WW =
    new RegExp(startww+"((?:("+webname+")\\.)?("+wikiword+"))", "gm");
  var ITALICODE =
    new RegExp(startww+"==(\\S+?|\\S[^\\n]*?\\S)=="+endww, "gm");
  var BOLDI =
    new RegExp(startww+"__(\\S+?|\\S[^\\n]*?\\S)__"+endww, "gm");
  var CODE =
    new RegExp(startww+"\\=(\\S+?|\\S[^\\n]*?\\S)\\="+endww, "gm");
  var ITALIC =
    new RegExp(startww+"\\_(\\S+?|\\S[^\\n]*?\\S)\\_"+endww, "gm");
  var BOLD =
    new RegExp(startww+"\\*(\\S+?|\\S[^\\n]*?\\S)\\*"+endww, "gm");
  var NOPWW =
    new RegExp("<nop(?: *\/)?>("+wikiword+"|"+abbrev+")", "g");
  var URI =
    new RegExp("(^|[-*\\s(])("+protocol+":([^\\s<>\"]+[^\s*.,!?;:)<]))");

  /*
   * Main entry point, and only external function. 'options' is an object
   * that must provide the following method:
   *   getViewUrl(web,topic) -> url (where topic may include an anchor)
   * and may optionally provide
   *   expandVarsInURL(url, options) -> url
   * getViewUrl must generate a URL for the given web and topic.
   * expandVarsinURL gives an opportunity for a caller to expand selected
   * Macros embedded in URLs
   */
  this.convert = function(content, options) {
    this.opts = options;

    content = content.replace(/\\\n/g, " ");
    
    content = content.replace(/\u0000/g, "!");	
    content = content.replace(/\u0001/g, "!");	
    content = content.replace(/\u0002/g, "!");	
    
    this.refs = new Array();

    // Render TML constructs to tagged HTML
    return this._getRenderedVersion(content);
  };
  
  this._liftOut = function(text) {
    index = '\u0001' + this.refs.length + '\u0001';
    this.refs.push(text);
    return index;
  }
  
  this._dropBack = function(text) {
    var match;
    
    while (match = MARKER.exec(text)) {
      var newtext = this.refs[match[1]];
      if (newtext != match[0]) {
        var i = match.index;
        var l = match[0].length;
        text = text.substr(0, match.index) +
          newtext +
          text.substr(match.index + match[0].length);
      }
      MARKER.lastIndex = 0;
    }
    return text;
  };
  
  // Parse twiki variables.
  //for InlineEdit, would like to not nest them, and to surround entire html entities where needed
  this._processTags = function(text) {
    
    var queue = text.split(/%/);
    var stack = new Array();
    var stackTop = '';
    var prev = '';
    
    while (queue.length) {
      var token = queue.shift();
      if (stackTop.substring(-1) == '}') {
        while (stack.length && !TWIKIVAR.match(stackTop)) {
          stackTop = stack.pop() + stackTop;
        }
      }
      
      var match = TWIKIVAR.exec(stackTop);
      if (match) {
        var nop = match[1];
        var args = match[3];
        if (!args)
          args = '';
        // You can always replace the %'s here with a construct e.g.
        // html spans; however be very careful of variables that are
        // used in the context of parameters to HTML tags e.g.
        // <img src="%ATTACHURL%...">
        var tag = '%' + match[2] + args + '%';
        if (nop) {
          nop = nop.replace(/[<>]/g, '');
          tag = "<span class='TML'"+nop+">"+tag+"</span>";
        }
        stackTop = stack.pop() + this._liftOut(tag) + token;
      } else {
        stack.push(stackTop);
        stackTop = prev + token;
      }
      prev = '%';
    }
    // Run out of input. Gather up everything in the stack.
    while (stack.length) {
      stackTop = stack.pop(stack) + stackTop;
    }
    
    return stackTop;
  };
  
  this._makeLink = function(url, text) {
    if (!text || text == '')
      text = url;
    url = this._liftOut(url);
    return "<a href='"+url+"'>" + text + "</a>";
  };
  
  this._expandRef = function(ref) {
    if (this.opts['expandVarsInURL']) {
      var origtxt = this.refs[ref];
      var newtxt = this.opts['expandVarsInURL'](origtxt, this.opts);
      if (newTxt != origTxt)
        return newtxt;
    }
    return '\u0001'+ref+'\u0001';
  };
  
  this._expandURL = function(url) {
    if (this.opts['expandVarsInURL'])
      return this.opts['expandVarsInURL'](url, this.opts);
    return url;
  };
  
  this._makeSquab = function(url, text) {
    url = _sg(MARKER, url, function(match) {
                this._expandRef(match[1]);
              }, this);
    
    if (url.test(/[<>\"\x00-\x1f]/)) {
      // we didn't manage to expand some variables in the url
      // path. Give up.
      // If we can't completely expand the URL, then don't expand
      // *any* of it (hence save)
      return text ? "[[save][text]]" : "[[save]]";
    }
    
    if (!text) {
      // forced link [[Word]] or [[url]]
      text = url;
      if (url.test(ISLINK)) {
        var wurl = url;
        wurl.replace(/(^|)(.)/g,$2.toUpperCase());
        var match = wurl.exec(ISWEB);
        if (match) {
          url = this.opts['getViewUrl'](match[1], match[2] + match[3]);
        } else {
          url = this.opts['getViewUrl'](null, wurl);
        }
      }
    } else if (match = url.exec(ISWIKILINK)) {
      // Valid wikiword expression
      url = this.optsgetViewUrl(match[1], match[2]) + match[3];
    }
    
    text.replace(WW, "$1<nop>$2");
    
    return this._makeLink(url, text);
  };
  
  // Lifted straight out of DevelopBranch Render.pm
  this._getRenderedVersion = function(text, refs) {
    if (!text)
      return '';
    
    this.LIST = new Array();
    this.refs = new Array();
    
    // Initial cleanup
    text = text.replace(/\r/g, "");
    text = text.replace(/^\n+/, "");
    text = text.replace(/\n+$/, "");

    var removed = new BlockSafe();
    
    text = removed.takeOut(text, 'verbatim', true);

    // Remove PRE to prevent TML interpretation of text inside it
    text = removed.takeOut(text, 'pre', false);
    
    // change !%XXX to %<nop>XXX
    text = text.replace(/!%([A-Za-z_]+(\{|%))/g, "%<nop>$1");

    // change <nop>%XXX to %<nopresult>XXX. A nop before th % indicates
    // that the result of the tag expansion is to be nopped
    text = text.replace(/<nop>%(?=[A-Z]+(\{|%))/g, "%<nopresult>");
    
    // Pull comments
    text = _sg(/(<!--.*?-->)/, text,
               function(match) {
                 this._liftOut(match[1]);
               }, this);
    
    // Remove TML pseudo-tags so they don't get protected like HTML tags
    text = text.replace(/<(.?(noautolink|nop|nopresult).*?)>/gi,
                        "\u0001($1)\u0001");
    
    // Expand selected TWiki variables in IMG tags so that images appear in the
    // editor as images
    text = _sg(/(<img [^>]*src=)([\"\'])(.*?)\2/i, text,
               function(match) {
                 return match[1]+match[2]+this._expandURL(match[3])+match[2];
               }, this);
    
    // protect HTML tags by pulling them out
    text = _sg(/(<\/?[a-z]+(\s[^>]*)?>)/i, text,
               function(match) {
                 return this._liftOut(match[1]);
               }, this);
    
    var pseud = new RegExp("\u0001\((.*?)\)\u0001", "g");
    // Replace TML pseudo-tags
    text = text.replace(pseud, "<$1>");
    
    // Convert TWiki tags to spans outside parameters
    text = this._processTags(text);
    
    // Change ' !AnyWord' to ' <nop>AnyWord',
    text = text.replace(PLINGWW, "$1<nop>$2");
    
    text = text.replace(/\\\n/g, "");  // Join lines ending in '\'
    
    // Blockquoted email (indented with '> ')
    text = text.replace(/^>(.*?)/gm,
                        '&gt;<cite class=TMLcite>$1<br /></cite>');
    
    // locate isolated < and > and translate to entities
    // Protect isolated <!-- and -->
    text = text.replace(/<!--/g, "\u0000{!--");
    text = text.replace(/-->/g, "--}\u0000");
    // SMELL: this next fragment is a frightful hack, to handle the
    // case where simple HTML tags (i.e. without values) are embedded
    // in the values provided to other tags. The only way to do this
    // correctly (i.e. handle HTML tags with values as well) is to
    // parse the HTML (bleagh!)
    text = text.replace(/<(\/[A-Za-z]+)>/g, "{\u0000$1}\u0000");
    text = text.replace(/<([A-Za-z]+(\s+\/)?)>/g, "{\u0000$1}\u0000");
    text = text.replace(/<(\S.*?)>/g, "{\u0000$1}\u0000");
    // entitify lone < and >, praying that we haven't screwed up :-(
    text = text.replace(/</g, "&lt;");
    text = text.replace(/>/g, "&gt;");
    text = text.replace(/{\u0000/g, "<");
    text = text.replace(/}\u0000/g, ">");
    
    // standard URI
    text = _sg(URI, text,
               function(match) {
                 return match[1] + this._makeLink(match[2],match[2]);
               }, this);
    
    // Headings
    // '----+++++++' rule
    text = _sg(HEADINGDA, text, function(match) {
                 return this._makeHeading(match[2],match[1].length);
               }, this);
    
    // Horizontal rule
    var hr = "<hr class='TMLhr' />";
    text = text.replace(/^---+/gm, hr);
    
    // Now we really _do_ need a line loop, to process TML
    // line-oriented stuff.
    var isList = false;		// True when within a list
    var insideTABLE = false;
    this.result = new Array();

    var lines = text.split(/\n/);
    for (var i in lines) {
      var line = lines[i];
      // Table: | cell | cell |
      // allow trailing white space after the last |
      if (line.match(/^(\s*\|.*\|\s*)/)) {
        if (!insideTABLE) {
          result.push("<table border=1 cellpadding=0 cellspacing=1>");
        }
        result.push(this._emitTR(match[1]));
        insideTABLE = true;
        continue;
      } else if (insideTABLE) {
        result.push("</table>");
        insideTABLE = false;
      }
      // Lists and paragraphs
      if (line.match(/^\s*$/)) {
        isList = false;
        line = "<p />";
      }
      else if (line.match(/^\S+?/)) {
        isList = false;
      }
      else if (line.match(/^(\t|   )+\S/)) {
        var match;
        if (match = line.match(/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s(.*)$/)) {
          // Definition list
          line = "<dt> "+match[3]+" </dt><dd> "+match[5];
          this._addListItem('dl', 'dd', match[1]);
          isList = true;
        }
        else if (match = line.match(/^((\t|   )+)(\S+?):\s(.*)$/)) {
          // Definition list
          line = "<dt> "+match[3]+" </dt><dd> "+match[4];
          this._addListItem('dl', 'dd', match[1]);
          isList = true;
        }
        else if (match = line.match(/^((\t|   )+)\* (.*)$/)) {
          // Unnumbered list
          line = "<li> "+match[3];
          this._addListItem('ul', 'li', match[1]);
          isList = true;
        }
        else if (match = line.match(/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/)) {
          // Numbered list
          var ot = $3;
          ot = ot.replace(/^(.).*/, "$1");
          if (!ot.match(/^\d/)) {
            ot = ' type="'+ot+'"';
          } else {
            ot = '';
          }
          line.replace(/^((\t|  )+)([1AaIi]\.|\d+\.?) ?/,
                       "<li"+ot+"> ");
          this._addListItem('ol', 'li', match[1]);
          isList = true;
        }
      } else {
        isList = false;
      }
      
      // Finish the list
      if (!isList) {
        this._addListItem('', '', '');
      }
      
      this.result.push(line);
    }
    
    if (insideTABLE) {
      this.result.push('</table>');
    }
    this._addListItem('', '', '');
    
    text = this.result.join("\n");
    text = text.replace(ITALICODE, "$1<b><code>$2</code></b>")
    text = text.replace(BOLDI, "$1<b><i>$2</i></b>");
    text = text.replace(BOLD, "$1<b>$2</b>")
    text = text.replace(ITALIC, "$1<i>$2</i>")
    text = text.replace(CODE, "$1<code>$2</code>");
    
    // Handle [[][] and [[]] links
    text = text.replace(/(^|\s)\!\[\[/gm, "$1[<nop>[");
    
    // We _not_ support [[http://link text]] syntax
    
    // detect and escape nopped [[][]]
    text = text.replace(/\[<nop(?: *\/)?>(\[.*?\](?:\[.*?\])?)\]/g,
                        '[<span class="TMLnop">$1</span>]');
    text.replace(/!\[(\[.*?\])(\[.*?\])?\]/g,
                 '[<span class="TMLnop">$1$2</span>]');
    
    // Spaced-out Wiki words with alternative link text
    // i.e. [[1][3]]

    text = _sg(/\[\[([^\]]*)\](?:\[([^\]]+)\])?\]/, text,
               function(match) {
                 return this._makeSquab(match[1],match[2]);
               }, this);
    
    // Handle WikiWords
    text = removed.takeOut(text, 'noautolink', true);
    
    text = text.replace(NOPWW, '<span class="TMLnop">$1</span>');
    
    text = _sg(WW, text,
               function(match) {
                 var url = this.opts['getViewUrl'](match[3], match[4]);
                 if (match[5])
                   url += match[5];
                 return match[1]+this._makeLink(url, match[2]);
               }, this);

    text = removed.putBack(text, 'noautolink', 'div');
    
    text = removed.putBack(text, 'pre');
    
    // replace verbatim with pre in the final output
    text = removed.putBack(text, 'verbatim', 'pre',
                           function(text) {
                             // use escape to URL encode, then JS encode
                             return HTMLEncode(text);
                           });
    
    // There shouldn't be any lingering <nopresult>s, but just
    // in case there are, convert them to <nop>s so they get removed.
    text = text.replace(/<nopresult>/g, "<nop>");
    
    return this._dropBack(text);
  }
  
  // Make the html for a heading
  this._makeHeading = function(heading, level) {
    var notoc = '';
    if (heading.match(HEADINGNOTOC)) {
      heading = heading.substring(0, match.index) +
        heading.substring(match.index + match[0].length);
      notoc = ' notoc';
    }
    return "<h"+level+" class='TML"+notoc+"'>"+heading+"</h"+level+">";
  };


  this._addListItem = function(type, tag, indent) {
    indent = indent.replace(/\t/g, "   ");
    var depth = indent.length / 3;
    var size = this.LIST.length;

    if (size < depth) {
      var firstTime = true;
      while (size < depth) {
        var obj = new Object();
        obj['type'] = type;
        obj['tag'] = tag;
        this.LIST.push(obj);
        if (!firstTime)
          this.result.push("<"+tag+">");
        this.result.push("<"+type+">");
        firstTime = false;
        size++;
      }
    } else {
      while (size > depth) {
        var types = this.LIST.pop();
        this.result.push("</"+types['tag']+">");
        this.result.push("</"+types['type']+">");
        size--;
      }
      if (size) {
        this.result.push("</this.{LIST}.[size-1].{element}>");
      }
    }
    
    if  (size) {
      var oldt = this.LIST[size-1];
      if (oldt['type'] != type) {
        this.result.push("</"+oldt['type']+">\n<type>");
        this.LIST.pop();
        var obj = new Object();
        obj['type'] = type;
        obj['tag'] = tag;
        this.LIST.push(obj);
      }
    }
  }
  
  this._emitTR = function(row) {
    
    row.replace(/^(\s*)\|/, "");
    var pre = 1;
                            
    var tr = new Array();
                            
    while (match = row.match(/^(.*?)\|/)) {
      row = row.substring(match[0].length);
      var cell = 1;
      
      if (cell == '') {
        cell = '%SPAN%';
      }
      
      var attr = new Attrs();
      
      my (left, right) =  (0, 0);
      if (cell.match(/^(\s*).*?(\s*)/)) {
        left = length (1);
        right = length (2);
      }
          
      if (left > right) {
        attr.set('class', 'align-right');
        attr.set('style', 'text-align: right');
      } else if (left < right) {
        attr.set('class', 'align-left');
        attr.set('style', 'text-align: left');
      } else if (left > 1) {
        attr.set('class', 'align-center');
        attr.set('style', 'text-align: center');
      }
      
      // make sure there's something there in empty cells. Otherwise
      // the editor will compress it to (visual) nothing.
      cell.replace(/^\s*/g, "&nbsp;");
      
      // Removed TH to avoid problems with handling table headers. TWiki
      // allows TH anywhere, but Kupu assumes top row only, mostly.
      // See Item1185
      tr.push("<td "+attr+"> "+cell+" </td>");
    }
    return pre+"<tr>" + tr.join('')+"</tr>";
  }
}

/* Make sure 'this' inside a method points to its class */
function ContextFixer(func, context) {
    this.func = func;
    this.context = context;
    this.args = arguments;
    var self = this;

    this.execute = function() {
        /* execute the method */
        var args = new Array();
        // the first arguments will be the extra ones of the class
        for (var i=0; i < self.args.length - 2; i++) {
            args.push(self.args[i + 2]);
        };
        // the last are the ones passed on to the execute method
        for (var i=0; i < arguments.length; i++) {
            args.push(arguments[i]);
        };
        return self.func.apply(self.context, args);
    };

};

// helper, does the equivalent of s///ge
function _sg(regex, text, f, context) {
  var fn = new ContextFixer(f, context);
  var match;
  while (match = regex.exec(text)) {
    var newtext = fn.execute(match);
    if (newtext != match[0]) {
      var i = match.index;
      var l = match[0].length;
      text = text.substr(0, match.index) +
        newtext +
        text.substr(match.index + match[0].length);
    }
  }
  return text;
}

// Helper class, parses and stores HTML tag attributes
function Attrs(p) {
  this.toString = function() {
    var res = '';
    for (var p in this.params) {
      res += ' '+p+'="'+this.params[p]+'"';
    }
    return res;
  }

  this.set = function(what, val) {
    this.params[what] = val;
  };

  this.get = function(what) {
    return this.params[what];
  };

  this.params = new Array();
  if (p) {
    _sg(/^\s*([A-Za-z0-9_]+)=(\".*\"|\'.*\'|[^\'\"]\S*)/,
        p, function(match) {
          var name = match[1];
          var val = match[2];
          val.replace(/([\'\"])(.*)\1/g, "$1");
          this.params[name] = val;
          return "";
        });
  }
};

// Helper class, stores away tagged blockes removed from the text
// during working
function BlockSafe() {

  this.map = new Array();

  this.takeOut = function(intext, tag, addClass) {
    
    var open = new RegExp("^(.*)<"+tag+"\\b([^>]*)>(.*)$", "i");
    var close = new RegExp("^(.*)</"+tag+">(.*)$", "i");
    var out = '';
    var depth = 0;
    var scoop;
    var tagParams;
    var n = 0;
    var lines = intext.split(/\n/);

    for (var i in lines) {
      var line = lines[i];
      var match = open.exec(line);
      if (match) {
        if (!depth++) {
          out += match[1];
          tagParams = match[2];
          scoop = '';
          line = match[3];
        }
      }
      match = close.exec(line);
      if (depth && match) {
        scoop += match[1];
        var rest = match[2];
        if (!--depth) {
          var placeholder = '\u0000'+tag+n+'\u0000';
          var obj = new Object();
          obj['params'] = new Attrs(tagParams);
          if (addClass)
            this.addClass(obj['params'],tag);
          obj['text'] = scoop;
          this.map[placeholder] = obj;
          line = placeholder;
          n++;
        }
      }
      if (depth) {
        scoop += line + "\n";
      } else {
        out += line + "\n";
      }
    }
    
    if (depth) {
      var placeholder = '\u0000'+tag+n+'\u0000';
      var obj = new Object();
      obj['params'] = new Attrs(tagParams);
      if (addClass)
        this.addClass(obj['params'],tag);
      obj['text'] = scoop;
      this.map[placeholder] = obj;
      out += placeholder;
    }
  
    out = out.replace(/\n+$/, "");

    return out;
  };
    
  this.putBack = function(text, tag, newtag, callback) {
    if (!newtag)
      newtag = tag;

    var tagre = new RegExp("^\u0000"+tag+"\\d+\u0000","i");
    for (var placeholder in this.map) {
      if (placeholder.match(tagre)) {
        var obj = this.map[placeholder];
        var val = obj['text'];
        if (callback) {
          val = callback(val);
        }
        var p = obj['params'];
        text = text.replace(placeholder,
                            "<"+newtag+
                            p+
                            ">"+val+"</"+newtag+">");
        this.map[placeholder] = null;
      }
    }
    return text;
  };

  this.addClass = function(attr, clas) {
    var claz = attr.get('class');
    if (claz)
      claz += ' ';
    else
      claz = '';
    attr.set('class', claz+'TML'+clas);
  };
}

function HTMLEncode(text) {
  text = text.replace(/&/g, "&amp;");
  text = text.replace(/</g, "&lt;");
  text = text.replace(/>/g, "&gt;");
  text = text.replace(/"/g, "&quot;");
  return text;
}