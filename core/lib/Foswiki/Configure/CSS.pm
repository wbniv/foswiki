package Foswiki::Configure::CSS;

use strict;

use vars qw( $css );

sub css {
    local $/ = undef;
    return <DATA>;
}

1;
__DATA__

/* Foswiki base CSS */

.twikiMakeVisible,
.twikiMakeVisibleInline,
.twikiMakeVisibleBlock {
	display:none; /* will be made visible with javascript */
}
.twikiLeft {
	float:left;
	position:relative;
}
.twikiRight {
	position:relative;
	float:right;
	display:inline;
	margin:0;
}
.twikiClear {
	/* to clean up floats */
	margin:0;
	padding:0;
	height:0;
	line-height:0px;
	clear:both;
	display:block;
}
.twikiHidden {
	display:none;
}
.twikiSmall {
	font-size:86%;
	line-height:110%; /*S3*/
}
.twikiSmallish {
	font-size:94%; /*S2*/
}
.twikiBroadcastMessage {
	background-color:#ff0;
	padding:.25em .5em;
	margin:0 0 1em 0;
}
.twikiBroadcastMessage b,
.twikiBroadcastMessage strong {
	color:#f00;
}
.twikiAlert,
.twikiAlert code {
	color:#f00;
}
.twikiEmulatedLink {
	text-decoration:underline;
}
.twikiAccessKey {
	text-decoration:none;
	border-width:0 0 1px 0;
	border-style:solid;
}
a:hover .twikiAccessKey {
	text-decoration:none;
	border:none;
}
.twikiImage img {
	padding:3px;
	border-width:1px;
	border-style:solid;
}
.twikiPreviewArea {
	border-width:1px;
	border-style:solid;
	border-color:#f00;
	margin:0 -0.5em 2em -0.5em;
	padding:.5em;
}

/* 
Basic layout derived from http://www.positioniseverything.net/articles/pie-maker/pagemaker_form.php.
I've changed many so things that I won't put a full copyright notice. However all hacks (and comments!) are far beyond my knowledge and this deserves full credits:

Original copyright notice:
Parts of these notes are
(c) Big John @ www.positioniseverything.net and (c) Paul O'Brien @ www.pmob.co.uk, all of whom contributed significantly to the design of
the css and html code.

Reworked for Foswiki: (c) Arthur Clemens @ visiblearea.com
*/

html, body {
	margin:0; /*** Do NOT set anything other than a left margin for the page
as this will break the design ***/
	padding:0;
	border:0;
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
}
body {
	background:#fff;
	min-width:100%; /*** This is needed for moz. Otherwise, the header and patternBottomBar will
slide off the left side of the page if the screen width is narrower than the design.
Not seen by IE. Left Col + Right Col + Center Col + Both Inner Borders + Both Outer Borders ***/
	text-align:center; /*** IE/Win (not IE/MAC) alignment of page ***/
}
.clear {
	clear:both;
	/*** these next attributes are designed to keep the div
	height to 0 pixels high, critical for Safari and Netscape 7 ***/
	height:0px;
	overflow:hidden;
	line-height:1%;
	font-size:0px;
}

#patternWrapper {
	height:100%; /*** moz uses this to make full height design. As this #patternWrapper is inside the #patternPage which is 100% height, moz will not inherit heights further into the design inside this container, which you should be able to do with use of the min-height style. Instead, Mozilla ignores the height:100% or min-height:100% from this point inwards to the center of the design - a nasty bug.
If you change this to height:100% moz won't expand the design if content grows.
Aaaghhh. I pulled my hair out over this for days. ***/
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Fixes height for non moz browsers, to full height ***/
}
#patternWrapp\65	r{ /*** for Opera and Moz (and some others will see it, but NOT Safari) ***/
	height:auto; /*** For moz to stop it fixing height to 100% ***/
}
/* \*/
* html #patternWrapper{
	height:100%;
}

#patternPage {
	margin-left:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	margin-right:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	text-align:left; /*** IE Win re-alignment of page if page is centered ***/
	position:relative;
	width:100%; /*** Needed for Moz/Opera to keep page from sliding to left side of
page when it calculates auto margins above. Can't use min-width. Note that putting
width in #patternPage shows it to IE and causes problems, so IE needs a hack
to remove this width. Left Col + Right Col + Center Col + Both Inner Border + Both Outer Borders ***/
/* \*/

/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for Moz to give full height design if page content is
too small to fill the page ***/
}
/* Last style with height declaration hidden from Mac IE 5.x */
/*** Fixes height for IE, back to full height,
from esc tab hack moz min-height solution ***/
#patternOuter {
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:relative; /*** IE needs this or the contents won't show outside the parent container. ***/

	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for full height inner borders in Win IE ***/
}

#patternFloatWrap {
	width:100%;
	float:left;
	display:inline;
}

#patternLeftBar {
	/* Left bar width is defined in viewleftbar.pattern.tmpl */
	float:left;
	display:inline;
	overflow:hidden;
}
#patternLeftBarContents {
	position:relative;
	/* for margins and paddings use style.css */
}
#patternMain {
	width:100%;
	float:right;
	display:inline;
}
#patternTopBar {
	/* Top bar height is defined in viewtopbar.pattern.tmpl */
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:absolute;
	top:0px;
	width:100%;
}
#patternTopBarContents {
	height:1%; /* or Win IE won't display a background */
	/* for margins/paddings use style.css */
}
#patternTopToolBar {
	/* Top bar y and height is defined in viewtopbar.pattern.tmpl */
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:absolute;
	width:100%;
}
#patternBottomBar {
	z-index:1; /* Critical value for Moz/Opera Background Column colors fudge to work */
	clear:both;
	width:100%;
}

/*	-----------------------------------------------------------
	STYLE
	Appearance: margins, padding, fonts, borders
	-----------------------------------------------------------	*/
	

/*	----------------------------------------------------------------------------
	CONSTANTS
	
	Sizes
	----------------------------------------
	S1 line-height											1.5em
	S2 somewhat smaller font size							94%
	S3 small font size, twikiSmall							font-size:86%; line-height:110%;
	S4 horizontal bar padding (h2, patternTop)				5px
	S5 form and attachment padding							20px
	S6 left margin left bar									1em

	------------------------------------------------------------------------- */

/* GENERAL HTML ELEMENTS */

html body {
	font-size:104%; /* to change the site's font size, change #patternPage below */
	voice-family:"\"}\""; 
	voice-family:inherit;
	font-size:small;
}
html>body { /* Mozilla */
	font-size:small;	
}
p {
	margin:1em 0 0 0;
}
table {
}
th {
	line-height:1.15em;
}
label {
	padding:.15em .3em .15em 0; /* same vertical padding as twikiInputField */
}
strong, b {
	font-weight:bold;
}
hr {
	height:1px;
	border:none;
}
/* put overflow pre in a scroll area */
pre {
    width:100%;
    margin:1em 0; /* Win IE tries to make this bigger otherwise */
}
/* IE behavior for pre is defined in css.pattern.tmpl in conditional comment */
html>body pre { /* hide from IE */
	/*\*/ overflow:auto !important; /* */ overflow:scroll; width:auto; /* for Mac Safari */
}
ol, ul {
	margin-top:0;
}
ol li, ul li {}
blockquote {
	padding:.5em 1.25em;
}
.patternRenamePage blockquote,
.patternPrintPage blockquote {
	border-style:solid;
	border-width:0 0 0 3px;
}
form { 
	display:inline;
	margin:0;
	padding:0;
}

/* Text */
h1 {
	padding:0.25em 0 0 0;
	margin:0 0 .5em 0;
}
h2, h3, h4, h5, h6 {
	padding:0;
	margin:1em 0 .1em 0;
}
h1, h2, h3, h4, h5, h6 {
	font-weight:normal;
	line-height:1em;
}
h1 { font-size:215%; }
h2 { font-size:153%; }
h3 { font-size:133%; font-weight:bold; }
h4 { font-size:122%; font-weight:bold; }
h5 { font-size:110%; font-weight:bold; }
h6 { font-size:95%; font-weight:bold; }
h2, h3, h4, h5, h6 {
	display:block;
	/* give header a background color for easy scanning:*/
	padding:.25em 10px;
	margin:1.25em -10px .35em -10px;
	border-width:0 0 1px 0;
	border-style:solid;
	height:auto;	
}

h1.patternTemplateTitle {
	font-size:180%;
	text-align:center;
}
h2.patternTemplateTitle {
	text-align:center;
	margin-top:.5em;
	background:none;
	border:none;
}
/* Links */
/* somehow the twikiNewLink style have to be before the general link styles */
.twikiNewLink {
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiNewLink a {
	text-decoration:none;
	margin-left:1px;
}
.twikiNewLink a sup {
	text-align:center;
	padding:0 2px;
	vertical-align:baseline;
	font-size:100%;
	text-decoration:none;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	border-width:1px;
	border-style:solid;
	text-decoration:none;
}
.twikiNewLink a:hover sup {
	text-decoration:none;
}

:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	text-decoration:underline;
}
:link:hover,
:visited:hover {
	text-decoration:none;
}
img {
	vertical-align:text-bottom;
	border:0;
}


/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* TagMePlugin */
.tagMePlugin select {
	margin:0 .25em 0 0;
}
.tagMePlugin input { 
	border:0px;
}

/* EditTablePlugin */
.editTable .twikiTable {
	margin:0 0 2px 0;
}
.editTableEditImageButton {
	border:none;
}

/* TablePlugin */
.twikiTable {
	border-style:solid;
	border-width:1px;
	margin:2px 0;
	border-collapse:collapse;
}
.twikiTable td {
	padding:.25em .5em;
	border-width:1px;
}
.twikiTable th {
	border-left-style:solid;
	border-width:1px;
	padding:.4em .5em;
}
.twikiTable th.twikiFirstCol {
	border-left-style:none;
}
.twikiTable a:link,
.twikiTable a:visited {
	text-decoration:underline;
}
.twikiTable a:hover {
	text-decoration:underline;
}

.twikiEditForm {
	margin:0 0 .5em 0;
}

/* TwistyContrib */
.twistyTrigger a:link,
.twistyTrigger a:visited {
	text-decoration:none;
}
.twistyTrigger a:link .twikiLinkLabel,
.twistyTrigger a:visited .twikiLinkLabel {
	text-decoration:none;
}

/*tipsOfTheDay*/
.tipsOfTheDay {
	padding:10px;
}

/*	-----------------------------------------------------------
	Foswiki styles
	-----------------------------------------------------------	*/

#twikiLogin {
	width:40em;
	margin:0 auto;
	text-align:center;
}
#twikiLogin .twikiFormSteps {
	border-width:5px;
}
.twikiAttachments,
.twikiForm {
	margin:1em 0;
	padding:1px; /* fixes disappearing borders because of overflow:auto; in twikiForm */
}
.twikiTable h2, .twikiFormTable h2,
.twikiTable h3, .twikiFormTable h3,
.twikiTable h4, .twikiFormTable h4,
.twikiTable h5, .twikiFormTable h5,
.twikiTable h6, .twikiFormTable h6 {
	border:0;
	margin-top:0;
	margin-bottom:0;
}
.twikiFormTable th {
	font-weight:normal;
}
.twikiFormTable .twikiTable th {
	font-weight:bold;
}
.patternEditPage .twikiFormTable td,
.patternEditPage .twikiFormTable th {
	padding:.3em .4em;
	border-style:solid;
	border-width:0 0 1px 0;
	vertical-align:middle;
}

.patternContent .twikiAttachments,
.patternContent .twikiForm {
	/* form or attachment table inside topic area */
	font-size:94%; /*S2*/
	padding:1em 20px; /*S5*/ /* top:use less padding for the toggle link; bottom:use less space in case the table is folded in  */
	border-width:1px 0 0 0;
	border-style:solid;
	margin:0;
}
.twikiAttachments table,
table.twikiFormTable {
	margin:5px 0;
	border-collapse:collapse;
	padding:0px;
	border-spacing:0px;
	empty-cells:show;
	border-style:solid;
	border-width:1px;
}
.twikiAttachments table {
	line-height:1.5em; /*S1*/
	width:auto;
	voice-family:"\"}\""; /* hide the following for Explorer 5.x */
	voice-family:inherit;
	width:100%;
}
.twikiAttachments th {
	border-style:none none solid solid;
	border-width:1px;
}
.twikiAttachments th,
table.twikiFormTable th.twikiFormTableHRow {
	padding:3px 6px;
	height:2.5em;
	vertical-align:middle;
}
table.twikiFormTable th.twikiFormTableHRow {
	text-align:center;
}
.twikiFormTableFooter {}
.twikiAttachments td,
table.twikiFormTable td {
	padding:3px 6px;
	height:1.5em; /*S1*/
	text-align:left;
	vertical-align:top;
}
.twikiAttachments th.twikiFirstCol,
.twikiAttachments td.twikiFirstCol {
	/* make more width for the icon column */
	width:26px;
	text-align:center;
}
.twikiAttachments caption {
	display:none;
}
table.twikiFormTable th.twikiFormTableHRow a:link,
table.twikiFormTable th.twikiFormTableHRow a:visited {
	text-decoration:none;
}
.twikiAttachments .twistyTrigger .twikiLinkLabel {
	font-size:122%; /* h4 size */
	font-weight:bold;
}
.patternAttachmentCount {
	font-weight:normal;
}
.twikiFormSteps {
	text-align:left;
	border-width:1px 0 0 0;
	border-style:solid;
}
.twikiFormStep {
	line-height:140%;
	padding:1em 40px;
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiFormStep h2,
.twikiFormStep h3,
.twikiFormStep h4 {
	border:none;
	margin:0;
	padding:0;
	background:none;
}
.twikiFormStep h2 {
	font-size:130%;
	font-weight:bold;
}
.twikiFormStep h3 {
	font-size:115%;
	font-weight:bold;
}
.twikiFormStep h4 {
	font-size:104%;
	font-weight:bold;
}
.twikiFormStep p {
	margin:.35em 0;
}
.twikiFormStep blockquote {
	margin-left:1em;
	padding-top:.25em;
	padding-bottom:.25em;
}
.twikiActionFormStepSign {
	position:absolute;
	font-size:104%;
	margin-left:-20px; /* half of S5 */
	margin-top:-.15em;
}
.twikiToc {
	margin:1em 0;
	padding:.3em 0 .6em 0;
}
.twikiToc ul {
	list-style:none;
	padding:0 0 0 .5em;
	margin:0;
}
.twikiToc li {
	margin-left:1em;
	padding-left:1em;
	background-repeat:no-repeat;
	background-position:0 .5em;
}
.twikiToc .twikiTocTitle {
	margin:0;
	padding:0;
	font-weight:bold;
}

.twikiSmall {
	font-size:86%; /*S3*/
	line-height:125%;
}
.twikiSmallish {
	font-size:94%; /*S2*/
	line-height:125%;
}
.twikiNew {}
.twikiSummary {
	font-size:86%; /*S3*/
	line-height:110%;
}
.twikiEmulatedLink {
	text-decoration:underline;
}
.twikiPageForm table {
	border-width:1px;
	border-style:solid;
}
.twikiPageForm table {
	width:100%;
}
.twikiPageForm th,
.twikiPageForm td {
	border:0;
	padding:.5em 1em;
}
.twikiPageForm td {}
.twikiPageForm td.first {
	padding-top:1em;
}
.twikiBroadcastMessage,
.twikiNotification {
	padding:.5em 20px; /*S5*/
}
.twikiNotification {
	margin:1em 0;
}
.twikiBroadcastMessage {
	margin:0 0 1.25em 0;
	border-width:1px;
	border-style:solid none;
}
.twikiHelp {
	height:1%; /* for IE */
	padding:1em;
	margin:0 0 -1px 0;
}
.twikiHelp ul {
	margin:0;
	padding-left:20px;
}
.twikiAccessKey {
	text-decoration:none;
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiWebIndent {
	margin:0 0 0 1em;
}
a.twikiLinkInHeaderRight {
	float:right;
	display:block;
	margin:0 0 0 5px;
}
.twikiLinkLabel {}
.twikiImage img {
	padding:3px;
	border-width:1px;
	border-style:solid;
}
.twikiImage a:link,
.twikiImage a:visited {
	background:none;
}
#twikiLogo img {
	margin:0;
	padding:0;
}
.twikiNoBreak {
	white-space:nowrap;
}

/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/

/* LAYOUT ELEMENTS */
/* for specific layout sub-elements see further down */

#patternPage {
	font-family:arial, verdana, sans-serif;
	line-height:1.5em; /*S1*/
	/* change font size here */
	font-size:105%;
}
#patternTopBar {
	border-width:1px;
	border-style:none none solid none;
}
#patternBottomBar {
	border-width:1px 0 0 0;
	border-style:solid;
}
#patternBottomBarContents {}
#patternWebBottomBar {
	font-size:94%; /*S2*/
	line-height:125%;
	text-align:left;
}
#patternLeftBarContents {
	margin:0 0 1em 0;
	padding-right:.5em;
	padding-left:1em;
	 /* bottom padding is set in colors.css for the reflection image */
}

/* top paddings */
#patternMainContents,
#patternBottomBarContents,
#patternLeftBarContents {
	padding-top:1em;
}
.patternNoViewPage #patternMainContents {
	padding-top:1.5em;
}

/* right paddings */
#patternMainContents,
#patternTopBarContents,
#patternBottomBarContents {
	padding-right:2.5em;
}


/* left paddings */
#patternTopBarContents {
	padding-left:1em; /*S6*/
}
#patternMainContents {
	padding-left:2.5em;
}
#patternBottomBarContents {
	padding-left:2.5em;
}

/* bottom paddings */
#patternMainContents,
#patternBottomBarContents {
	padding-bottom:2em;
}

.patternTopic {
	margin:.5em 0 2em 0;
}
.patternViewPage #patternBottomBarContents {
	padding-left:1em; /*S6*/
}
.patternNoViewPage #patternMainContents,
.patternNoViewPage #patternBottomBarContents {
	margin-left:4%;
	margin-right:4%;
}
.patternEditPage #patternMainContents,
.patternEditPage #patternBottomBarContents {
	margin-left:2%;
	margin-right:2%;
}

#patternLeftBarContents {}
#patternLeftBarContents img {
	margin:0 3px 0 0;
	vertical-align:text-bottom;
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	text-decoration:none;
}
#patternLeftBarContents ul {
	padding:0;
	margin:0;
	list-style:none;
}
#patternLeftBarContents h2 {
	border:none;
	background-color:transparent;
}
#patternLeftBarContents .patternLeftBarPersonal,
#patternLeftBarContents .patternWebIndicator {
	padding:0 1em .75em 1em;
	margin:0 -1em .75em -1em; /*S6*/
}
.patternWebIndicator a {
	font-size:1.1em;
	font-weight:bold;
}

#patternLeftBarContents li {
	overflow:hidden;
}
html>body #patternLeftBarContents li { /* Mozilla */
	overflow:visible;
}

/* form options in top bar */
.patternMetaMenu input,
.patternMetaMenu select,
.patternMetaMenu select option {
	margin:0;
}
.patternMetaMenu select option {
	padding:1px 0 0 0;
}
.patternMetaMenu ul {
    padding:0;
    margin:0;
   	list-style:none;
}
.patternMetaMenu ul li {
    padding:0;
	display:inline;
}
.patternMetaMenu ul li .twikiInputField,
.patternMetaMenu ul li .twikiSelect {
	margin:0 0 0 .5em;
}

.patternHomePath a:link,
.patternHomePath a:visited {
	text-decoration:none;
	border-style:none none solid none;
	border-width:1px;
}

.patternToolBar {
}
.patternToolBar .patternButton {
	float:left;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike,
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	display:block;
	border-width:1px;
	border-style:solid;
	padding:.1em .35em;
	margin:-.2em 0 .2em .25em;
	font-weight:bold;
}
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	text-decoration:none;
	outline:none;
}
.patternToolBar .patternButton a:hover,
.patternToolBar .patternButton a:hover {
	border-width:1px;
	border-style:solid;
}
.patternToolBar .patternButton a:active {
	outline:none;
}
.patternToolBar a:hover .twikiAccessKey {
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike {
	text-decoration:none;
}

.patternTopicActions {
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternTopicAction {
	line-height:1.5em;
	padding:.4em 20px; /*S5*/
	border-width:1px 0 0 0;
	border-style:solid;
	height:1%; /* for IE */
}
.patternOopsPage .patternTopicActions,
.patternEditPage .patternTopicActions {
	margin:1em 0 0 0;
}
.patternAttachPage .patternTopicAction,
.patternRenamePage .patternTopicAction {
	padding-left:40px;
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	padding:1px 1px 2px 1px;
}
.patternTopicAction .patternActionButtons a:link,
.patternTopicAction .patternActionButtons a:visited {
	text-decoration:none;
}
.patternTopicAction .patternActionButtons .patternButton s,
.patternTopicAction .patternActionButtons .patternButton strike {
	text-decoration:none;
}
.patternTopicAction .patternSaveOptions {
	margin-top:.5em;
}
.patternTopicAction .patternSaveOptions .patternSaveOptionsContents {
	padding:.2em 0;
}
.patternNoViewPage .patternTopicAction {
	margin-top:-1px;
}
.patternInfo {
	margin:1.5em 0 0 0;
}
.patternHomePath .patternRevInfo {
	font-size:94%;
}
.patternMoved {
	margin:1em 0;
}
.patternMoved i,
.patternMoved em {
	font-style:normal;
}
.patternTopicFooter {
	margin:1em 0 0 0;
}

/* WebSearch, WebSearchAdvanced */
#twikiSearchTable {
	background:none;
	border-bottom:0;
} 
#twikiSearchTable th,
#twikiSearchTable td {
	padding:1em;
	border-width:0 0 1px 0;
	border-style:solid;
} 
#twikiSearchTable th {
	width:20%;
	text-align:right;
}
#twikiSearchTable td {
	width:80%;
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

.patternSearchResults {
	/* no longer used in search.pattern.tmpl, but remains in rename templates */
	margin:0 0 1em 0;
}
.patternSearchResults blockquote {
	margin:1em 0 1em 5em;
}
h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	display:block;
	border-width:0 0 1px 0;
	border-style:solid;
	height:1%; /* or WIN/IE wont draw the backgound */
	font-weight:bold;
}
.patternSearchResults h3 {
	font-size:115%; /* same as twikiFormStep */
	margin:0;
	padding:.5em 40px; /*S5*/
	font-weight:bold;
}
h4.patternSearchResultsHeader {
	font-size:100%;
	padding-top:.3em;
	padding-bottom:.3em;
	font-weight:normal;
}
.patternSearchResult .twikiTopRow {
	padding-top:.2em;
	margin-top:.1em;
}
.patternSearchResult .twikiBottomRow {
	margin-bottom:.1em;
	padding-bottom:.25em;
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternSearchResult .twikiAlert {
	font-weight:bold;
}
.patternSearchResult .twikiSummary .twikiAlert {
	font-weight:normal;
}
.patternSearchResult .twikiNew {
	border-width:1px;
	border-style:solid;
	font-size:86%; /*S3*/
	padding:0 1px;
	font-weight:bold;
}
.patternSearchResults .twikiHelp {
	display:block;
	width:auto;
	padding:.1em 5px;
	margin:1em -5px .35em -5px;
}
.patternSearchResult .twikiSRAuthor {
	width:15%;
	text-align:left;
}
.patternSearchResult .twikiSRRev {
	width:30%;
	text-align:left;
}
.patternSearchResultCount {
	margin:1em 0 3em 0;
}
.patternSearched {
}
.patternSaveHelp {
	line-height:1.5em;
	padding:.5em 20px; /*S5*/
}

/* Search results in book view format */

.patternBookView {
	border-width:0 0 2px 2px;
	border-style:solid;
	/* border color in cssdynamic.pattern.tmpl */
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternBookView .twikiTopRow {
	padding:.25em 5px .15em 5px; /*S4*/
	margin:1em -5px .15em -5px; /*S4*/
}
.patternBookView .twikiBottomRow {
	font-size:100%;
	padding:1em 0 1em 0;
	width:auto;
	border:none;
}

/* pages that are not view */

/* edit.pattern.tmpl */

.patternEditPage .twikiForm {
	margin:1em 0 0 0;
}
.patternEditPage .twikiForm h1,
.patternEditPage .twikiForm h2,
.patternEditPage .twikiForm h3 {
	/* same as twikiFormStep */
	font-size:120%;
	font-weight:bold;
}	
.twikiEditboxStyleMono {
	font-family:"Courier New", courier, monaco, monospace;
}
.twikiEditboxStyleProportional {
	font-family:arial, verdana, sans-serif;
}
.twikiChangeFormButtonHolder {
	float:right;
	margin:.5em 0 -.5em 0;
}
.twikiFormHolder { /* constrains the textarea */
	width:100%;
}
.patternSigLine {
	padding:.25em 20px;
	border-style:none none solid none;
	border-width:1px;
	height:1%; /* for IE */
}
.patternOopsPage .patternTopicActions,
.patternEditPage .patternTopicActions {
	margin:1em 0 0 0;
}
.patternTextareaButton {
	margin:0 0 0 1px;
	display:block;
	cursor:pointer;
	border-style:solid;
	border-width:1px;
}
.patternButtonFontSelector {
	margin:0 8px 0 0;
}

/* preview.pattern.tmpl */

.twikiPreviewArea {
	border-width:1px;
	border-style:solid;
	margin:0 0 2em 0;
	padding:1em;
	height:1%; /* for IE */
}

/* attach.pattern.tmpl */

.patternAttachPage .twikiAttachments table {
	width:auto;
}
.patternAttachPage .twikiAttachments {
	margin-top:0;
}
.patternMoveAttachment {
	margin:.5em 0 0 0;
	text-align:right;
}

/* rdiff.pattern.tmpl */

.patternDiff {
	/* same as patternBookView */
	border-width:0 0 2px 2px;
	border-style:solid;
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternDiff h4.patternSearchResultsHeader {
	padding:.5em;
}
.patternDiffPage .patternRevInfo ul {
	padding:0;
	margin:2em 0 0 0;
	list-style:none;
}
.patternDiffPage .twikiDiffTable {
	margin:2em 0;
}
tr.twikiDiffDebug td {
	border-width:1px;
	border-style:solid;
}
.patternDiffPage td.twikiDiffDebugLeft {
	border-bottom:none;
}
.patternDiffPage .twikiDiffTable th {
	padding:.25em .5em;
}
.patternDiffPage .twikiDiffTable td {
	padding:.25em;
}
.twikiDiffLineNumberHeader {
	padding:.3em 0;
}


/* PatternSkin colors */
/* Generated by AttachContentPlugin from %SYSTEMWEB%.PatternSkinColorSettings */

/* LAYOUT ELEMENTS */

#patternTopBar {
	border-color:#e7e2da;
	background-color:#fefcf7;
}
#patternMain { /* don't set a background here; use patternOuter */ }
#patternOuter {
	background-color:#fff; /* Sets background of center col */
	border-color:#cfcfcf;
}
#patternLeftBar,
#patternWrapper {
	background-color:#f5f9fb;
}
#patternBottomBar {
	border-color:#e7e2da;
}
#patternBottomBarContents,
#patternBottomBarContents a:link,
#patternBottomBarContents a:visited {
	color:#777;
}
#patternBottomBarContents a:hover {
	color:#fff;
}

/* GENERAL HTML ELEMENTS */

html body {
	background-color:#fff;
	color:#000;
}
/* be kind to netscape 4 that doesn't understand inheritance */
body, p, li, ul, ol, dl, dt, dd, acronym, h1, h2, h3, h4, h5, h6 {
	background-color:transparent;
}
hr {
	color:#e7e2da;
	background-color:#e7e2da;
}
pre, code, tt {
	color:#7A4707;
}
blockquote {
	background-color:#f1f6fa;
}
.patternRenamePage blockquote,
.patternPrintPage blockquote {
	border-color:#ddd;
}
blockquote h2 {
	background:none;
}
h1, h2, h3, h4, h5, h6 {
	color:#800;
}
h2 {
	background-color:#fdfaf2;
	border-color:#e7e2da;
}
h3, h4, h5, h6 {
	border-color:#e7e2da;
}
/* to override old Render.pm coded font color style */
.twikiNewLink font {
	color:inherit;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	color:#777;
	border-color:#ddd;
}
.twikiNewLink a:hover sup {
	background-color:#d6000f;
	color:#fff;
	border-color:#d6000f;
}
.twikiNewLink {
	border-color:#ddd;
}
:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	color:#4571d0;
	background-color:transparent;
}
:link:hover,
:visited:hover {
	color:#fff;
	background-color:#d6000f;
	background-image:none;
}
:link:hover img,
:visited:hover img {
	background-color:transparent;
}
.patternTopic a:visited {
	color:#666;
}
.patternTopic a:hover {
	color:#fff;
}
#patternMainContents h1 a:link, #patternMainContents h1 a:visited,
#patternMainContents h2 a:link, #patternMainContents h2 a:visited,
#patternMainContents h3 a:link, #patternMainContents h3 a:visited,
#patternMainContents h4 a:link, #patternMainContents h4 a:visited,
#patternMainContents h5 a:link, #patternMainContents h5 a:visited,
#patternMainContents h6 a:link, #patternMainContents h6 a:visited {
	color:#800;
}
#patternMainContents h1 a:hover,
#patternMainContents h2 a:hover,
#patternMainContents h3 a:hover,
#patternMainContents h4 a:hover,
#patternMainContents h5 a:hover,
#patternMainContents h6 a:hover {
	color:#fff;
}
.patternTopic .twikiUnvisited a:visited {
	color:#4571d0;
}
.patternTopic .twikiUnvisited a:hover {
	color:#fff;
}



/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* TablePlugin */
.twikiTable,
.twikiTable td {
	border-color:#e7e2da;
}
.twikiTable th {
	border-color:#e7e2da #fff;
}
.twikiTable th a:link,
.twikiTable th a:visited,
.twikiTable th a font {
	color:#fff;
}

/* TwistyContrib */
.twistyPlaceholder {
	color:#777;
}
a:hover.twistyTrigger {
	color:#fff;
}

/* TipsContrib */
.tipsOfTheDay {
	background-color:#fff9d1;
}

/* RevCommentPlugin */
.revComment .patternTopicAction {
	background-color:#fefcf6;
}

/*	-----------------------------------------------------------
	Foswiki styles
	-----------------------------------------------------------	*/

.twikiGrayText {
	color:#777;
}
.twikiGrayText a:link,
.twikiGrayText a:visited {
	color:#777;
}
.twikiGrayText a:hover {
	color:#fff;
}

table.twikiFormTable th.twikiFormTableHRow,
table.twikiFormTable td.twikiFormTableRow {
	color:#777;
}
.twikiEditForm {
	color:#000;
}
.twikiEditForm .twikiFormTable,
.twikiEditForm .twikiFormTable th,
.twikiEditForm .twikiFormTable td {
	border-color:#e7e2da;
}
/* use a different table background color mix: no odd/even rows, no white background */
.twikiEditForm .twikiFormTable td  {
	background-color:#f7fafc;
}
.twikiEditForm .twikiFormTable th {
	background-color:#f0f6fb;
}
.patternContent .twikiAttachments,
.patternContent .twikiForm {
	background-color:#fefcf6;
	border-color:#e7e2da;
}
.twikiAttachments table,
table.twikiFormTable {
	border-color:#e7e2da;
	background-color:#fff;
}
.twikiAttachments table {
	background-color:#fff;
}
.twikiAttachments td, 
.twikiAttachments th {
	border-color:#e7e2da;
}
.twikiAttachments .twikiTable th font,
table.twikiFormTable th.twikiFormTableHRow font {
	color:#4571d0;
}

.twikiFormSteps {
	background-color:#f1f6fa;
	border-color:#d9e8ef;
}
.twikiFormStep {
	border-color:#d9e8ef;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	color:#777;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	background-color:transparent;
}
.twikiActionFormStepSign {
	color:#4571d0;
}
.twikiToc .twikiTocTitle {
	color:#777;
}
.twikiBroadcastMessage {
	background-color:#fff9d1;
	border-color:#ffdf4c;
}
.twikiNotification {
	background-color:#fff9d1;
}
.twikiHelp {
	background-color:#fff9d1;
}
.twikiBroadcastMessage b,
.twikiBroadcastMessage strong {
	color:#f00;
}
.twikiAlert,
.twikiAlert code {
	color:#f00;
}
.twikiEmulatedLink {
	color:#4571d0;
}
.twikiPageForm table {
	border-color:#e7e2da;
	background:#fff;
}
.twikiPageForm hr {
	border-color:#cfcfcf;
	background-color:#cfcfcf;
	color:#cfcfcf;
}
.twikiAccessKey {
	color:inherit;
	border-color:#777;
}
a:link .twikiAccessKey,
a:visited .twikiAccessKey {
	color:inherit;
}
a:hover .twikiAccessKey {
	color:inherit;
}
.twikiImage img {
	border-color:#eee;
	background-color:#fff;
}
#patternTopBar .twikiImage img {
	background-color:transparent;
}
.twikiImage a:hover img {
	border-color:#d6000f;
}

/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/
#patternPage {
	background-color:#fff;
}
.patternHomePath a:link,
.patternHomePath a:visited {
	border-color:#ddd;
	color:#666;
}
.patternTop a:hover {
	border:none;
	color:#fff;
}
.patternHomePath .patternRevInfo,
.patternHomePath .patternRevInfo a:link,
.patternHomePath .patternRevInfo a:visited {
	color:#777;
}
.patternHomePath .patternRevInfo a:hover {
	color:#fff;
}

/* Left bar */
#patternLeftBarContents {
	color:#000;
}
#patternLeftBarContents hr {
	color:#d9e8ef;
	background-color:#d9e8ef;
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	color:#555;
}
#patternLeftBarContents a:hover {
	color:#fff;
}
#patternLeftBarContents .patternLeftBarPersonal a:link,
#patternLeftBarContents .patternLeftBarPersonal a:visited {
	color:#4571d0;
}
#patternLeftBarContents .patternLeftBarPersonal a:hover {
	color:#fff;
}

.patternTopicActions {
	border-color:#e7e2da;
	background-color:#fdfaf2;
	color:#777;
}
.patternTopicAction {
	border-color:#e7e2da;
}
.patternTopicAction s,
.patternTopicAction strike {
	color:#aaa;
}
.patternTopicAction .twikiSeparator {
	color:#e7e2da;
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	color:#be000a;
}
.patternActionButtons a:hover {
	color:#fff;
}
.patternTopicAction .twikiAccessKey {
	color:#be000a;
	border-color:#be000a;
}
.patternTopicAction a:hover .twikiAccessKey {
	color:#fff;
}
.patternTopicAction label {
	color:#000;
}
.patternHelpCol {
	color:#777;
}
.patternSigLine {
	color:#777;
}
.patternToolBar a:link .twikiAccessKey,
.patternToolBar a:visited .twikiAccessKey {
	color:inherit;
	border-color:#666;
}
.patternToolBar a:hover .twikiAccessKey {
	background-color:transparent;
	color:inherit;
	border-color:#666;
}
.patternSaveHelp {
	background-color:#fff;
}

/* WebSearch, WebSearchAdvanced */
table#twikiSearchTable {
	border-color:#d9e8ef;
}
table#twikiSearchTable th,
table#twikiSearchTable td {
	background-color:#fff;
	border-color:#d9e8ef;
}
table#twikiSearchTable hr {
	border-color:#d9e8ef;
	background-color:#d9e8ef;
}
table#twikiSearchTable th {
	color:#000;
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	background-color:#fefcf6;
	border-color:#e7e2da;
}
h4.patternSearchResultsHeader {
	color:#000;
}
.patternNoViewPage h4.patternSearchResultsHeader {
	color:#800;
}
.patternSearchResult .twikiBottomRow {
	border-color:#e7e2da;
}
.patternSearchResult .twikiAlert {
	color:#f00;
}
.patternSearchResult .twikiSummary .twikiAlert {
	color:#900;
}
.patternSearchResult .twikiNew {
	background-color:#ECFADC;
	border-color:#049804;
	color:#049804;
}
.patternViewPage .patternSearchResultsBegin {
	border-color:#e7e2da;
}

/* Search results in book view format */

.patternBookView .twikiTopRow {
	background-color:transparent; /* set to WEBBGCOLOR in css.pattern.tmpl */
	color:#777;
}
.patternBookView .twikiBottomRow {
	border-color:#e7e2da;
}
.patternBookView .patternSearchResultCount {
	color:#777;
}

/* edit.pattern.tmpl */

.patternEditPage .patternSigLine {
	background-color:#fefcf6;
	border-color:#e7e2da;
}

/* preview.pattern.tmpl */

.twikiPreviewArea {
	border-color:#f00;
	background-color:#fff;
}

/* rdiff.pattern.tmpl */

.patternDiff {
	border-color:#6b7f93;
}
.patternDiff h4.patternSearchResultsHeader {
	background-color:#6b7f93;
	color:#fff;
}
.patternDiff h4.patternSearchResultsHeader a:link,
.patternDiff h4.patternSearchResultsHeader a:visited {
	color:#fff;
}
tr.twikiDiffDebug td {
	border-color:#e7e2da;
}
.patternDiffPage .twikiDiffTable th {
	background-color:#ccc;
}
/* Changed */
.twikiDiffChangedHeader,
tr.twikiDiffDebug .twikiDiffChangedText,
tr.twikiDiffDebug .twikiDiffChangedText {
	background:#9f9; /* green - do not change */
}
/* Deleted */
.twikiDiffDeletedHeader,
tr.twikiDiffDebug .twikiDiffDeletedMarker,
tr.twikiDiffDebug .twikiDiffDeletedText {
	background-color:#f99; /* red - do not change */
}
/* Added */
.twikiDiffAddedHeader,
tr.twikiDiffDebug .twikiDiffAddedMarker,
tr.twikiDiffDebug .twikiDiffAddedText {
	background-color:#ccf; /* violet - do not change */
}
/* Unchanged */
tr.twikiDiffDebug .twikiDiffUnchangedText {
	color:#777;
}
.twikiDiffUnchangedTextContents { }
.twikiDiffLineNumberHeader {
	background-color:#ccc;
}


/*	----------------------------------------------------------------------- */
/* configure styles */
/*	----------------------------------------------------------------------- */

#twikiPassword,
#twikiPasswordChange {
	width:40em;
	margin:1em auto;
}
#twikiPassword .twikiFormSteps,
#twikiPasswordChange .twikiFormSteps {
	border-width:5px;
}
div.foldableBlock h1,
div.foldableBlock h2,
div.foldableBlock h3,
div.foldableBlock h4,
div.foldableBlock h5,
div.foldableBlock h6 {
	border:0;
	margin-top:0;
	margin-bottom:0;
}
ul {
    margin-top:0;
    margin-bottom:0;
}
.logo {
    margin:1em 0 1.5em 0;
}
.formElem {
    background-color:#e9ecf2;
    margin:0.5em 0;
    padding:0.5em 1em;
}
.blockLinkAttribute {
    margin-left:0.35em;
}
.blockLinkAttribute a:link,
.blockLinkAttribute a:visited {
	text-decoration:none;
}
a.blockLink {
    display:block;
    padding:0.25em 1em;
    border-bottom:1px solid #aaa;
    border-top:1px solid #f2f4f6;
	font-weight:bold;
}
a:link.blockLink,
a:visited.blockLink {
    text-decoration:underline; 
}
a:link:hover.blockLink {
    text-decoration:underline;   
}
a:link.blockLinkOff,
a:visited.blockLinkOff {
    background-color:#f2f4f6;
}
a:link.blockLinkOn,
a:visited.blockLinkOn {
    background-color:#c4cbd6;
	border-bottom-color:#3f4e67;
    border-top-color:#fff;
}
a.blockLink:hover {
	background-color:#c4cbd6;
    color:#3f4e67;
    border-bottom-color:#3f4e67;
    border-top-color:#fff;
}
div.explanation {
	background-color:#fff9d1;
    padding:0.5em 1em;
    margin:0.5em 0;
}
div.specialRemark {
    background-color:#fff;
    border:1px solid #ccc;
    margin:0.5em;
    padding:0.5em 1em;
}
div.options {
    margin:1em 0;
}
div.options div.optionHeader {
    padding:0.25em 1em;
    background-color:#666;
    color:white;
    font-weight:bold;
}
div.options div.optionHeader a {
    border-width:2px;
    border-style:solid;
    border-color:#eee #999 #999 #eee;
    background-color:#eee;
	padding:0 .5em;
	text-decoration:none;
}
div.options div.optionHeader a:link:hover,
div.options div.optionHeader a:visited:hover {
    background-color:#b4d5ff; /* King's blue */
	text-decoration:none;
	color:#333;
}
div.options .twikiSmall {
    margin-left:0.5em;
    color:#bbb;
}
div.foldableBlock {
    border-bottom:1px solid #ccc;
    border-left:1px solid #ddd;
    border-right:1px solid #ddd;
    height:auto;
    width:auto;
    overflow:auto;
}
.foldableBlockOpen {
    display:block;
}
.foldableBlockClosed {
    display:block;
}
div.foldableBlock td {
    padding:0.5em 1em;
    border-top:1px solid #ccc;
    vertical-align:middle;
    line-height:1.2em;
}
div.foldableBlock td.info {
	border-width:6px;
}
.info {
    color:#666; /*T7*/ /* gray */
    background-color:#f8fbfc;
}
.firstInfo {
    color:#000;
    background-color:#fff;
}

.warn {
    color:#f60; /* orange */
    background-color:#FFE8D9; /* light orange */
    border-bottom:1px solid #f60;
}
a.info,
a.warn,
a.error {
	text-decoration:none;
}
.error {
    color:#f00; /*T9*/ /*red*/
    background-color:#FFD9D9; /* pink */
    border-bottom:1px solid #f00;
}
.mandatory,
.mandatory input {
    color:green;
    background-color:#ECFADC;
    font-weight: bold;
}
.mandatory {
    border-bottom:1px solid green;
}
.mandatory input {
    font-weight:normal;
}
.docdata {
    padding-top: 1ex;
    vertical-align: top;
}
.keydata {
    font-weight: bold;
    background-color:#F0F0F0;
    vertical-align: top;
}
.subHead {
    font-weight: bold;
    font-style: italic;
}
.firstCol {
    width: 30%;
    font-weight: bold;
    vertical-align: top;
}
.secondCol {
}
.hiddenRow {
    display:none;
}
