// Set up Wikiwyg overrides for Wikimedia
Wikiwyg.prototype.saveChanges = function() {
    var self = this;
    this.current_mode.toHtml( function(html) { self.fromHtml(html) });
    this.displayMode();
}

proto = Wikiwyg.Toolbar.prototype;
proto.config.controlLayout = [
    'save', 'cancel', 'mode_selector', '/',
    'bold',
    'italic',
    'link',
    'h2',
    'ordered',
    'unordered',
    'math',
    'nowiki',
    'hr'
];
proto.config.controlLabels.math = 'Math';
proto.config.controlLabels.nowiki = 'As Is';

proto = Wikiwyg.Wikitext.prototype;
proto.config.markupRules.bold = ['bound_phrase', "'''", "'''"];
proto.config.markupRules.italic = ['bound_phrase', "''", "''"];
proto.config.markupRules.link = ['bound_phrase', '[[', ']]'];
proto.config.markupRules.math = ['bound_phrase', '<math>', '</math>'];
proto.config.markupRules.nowiki = ['bound_phrase', '<nowiki>', '</nowiki>'];
proto.config.markupRules.h1 = ['bound_line', '= ', ' ='],
proto.config.markupRules.h2 = ['bound_line', '== ', ' =='],
proto.config.markupRules.h3 = ['bound_line', '=== ', ' ==='],
proto.config.markupRules.h4 = ['bound_line', '==== ', ' ===='],
proto.config.markupRules.h5 = ['bound_line', '===== ', ' ====='],
proto.config.markupRules.h6 = ['bound_line', '====== ', ' ======'],

proto.do_math = Wikiwyg.Wikitext.make_do('math');
proto.do_nowiki = Wikiwyg.Wikitext.make_do('nowiki');

proto.convertWikitextToHtml = function(wikitext, func) {
    var postdata = 'markup=' + encodeURIComponent(wikitext);
    GM_xmlhttpRequest({
        method: 'POST',
        'url': 'http://www.wikiwyg.net/mediawiki/index.php/Special:Markuptohtml',
        data: postdata,
        headers: {
            'Content-type': 'application/x-www-form-urlencoded'
        },
        onload: function(response) {
            func(response.responseText);
        }
    });
}

// Inject Wikiwyg css into the head
var head = document.getElementsByTagName('head')[0];

var link = document.createElement('link');
link.setAttribute('rel', 'stylesheet');
link.setAttribute('type', 'text/css');
link.setAttribute('href', 'http://demo.wikiwyg.net/wikiwyg/demo/wikipedia/wikiwyg.css');
head.appendChild(link);


wikiwyg_divs = [];
function createWikiwygDiv(elem, parent) {
    var div = document.createElement('div');
    div.setAttribute('class', 'wikiwyg_area');
    var insert = elem.previousSibling;
    var edit = elem;
    var elem = elem.nextSibling;
    while (elem) {
        if (elem.className == 'editsection')
            break;
        if (elem.className == 'printfooter') {
            elem = null;
            break;
        }
        var temp = elem.nextSibling;
        div.appendChild(elem);
        elem = temp;
    }
    wikiwyg_divs.push([edit, div]);
    parent.insertBefore(div, insert);
    parent.insertBefore(edit, div);
    return elem;
}

// Munge bodyContent into bite-sized divs
var body_content = document.getElementById('bodyContent');
var elem = body_content.firstChild;
while (elem) {
    if (elem.className == 'editsection') {
        elem = createWikiwygDiv(elem, body_content);
    }
    else
        elem = elem.nextSibling; 
}

wikiwygs = [];
for (var i = 0; i < wikiwyg_divs.length; i++) {
    var edit_div = wikiwyg_divs[i][0];
    var wiki_div = wikiwyg_divs[i][1];
    var myConfig = {
        doubleClickToEdit: true,
        toolbar: {
            imagesLocation:
                'http://www.wikiwyg.net/test/demo/wikipedia/images/',
            imagesExtension: '.png'
        }
    }
    
    var myWikiwyg = new Wikiwyg();
    myWikiwyg.createWikiwygArea(wiki_div, myConfig);
    wikiwygs.push(myWikiwyg);
    var a = edit_div.getElementsByTagName('a')[0];
    function activate(w) {
        return function() {
            w.editMode();
            return false;
        };
    };
    a.onclick = activate(myWikiwyg);
}
