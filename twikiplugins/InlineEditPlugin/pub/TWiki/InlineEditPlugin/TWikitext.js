/*==============================================================================
This Wikiwyg mode supports a textarea editor with toolbar buttons.

COPYRIGHT:

 Sven Dowideit - SvenDowideit@home.org.au

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.TWikitext', 'Wikiwyg.Wikitext');
klass = Wikiwyg.TWikitext;

proto.classtype = 'twikitext';
proto.modeDescription = 'TWikitext';

//TODO: we should make this readonly...
proto.config = {
    supportCamelCaseLinks: true,
    javascriptLocation: null,
    clearRegex: null,
    editHeightMinimum: 10,
    editHeightAdjustment: 1.3,
    markupRules: {
        link: ['bound_phrase', '[[', ']]'],
        bold: ['bound_phrase', '*', '*'],
        code: ['bound_phrase', '<verbatim>', '</verbatim>'],
        italic: ['bound_phrase', '_', '_'],
/*        underline: ['bound_phrase', '_', '_'],	*/
/*        strike: ['bound_phrase', '-', '-'],	*/
        p: ['start_lines', ''],
        pre: ['bound_phrase', '<pre>', '</pre>'],
        h1: ['start_line', '---+'],
        h2: ['start_line', '---++'],
        h3: ['start_line', '---+++'],
        h4: ['start_line', '---++++'],
        h5: ['start_line', '---+++++'],
        h6: ['start_line', '---++++++'],
        ordered: ['start_lines', '   1'],
        unordered: ['start_lines', '   *'],
/*        indent: ['start_lines', '>'],	*/
        hr: ['line_alone', '---'],
        table: ['line_alone', '| A | B | C |\n|   |   |   |\n|   |   |   |\n']
    }
}
