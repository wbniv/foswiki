/*
 * AS3 Syntax
 * @author Mark Walters
 * http://www.digitalflipbook.com
*/

dp.sh.Brushes.AS3 = function()
{
	var definitions =	'class interface package';
	
	var keywords =	'Array Boolean Date decodeURI decodeURIComponent encodeURI encodeURIComponent escape ' +
					'int isFinite isNaN isXMLName Number Object parseFloat parseInt ' +
					'String trace uint unescape XML XMLList ' + //global functions
					
					'Infinity -Infinity NaN undefined ' + //global constants
					
					'as delete instanceof is new typeof ' + //operators
					
					'break case catch continue default do each else finally for if in ' +
					'label return super switch throw try while with ' + //statements
					
					'dynamic final internal native override private protected public static ' + //attributes
					
					'...rest const extends function get implements namespace set ' + //definitions
					
					'import include use ' + //directives
					
					'AS3 flash_proxy object_proxy ' + //namespaces
					
					'false null this true ' + //expressions
					
					'void Null'; //types
	
	this.regexList = [
		{ regex: dp.sh.RegexLib.SingleLineCComments,				css: 'comment' },			// one line comments
		{ regex: dp.sh.RegexLib.MultiLineCComments,					css: 'blockcomment' },		// multiline comments
		{ regex: dp.sh.RegexLib.DoubleQuotedString,					css: 'string' },			// double quoted strings
		{ regex: dp.sh.RegexLib.SingleQuotedString,					css: 'string' },			// single quoted strings
		{ regex: new RegExp('^\\s*#.*', 'gm'),						css: 'preprocessor' },		// preprocessor tags like #region and #endregion
		{ regex: new RegExp(this.GetKeywords(definitions), 'gm'),	css: 'definition' },		// definitions
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),		css: 'keyword' },			// keywords
		{ regex: new RegExp('var', 'gm'),							css: 'variable' }			// variable
		];

	this.CssClass = 'dp-as';
	this.Style =	'.dp-as .comment { color: #009900; font-style: italic; }' +
					'.dp-as .blockcomment { color: #3f5fbf; }' +
					'.dp-as .string { color: #990000; }' +
					'.dp-as .preprocessor { color: #0033ff; }' +
					'.dp-as .definition { color: #9900cc; font-weight: bold; }' +
					'.dp-as .keyword { color: #0033ff; }' +
					'.dp-as .variable { color: #6699cc; font-weight: bold; }';
}

dp.sh.Brushes.AS3.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.AS3.Aliases	= ['as', 'actionscript', 'ActionScript', 'as3', 'AS3'];
