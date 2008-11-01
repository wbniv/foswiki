tinyMCE.importPluginLanguagePack('twikibuttons');

var TWikiButtonsPlugin = {
	getInfo : function() {
		return {
			longname : 'TWiki Buttons Plugin',
			author : 'Crawford Currie',
			authorurl : 'http://c-dot.co.uk',
			infourl : 'http://c-dot.co.uk',
			version : 1
		};
	},

	initInstance : function(inst) {
		//tinyMCE.importCSS(inst.getDoc(),
        //tinyMCE.baseURL + "/plugins/twikibuttons/css/twikibuttons.css");
	},

	getControlHTML : function(cn) {
        var html, formats;
		switch (cn) {
        case "tt":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_tt_desc',
                                         '{$pluginurl}/images/tt.gif',
                                         'twikiTT', true);
        case "colour":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_colour_desc',
                                         '{$pluginurl}/images/colour.gif',
                                         'twikiCOLOUR', true);
        case "attach":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_attach_desc',
                                         '{$pluginurl}/images/attach.gif',
                                         'twikiATTACH', true);
        case "hide":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_hide_desc',
                                         '{$pluginurl}/images/hide.gif',
                                         'twikiHIDE', true);
        case "twikiformat":
            html = '<select id="{$editor_id}_twikiFormatSelect" name="{$editor_id}_twikiFormatSelect" onfocus="tinyMCE.addSelectAccessibility(event, this, window);" onchange="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'twikiFORMAT\',false,this.options[this.selectedIndex].value);" class="mceSelectList">';
            formats = tinyMCE.getParam("twikibuttons_formats");
            // Build format select
            for (var i = 0; i < formats.length; i++) {
                html += '<option value="'+ formats[i].name + '">'
                    + formats[i].name + '</option>';
            }
            html += '</select>';
            
            return html;
		}

		return "";
	},

	execCommand : function(editor_id, element, command,
                           user_interface, value) {
		var em;
        var inst = tinyMCE.getInstanceById(editor_id);

		switch (command) {
        case "twikiCOLOUR":
            var t = inst.selection.getSelectedText();
            if (!(t && t.length > 0 || pe))
                return true;

            template = new Array();
            template['file'] = '../../plugins/twikibuttons/colours.htm';
            template['width'] = 240;
            template['height'] = 140;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "twikiTT":
            inst = tinyMCE.getInstanceById(editor_id);
            elm = inst.getFocusElement();
            var t = inst.selection.getSelectedText();
            var pe = tinyMCE.getParentElement(elm, 'TT');

            if (!(t && t.length > 0 || pe))
                return true;
            var s = inst.selection.getSelectedHTML();
            if (s.length > 0) {
                tinyMCE.execCommand('mceBeginUndoLevel');
                tinyMCE.execInstanceCommand(
                    editor_id, 'mceSetCSSClass', user_interface,
                    "WYSIWYG_TT");
                tinyMCE.execCommand('mceEndUndoLevel');
            }

            return true;

        case "twikiHIDE":
            tinyMCE.execCommand("mceToggleEditor", user_interface, editor_id);
            return true;

        case "twikiATTACH":
            template = new Array();
            template['file'] = '../../plugins/twikibuttons/attach.htm';
            template['width'] = 350;
            template['height'] = 250;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "twikiFORMAT":
            var formats = tinyMCE.getParam("twikibuttons_formats");
            var format = null;
            for (var i = 0; i < formats.length; i++) {
                if (formats[i].name == value) {
                    format = formats[i];
                    break;
                }
            }

            if (format != null) {
                // if None, then remove all the styles that are in the
                // formats
                tinyMCE.execCommand('mceBeginUndoLevel');
                if (format.el != null) {
                    var fmt = format.el;
                    if (fmt.length)
                        fmt = '<' + fmt + '>';
                    tinyMCE.execInstanceCommand(
                        editor_id, 'FormatBlock', user_interface, fmt);
                    if (format.el == '') {
                        elm = inst.getFocusElement();
                        tinyMCE.execCommand(
                            'removeformat', user_interface, elm);
                    }
                }
                if (format.style != null) {
                    // element is additionally styled
                    tinyMCE.execInstanceCommand(
                        editor_id, 'mceSetCSSClass', user_interface,
                        format.style);
                }
                tinyMCE.triggerNodeChange();
            }
            tinyMCE.execCommand('mceEndUndoLevel');
           return true;
		}

		return false;
	},

	handleNodeChange : function(editor_id, node, undo_index,
                                undo_levels, visual_aid, any_selection) {
		var elm = tinyMCE.getParentElement(node);

		if (node == null)
			return;

		if (!any_selection) {
			// Disable the buttons
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonDisabled');
			tinyMCE.switchClass(editor_id + '_colour', 'mceButtonDisabled');
		} else {
			// A selection means the buttons should be active.
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonNormal');
			tinyMCE.switchClass(editor_id + '_colour', 'mceButtonNormal');
		}

		switch (node.nodeName) {
			case "TT":
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonSelected');
            return true;
		}

		var selectElm = document.getElementById(
            editor_id + "_twikiFormatSelect");
        if (selectElm) {
            var formats = tinyMCE.getParam("twikibuttons_formats");
            var puck = -1;
            do {
                for (var i = 0; i < formats.length; i++) {
                    if (!formats[i].el ||
                        formats[i].el == node.nodeName.toLowerCase()) {
                        if (!formats[i].style ||
                            RegExp('\\b' + formats[i].style + '\\b').test(
                                tinyMCE.getAttrib(node, "class"))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal (which
                            // always matches, and is at pos 0)
                            if (puck > 0)
                                break;
                        }
                    }
                }
            } while (puck < 0 && (node = node.parentNode) != null);
            if (puck >= 0) {
                selectElm.selectedIndex = puck;
            }
        }
		return true;
	}
};

tinyMCE.addPlugin("twikibuttons", TWikiButtonsPlugin);