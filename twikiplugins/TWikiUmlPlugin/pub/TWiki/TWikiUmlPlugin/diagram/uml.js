/*
AJAX UML diagram editor

Copyright (C) 2007 Carlos Manzanares, carlos.manzanares@gmail.com

For licensing info read LICENSE file in the distribution root.
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

As per the GPL, removal of this notice is prohibited.
*/

// TODO: (I) provide own href
// TODO: (I) add send to forward, send to backward
// TODO: (I) add interface connector
// TODO: (N) add autofit
// TODO: (N) add editing of colors
// TODO: (N) generate gif
// TODO: (N) add help
// TODO: (N) make parsing async. and show progress bar
// TODO: bug: grid does not work for connector

dojo.provide("diagram.uml");

dojo.require("diagram.common");
dojo.require("diagram.editor");
dojo.require("diagram.xmi");
dojo.require("dojo.gfx.shape");

dojo.declare("diagram.uml.Toolbar", diagram.SelectionListener, {
	editor: null,
	selection: null,
	
	initializer: function(container, editor, hasImportButton) {
		this.xmiHandler = new diagram.xmi.Handler();
		
		this.editor = editor;
		this.editor.addSelectionListener(this);

		var tc = dojo.widget.createWidget("ToolbarContainer");
		container.appendChild(tc.domNode);
		
		var tb = dojo.widget.createWidget("Toolbar");
		tc.addChild(tb);
		
		this.editableButton = tb.addChild(
			dojo.uri.moduleUri("diagram", "buttons/edit.gif"), 
			null, {toggleItem: true});
		this.editableButton.setSelected(this.editor.isEditable());
		dojo.event.connect(this.editableButton, 'onSelect', this, this.enableEdit);
		dojo.event.connect(this.editableButton, 'onDeselect', this, this.disableEdit);
		
		tb.addChild("|");
		
		if (hasImportButton) {
			this.xmiImportButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/load.gif"));
			dojo.event.connect(this.xmiImportButton, 'onClick', this, this.xmiImport);
		}

		this.xmiExportButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/save.gif"));
		dojo.event.connect(this.xmiExportButton, 'onClick', this, this.xmiExport);

		tb.addChild("|");
		
		this.addPackageButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/addPackage.gif"));
		dojo.event.connect(this.addPackageButton, 'onClick', this, this.addPackage);
		
		this.addClassButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/addClass.gif"));
		dojo.event.connect(this.addClassButton, 'onClick', this, this.addClass);

		tb.addChild("|");
		
		for(x in diagram.uml.connectorEnum) {
			this[x] = tb.addChild(dojo.uri.moduleUri("diagram", diagram.uml.connectorEnum[x].gif));
			this[x].setEnabled(false);
			this[x].connector = diagram.uml.connectorEnum[x];
			dojo.event.connect(this[x], 'onClick', this, this.addConnector);
		}

		tb.addChild("|");
		
		this.editButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/properties.gif"));
		this.editButton.setEnabled(false);
		dojo.event.connect(this.editButton, 'onClick', this, this.edit);
		
		this.removeButton = tb.addChild(dojo.uri.moduleUri("diagram", "buttons/delete.gif"));
		this.removeButton.setEnabled(false);
		dojo.event.connect(this.removeButton, 'onClick', this, this.remove);
		
		tb.addChild("|");
		
		this.gridButton = tb.addChild(
			dojo.uri.moduleUri("diagram", "buttons/grid.gif"), 
			null, {toggleItem: true});
		dojo.event.connect(this.gridButton, 'onSelect', this, this.enableGrid);
		dojo.event.connect(this.gridButton, 'onDeselect', this, this.disableGrid);
		
		
		this.selectionChanged([]);
	},
	
	xmiExport: function(event) {
	},
	
	xmiImport: function(event) {
	},
	
	addClass: function(event) {
		diagram.uml.addClass(
			this.editor, "MyClass", {x: 10, y: 10, width: 100, height: 50});
	},
	
	addPackage: function(event) {
		diagram.uml.addPackage(
			this.editor, "MyPackage", {x: 10, y: 10, width: 100, height: 50});
	},
	
	addConnector: function(event) {
		if (this.selection.length == 2) {
			var srcShape = this.selection[0].getShape();
			var tgtShape = this.selection[1].getShape();
			
			diagram.uml.addConnector(
				this.editor, event.connector, srcShape, tgtShape);
		}
	},
	
	edit: function(event) {
		var s = dojo.html.getScroll();
		var cursor = {x: s.left + 10, y: s.top + 10}; 
		if (this.selection.length == 1) {
			this.selection[0].getShape().edit(cursor);
		}
	},
	
	remove: function(event) {
		var localSelection = Array();
		for(i = 0; i < this.selection.length; i++) {
			localSelection[i] = this.selection[i];
		}
		
		for(x in localSelection) {
			var shape = localSelection[x].getShape();
			this.editor.unregisterShape(shape);
		}
	},
	
	enableGrid: function(event) {
		this.editor.setGrid(10);
	},

	disableGrid: function(event) {
		this.editor.setGrid(null);
	},

	enableEdit: function(event) {
		this.editor.setEditable(true);
	},

	disableEdit: function(event) {
		this.editor.setEditable(false);
		this.xmiExport(event);
	},
	
	selectionChanged: function(newSelection) {
		this.selection = newSelection;
		
		for(x in diagram.uml.connectorEnum) {
			this[x].setEnabled(newSelection.length == 2);
		}
		
		if (this.xmiImportButton) {
			this.xmiImportButton.setEnabled(this.editor.isEditable());
		}
		this.xmiExportButton.setEnabled(this.editor.isEditable());
		this.addClassButton.setEnabled(this.editor.isEditable());
		this.addPackageButton.setEnabled(this.editor.isEditable());
		this.editButton.setEnabled(this.editor.isEditable() && newSelection.length == 1);
		this.removeButton.setEnabled(this.editor.isEditable() && newSelection.length > 0);
	}
});

diagram.uml.addClass = function(editor, className, rect) {
	// summary: adds an UML class to an editor
	// editor: diagram.Editor: the editor where the UML class is added
	// className: name of the class
	// rect: dojo.gfx.Rect: the dimensions of the UML class
	var c = new diagram.uml.Class(
		editor.getSurface(), className, rect, editor.isEditable());

	editor.registerShape(c);

	return c;	// diagram.uml.Class
};

diagram.uml.addPackage = function(editor, packageName, rect) {
	// summary: adds an UML package to an editor
	// editor: diagram.Editor: the editor where the UML package is added
	// packageName: name of the package
	// rect: dojo.gfx.Rect: the dimensions of the UML package
	
	var p = new diagram.uml.Package(
		editor.getSurface(), packageName, rect, editor.isEditable());

	editor.registerShape(p);

	return p;	// diagram.uml.Package
};

diagram.uml.addConnector = function(editor, connectorType, src, tgt) {
	// summary: adds an UML connector to an editor
	// editor: diagram.Editor: the editor where the UML class is added
	var c = diagram.addConnector(
		diagram.uml.Connector, 
		editor, 
		src, connectorType.srcArrow, 
		tgt, connectorType.tgtArrow);

	c.setType(connectorType);
	
	return c;
};

diagram.uml.addConnectorPosBias = function(
	editor, connectorType, 
	src, srcPos, srcBias, tgt, tgtPos, tgtBias) {
	// summary: adds an UML connector to an editor
	// editor: diagram.Editor: the editor where the UML class is added
	var c = diagram.addConnector(
		diagram.uml.Connector, 
		editor, 
		src, srcPos, srcBias, connectorType.srcArrow, 
		tgt, tgtPos, tgtBias, connectorType.tgtArrow);

	c.setType(connectorType);
	
	return c;
};


dojo.lang.mixin(diagram.uml, {
	generalizationArrow: new diagram.ConnectorArrow(
		[{x: 0, y: 0}, {x: 10, y: -10}, {x: 10, y: 10}, {x: 0, y: 0}],
		new dojo.gfx.color.Color(240, 240, 240, 1),
		{color: new dojo.gfx.color.Color(50, 120, 255, 1), width: 1}),
	aggregationArrow: new diagram.ConnectorArrow(
		[{x: 0, y: 0}, {x: 10, y: -5}, {x: 20, y: 0}, {x: 10, y: 5}, {x: 0, y: 0}],
		new dojo.gfx.color.Color(240, 240, 240, 1),
		{color: new dojo.gfx.color.Color(50, 120, 255, 1), width: 1}),
	compositionArrow: new diagram.ConnectorArrow(
		[{x: 0, y: 0}, {x: 10, y: -5}, {x: 20, y: 0}, {x: 10, y: 5}, {x: 0, y: 0}],
		new dojo.gfx.color.Color(50, 120, 255, 1),
		{color: new dojo.gfx.color.Color(50, 120, 255, 1), width: 1}),
	dependencyArrow: new diagram.ConnectorArrow(
		[{x: 0, y: 0}, {x: 10, y: -5}, {x: 0, y: 0}, {x: 10, y: 5}],
		new dojo.gfx.color.Color(50, 120, 255, 1),
		{color: new dojo.gfx.color.Color(50, 120, 255, 1), width: 1})
});

dojo.lang.mixin(diagram.uml, {
	generalization: {name: "Generalization", srcArrow: diagram.uml.generalizationArrow, tgtArrow: null, gif: "buttons/addGeneralization.gif"}, 
	aggregation: {name: "Aggregation", srcArrow: diagram.uml.aggregationArrow, tgtArrow: null, gif: "buttons/addAggregation.gif"},
	directedAggregation: {name: "Directed Aggregation",srcArrow: diagram.uml.aggregationArrow, tgtArrow: diagram.uml.dependencyArrow, gif: "buttons/addDirectedAggregation.gif"},
	composition: {name: "Composition",srcArrow: diagram.uml.compositionArrow, tgtArrow: null, gif: "buttons/addComposition.gif"},
	directedComposition: {name: "Directed Composition",srcArrow: diagram.uml.compositionArrow, tgtArrow: diagram.uml.dependencyArrow, gif: "buttons/addDirectedComposition.gif"},
	association: {name: "Association",srcArrow: null, tgtArrow: null, gif: "buttons/addAssociation.gif"},
	directedAssociation: {name: "Directed Association",srcArrow: null, tgtArrow: diagram.uml.dependencyArrow, gif: "buttons/addDirectedAssociation.gif"}
});

dojo.lang.mixin(diagram.uml, {
	connectorEnum: [diagram.uml.generalization, diagram.uml.aggregation, diagram.uml.directedAggregation, diagram.uml.composition, diagram.uml.directedComposition, diagram.uml.association, diagram.uml.directedAssociation]
});

dojo.declare("diagram.uml.Connector", diagram.Connector, {
	// summary: an UML connector

	type: null,

	fillColor: new dojo.gfx.color.Color(50, 120, 255, 1),
	strokeColor: new dojo.gfx.color.Color(50, 120, 255, 1),
 	strokeWidth: 1,
	stroke: null,
	
	sourceText: "",
	sourceLabel: null,
	
	centerText: "",
	centerLabel: null,

	targetText: "",
	targetLabel: null,
	
 	textColor: new dojo.gfx.color.Color(0, 0, 0, 1),
 	textFontProperties: {
 		textAlign: "center", fontFamily: "verdana", fontSize: "10px", 
 		fontWeight: "normal", overflow: "visible", whiteSpace: "pre", 
 		cursor: "default"},

	initializer: function(
		surface,
		src, srcPos, srcBias, srcConnectorArrow,
		tgt, tgtPos, tgtBias, tgtConnectorArrow,
		editable) {
		// summary: creates an UML connector
		// src: diagram.Shape: the source shape
		// srcPos: 'north', "south", "east", "west": side of the bounding
		//	box of the given source shape
		// srcBias: a number from 0 to 1 that indicates the bias from one side
		//  to the other of the side of the bounding box of the given source 
		//  shape
		// srcConnectorArrow: diagram.ConnectorArrow: the connector arrow
		//	used in the source side of the connector
		// tgt: diagram.Shape: the target shape
		// tgtPos: 'north', "south", "east", "west": side of the bounding
		//	box of the given target shape
		// tgtBias: a number from 0 to 1 that indicates the bias from one side
		//  to the other of the side of the bounding box of the given target 
		//  shape
		// tgtConnectorArrow: diagram.ConnectorArrow: the connector arrow
		//	used in the target side of the connector
		// editable: whether the association attributes (e.g.: class name) 
		//	are editable
		
		this.surface = surface;	
	
		this.setEditable(editable);
		
		this.stroke = {
			color: this.strokeColor, 
			width: this.strokeWidth};
			
		this.setSource(src, srcPos, srcBias);
		this.setTarget(tgt, tgtPos, tgtBias);
		
		this.polyline = surface.createPolyline(
			[this.getSourcePoint(), this.getTargetPoint()]);
		this.polyline.setStroke(this.stroke);
		
		this.setSrcConnectorArrow(srcConnectorArrow);
		this.setTgtConnectorArrow(tgtConnectorArrow);
		
		this.polylineSelection = surface.createPolyline(
			[this.getSourcePoint(), this.getTargetPoint()]);
		this.polylineSelection.setStroke({color: [255, 255, 255, 0.01], width: 4});
		this.polylineSelection.getEventSource().style.cursor = "pointer";
		
		this.sourceLabel = new diagram.Label(
			this.surface, 
			this.sourceText, 
			this._getSourceTextRect(), 
			this.textColor, 
			this.textFontProperties);
			
		this.centerLabel = new diagram.Label(
			this.surface, 
			this.centerText, 
			this._getCenterTextRect(), 
			this.textColor, 
			this.textFontProperties);

		this.targetLabel = new diagram.Label(
			this.surface, 
			this.targetText, 
			this._getTargetTextRect(), 
			this.textColor, 
			this.textFontProperties);
	},
	
	setType: function(type) {
		this.type = type;
		this.setSrcConnectorArrow(type.srcArrow);
		this.setTgtConnectorArrow(type.tgtArrow);
	},
	
	setSrcConnectorArrow: function(srcConnectorArrow) {
		this.srcConnectorArrow = srcConnectorArrow;
		if (this.srcConnectorArrowShape) {
			this.surface.remove(this.srcConnectorArrowShape);
		}
		
		if (srcConnectorArrow != null) {
			this.srcConnectorArrowShape = this.surface.createPolyline(
				srcConnectorArrow.shapePoints);
			this.srcConnectorArrowShape.setStroke(
				srcConnectorArrow.stroke);
			this.srcConnectorArrowShape.setFill(
				srcConnectorArrow.fillColor);
			this.srcConnectorArrowShape.setTransform(
				this.getSourceRotationTransform());
			this.srcConnectorArrowShape.applyTransform(
				{dx: this.getSourcePoint().x, dy: this.getSourcePoint().y})
		}
	},
	
	setTgtConnectorArrow: function(tgtConnectorArrow) {
		this.tgtConnectorArrow = tgtConnectorArrow;
		if (this.tgtConnectorArrowShape) {
			this.surface.remove(this.tgtConnectorArrowShape);
		}
		
		if (tgtConnectorArrow != null) {
			this.tgtConnectorArrowShape = this.surface.createPolyline(
				tgtConnectorArrow.shapePoints);
			this.tgtConnectorArrowShape.setStroke(
				tgtConnectorArrow.stroke);
			this.tgtConnectorArrowShape.setFill(
				tgtConnectorArrow.fillColor);
			this.tgtConnectorArrowShape.setTransform(
				this.getTargetRotationTransform());
			this.tgtConnectorArrowShape.applyTransform(
				{dx: this.getTargetPoint().x, dy: this.getTargetPoint().y})
		}
	},
	
	createManipulator: function() {
		return new diagram.ConnectorManipulator(
			this.surface, this);	// diagram.ConnectorManipulator
	},
	
	edit: function(cursorPosition) {
		new diagram.uml.ConnectorEditor(this, cursorPosition);
	},	
	
	getHRef: function() {
		return this.centerText;
	},
	
	setSourceText: function(text) {
		this.sourceText = text;
		this.sourceLabel.setText(text);
		this.updatePosition();
	},

	setCenterText: function(text) {
		this.centerText = text;
		this.centerLabel.setText(text);
		this.updatePosition();
	},
	
	setTargetText: function(text) {
		this.targetText = text;
		this.targetLabel.setText(text);
		this.updatePosition();
	},

	remove: function() {
		diagram.uml.Connector.superclass.remove.apply(this, []);
		
		this.setSrcConnectorArrow(null);
		this.setTgtConnectorArrow(null);
		this.surface.remove(this.polyline);
		this.surface.remove(this.polylineSelection);
		
		this.sourceLabel.remove();
		this.centerLabel.remove();
		this.targetLabel.remove();
	},
	
	getNode: function() {
		// summary: returns the current DOM Node or null
		return this.polyline.getNode(); // Node
	},
	
	getEventSource: function() {
		// summary: returns a Node, which is used as 
		//	a source of events for this shape
		return this.polylineSelection.getEventSource();	// Node
	},

	getSourceRotationTransform: function() {
		return dojo.gfx.matrix.rotategAt(
			diagram.getAngle(this.getSourcePoint(), this.getTargetPoint()), 
			this.getSourcePoint());
	},
	
	getTargetRotationTransform: function() {
		return dojo.gfx.matrix.rotategAt(
			diagram.getAngle(this.getTargetPoint(), this.getSourcePoint()), 
			this.getTargetPoint());
	},

	updatePosition: function() {
		this.polyline.setShape(
			[this.getSourcePoint(), this.getTargetPoint()]);
		this.polyline.setStroke(this.stroke);
			
		this.polylineSelection.setShape(
			[this.getSourcePoint(), this.getTargetPoint()]);
		this.polylineSelection.setStroke(
			{color: [255, 255, 255, 0.01], width: 4});
			
		if (this.srcConnectorArrowShape != null) {
			this.srcConnectorArrowShape.setTransform(
				this.getSourceRotationTransform());
			this.srcConnectorArrowShape.applyTransform(
				{dx: this.getSourcePoint().x, dy: this.getSourcePoint().y})
		}
		
		if (this.tgtConnectorArrowShape != null) {
			this.tgtConnectorArrowShape.setTransform(
				this.getTargetRotationTransform());
			this.tgtConnectorArrowShape.applyTransform(
				{dx: this.getTargetPoint().x, dy: this.getTargetPoint().y})
		}
		
		this.sourceLabel.setRect(this._getSourceTextRect());
		this.centerLabel.setRect(this._getCenterTextRect());
		this.targetLabel.setRect(this._getTargetTextRect());
	},
	
	_getSourceTextRect: function() {
		var srcP = this.getSourcePoint();
		var tgtP = this.getTargetPoint();
		var diff = {x: tgtP.x - srcP.x, y: tgtP.y - srcP.y};
		
		var diffL = Math.sqrt( diff.x*diff.x + diff.y*diff.y);
		var p = {x: diff.x/diffL*10 + srcP.x, y: diff.y/diffL*10 + srcP.y};
		
		
		return this._getTextRect(this.sourceText, p, this.sourcePosition);
	},
	
	_getCenterTextRect: function() {
		var rect = diagram.getRect(this.centerText, this.textFontProperties);
		
		var srcP = this.getSourcePoint();
		var tgtP = this.getTargetPoint();
		var diff = {x: tgtP.x - srcP.x, y: tgtP.y - srcP.y};

		var p = {x: diff.x/2 + srcP.x, y: diff.y/2 + srcP.y};
		
		return {x: p.x + 10, y: p.y + 5, height: rect.height, width: rect.width};
	},

	_getTargetTextRect: function() {
		var srcP = this.getSourcePoint();
		var tgtP = this.getTargetPoint();
		var diff = {x: srcP.x - tgtP.x, y: srcP.y - tgtP.y};
		
		var diffL = Math.sqrt( diff.x*diff.x + diff.y*diff.y);
		var p = {x: diff.x/diffL*10 + tgtP.x, y: diff.y/diffL*10 + tgtP.y};
		
		
		return this._getTextRect(this.targetText, p, this.targetPosition);
	},
	
	_getTextRect: function(text, p, position) {
		var rect = diagram.getRect(text, this.textFontProperties);
		
		if (position == "north") {
			return {x: p.x + 10, y: p.y - rect.height, height: rect.height, width: rect.width};
		} else if (position == "south") {
			return {x: p.x + 10, y: p.y, height: rect.height, width: rect.width};
		} else if (position == "east") {
			return {x: p.x + 10, y: p.y - rect.height - 3, height: rect.height, width: rect.width};
		} else if (position == "west") {
			return {x: p.x - rect.width, y: p.y + 5, height: rect.height, width: rect.width};
		}
	}
});

dojo.declare("diagram.uml.AttributesTableDiv", null, {
	parentNode: null,
	tableDiv: null,
	
	initializer: function(parentNode, rect, textColor, fontProperties, data) {

		this.parentNode = parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}
		
		this.tableDiv = document.createElement("div");
		
		if (rect.x != null) {
			this.tableDiv.style.position = "absolute";
		}
		if (textColor != null) {
			this.tableDiv.style.color = textColor.toCss();
		}

		for(var x in fontProperties) {
			this.tableDiv.style[x] = fontProperties[x];
		}
		
		parentNode.appendChild(this.tableDiv);
		
		this.setData(data);
		this.setRect(rect);
	},
	
	setRect: function(rect) {
		if (rect.y != null) {
			this.tableDiv.style.top = rect.y + "px";
		}
		if (rect.x != null) {
			this.tableDiv.style.left = rect.x + "px";
		}
		
		with(this.tableDiv.style) {
			width = rect.width + "px";
			height = rect.height + "px";
		}
	},
	
	setData: function(data) {
		var html = "";		
		
		for(var i = 0; i < data.length; i++) {
			html += data[i]["Visibility"];
			html += data[i]["Name"];
			
			if (data[i]["DefaultValue"]) {
				html += " = " + data[i]["DefaultValue"];
			}
			
			html += "<br/>";
		}
		
		this.tableDiv.innerHTML = html;
		
		this.data = data;
	},
	
	remove: function() {
		this.parentNode.removeChild(this.tableDiv);
	}
});

dojo.declare("diagram.uml.OperationsTableDiv", null, {
	parentNode: null,
	tableDiv: null,
	
	initializer: function(parentNode, rect, textColor, fontProperties, data) {

		this.parentNode = parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}

		this.tableDiv = document.createElement("div");
		
		if (rect.x != null) {
			this.tableDiv.style.position = "absolute";
		}
		if (textColor != null) {
			this.tableDiv.style.color = textColor.toCss();
		}

		for(var x in fontProperties) {
			this.tableDiv.style[x] = fontProperties[x];
		}
		
		parentNode.appendChild(this.tableDiv);
		
		this.setData(data);
		this.setRect(rect);
	},
	
	setRect: function(rect) {
		if (rect.y != null) {
			this.tableDiv.style.top = rect.y + "px";
		}
		if (rect.x != null) {
			this.tableDiv.style.left = rect.x + "px";
		}
		
		with(this.tableDiv.style) {
			width = rect.width + "px";
			height = rect.height + "px";
		}
	},
	
	setData: function(data) {
		var html = "";		
		
		for(var i = 0; i < data.length; i++) {
			if (data[i]["IsStatic"]) {
				html += "<u>";
			}
			if (data[i]["IsAbstract"]) {
				html += "<i>";
			}
			
			html += data[i]["Visibility"];
			html += data[i]["Name"];
			html += "()";
			
			if (data[i]["IsAbstract"]) {
				html += "</i>";
			}
			if (data[i]["IsStatic"]) {
				html += "</u>";
			}
			
			html += "<br/>";
		}
		
		this.tableDiv.innerHTML = html;
		
		this.data = data;
	},
	
	remove: function() {
		this.parentNode.removeChild(this.tableDiv);
	}
});

dojo.lang.mixin(diagram.uml, {
	attributesColumns: [ 
		{field: "Visibility"}, {field: "Name"}, {field: "DefaultValue"}],
	operationsColumns: [ 
		{field: "Visibility"}, {field: "Name"}, {field: "IsAbstract"}, {field: "IsStatic"}]
});

dojo.declare("diagram.uml.Class", diagram.Shape, {
	// summary: an UML class

	// fills, strokes... for the UML class representation
	fillColor: new dojo.gfx.color.Color(240, 240, 240, 1),
	strokeColor: new dojo.gfx.color.Color(50, 120, 255, 1),
 	strokeWidth: 1,
	stroke: null,
 	textColor: new dojo.gfx.color.Color(0, 0, 0, 1),
 	classNameFontProperties: {
 		textAlign: "center", fontFamily: "verdana", fontSize: "15px", 
 		fontWeight: "normal", overflow: "hidden", whiteSpace: "pre",
 		lineHeight: "normal"},
 	attributesFontProperties: {
 		textAlign: "left", fontFamily: "verdana", fontSize: "10px", 
 		fontWeight: "normal", overflow: "hidden", whiteSpace: "pre",
 		lineHeight: "normal"},

	tableProperties: { valueField: "Name" },
		
	className: null,
	attributes: [], 
	operations: [],
	
	initializer: function(surface, className, rect, editable) {
		// summary: creates an UML class
		// surface: dojo.gfx.Surface: the surface where the UML class 
		// 	will be located
		// rect: dojo.gfx.Rect: the dimensions of the UML class
		// editable: whether the class attributes (e.g.: class name) 
		//	are editable

		this.surface = surface;	
		this.className = className;

		this.setEditable(editable);
		
		this.stroke = {
			color: this.strokeColor, 
			width: this.strokeWidth};

		var parentNode = this.surface.rawNode.parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}

		
		this.classRect = surface.createRect(rect);
		this.classRect.setFill(this.fillColor);
		this.classRect.setStroke(this.stroke);
		
		
		this.classLine = surface.createLine(this._getClassLine(rect));
		this.classLine.setStroke(this.stroke);
		
		this.operationsLine = surface.createLine(this._getOperationsLine(rect));
		this.operationsLine.setStroke(this.stroke);
		
		
		this.classNameLabel = new diagram.Label(
			surface, this.className, 
			this._getClassNameLabelRect(rect),
			this.textColor, this.classNameFontProperties);

		this.attributesTableDiv = new diagram.uml.AttributesTableDiv(
			parentNode, this._getAttributesRect(rect),
			this.textColor, this.attributesFontProperties, this.attributes);

		this.operationsTableDiv = new diagram.uml.OperationsTableDiv(
			parentNode, this._getOperationsRect(rect),
			this.textColor, this.attributesFontProperties, this.tableProperties,
			false, diagram.uml.operationsColumns, this.operations);
			
		this.eventSourceBoxDiv = new diagram.BoxDiv(this.surface, rect);
		this.eventSourceBoxDiv.getEventSource().style.cursor = "pointer";
		
		
		// TODO: create tooltip
		/*
		var boxDivId = this.eventSourceBoxDiv.getEventSource().id;
		var tooltipProps = {
			caption: this.className, 
			connectId: boxDivId, 
			showDelay: 1500,
			href: "dojo/tests/widget/test_AccordionContainer.html", 
			cacheContent: false};
		this.tooltip = dojo.widget.createWidget("Tooltip", tooltipProps);
		*/
	},
	
	createManipulator: function() {
		return new diagram.ShapeManipulator(
			this.surface, this);	// diagram.ShapeManipulator
	},
	
	edit: function(cursorPosition) {
		new diagram.uml.ClassEditor(this, cursorPosition);
	},

	getHRef: function() {
		return this.className;
	},
	
	setClassName: function(className) {
		this.className = className;
		this.classNameLabel.setText(className);
	},
	
	setAttributes: function(attributes) {
		this.attributes = attributes;
		this.attributesTableDiv.setData(attributes);
		this._positionElements();
	},
	
	setOperations: function(operations) {
		this.operations = operations;
		this.operationsTableDiv.setData(operations);
		this._positionElements();
	},
	
	remove: function() {
		this.surface.remove(this.classRect);
		this.surface.remove(this.classLine);
		this.surface.remove(this.operationsLine);
		
		this.classNameLabel.remove();
		this.attributesTableDiv.remove();
		this.operationsTableDiv.remove();

		this.eventSourceBoxDiv.remove();
		// TODO: if tooltip remove it!
	},
	
	getEventSource: function() {
		// summary: returns a Node, which is used as 
		//	a source of events for this shape
		return this.eventSourceBoxDiv.getEventSource();
	},
	
	getBoundingBox: function() {
		// summary: returns the bounding box
		//return this.classRect.getBoundingBox(); // dojo.gfx.Rectangle
		
		var bb = this.classRect.getBoundingBox();
		var transform = this.classRect.getTransform();

		if (transform != null) {
			bb = {
				x: bb.x + transform.dx, 
				y: bb.y + transform.dy, 
				width: bb.width, 
				height: bb.height};
		}
		
		return bb;
	},
	
	setBoundingBox: function(newBB, grid) {
		if (newBB.width < 30 || newBB.height < 50) {
			return;
		}
		
		if (grid) {
			newBB.x = diagram.applyGrid(newBB.x, 10);
			newBB.y = diagram.applyGrid(newBB.y, 10);
			newBB.width = diagram.applyGrid(newBB.width, 10);
			newBB.height = diagram.applyGrid(newBB.height, 10);
		}
		
		var bb = this.getBoundingBox();
		
		if (newBB.width == bb.width && newBB.height == bb.height) {
			// if it is only translation then apply it as transformation
			// (IE optimization)
			this.classRect.applyTransform(
				{dx: newBB.x-bb.x, dy: newBB.y-bb.y});
		} else {
			// if there is scaling then set it as new shape
			this.classRect.setShape(newBB);
			this.classRect.setFill(this.fillColor);
			this.classRect.setStroke(this.stroke);
			this.classRect.setTransform(null);
		}
		
		this._positionElements();
	},
	
	getTransform: function(){
		// summary: returns the current transformation matrix or null
		return this.classRect.getTransform();	// dojo.gfx.matrix.Matrix
	},
	
	setTransform: function(matrix) {
		// summary: sets a transformation matrix
		// matrix: dojo.gfx.matrix.Matrix: a matrix or a matrix-like object
		//	(see an argument of dojo.gfx.matrix.Matrix 
		//	constructor for a list of acceptable arguments)
		this.classRect.setTransform(matrix);
		this._positionElements();
		
		return this;		
	},
	
	applyTransform: function(matrix) {
		// summary: a shortcut for dojo.gfx.Shape.applyRight
		// matrix: dojo.gfx.matrix.Matrix: a matrix or a matrix-like object
		//	(see an argument of dojo.gfx.matrix.Matrix 
		//	constructor for a list of acceptable arguments)
		this.classRect.applyTransform(matrix);
		this._positionElements();

		return this;
	},
	
	_positionElements: function() {
		var bb = this.getBoundingBox();
		
		this.classLine.setShape(this._getClassLine(bb));
		this.classLine.setStroke(this.stroke);
		
		this.operationsLine.setShape(this._getOperationsLine(bb));
		this.operationsLine.setStroke(this.stroke);
		
		this.classNameLabel.setRect(this._getClassNameLabelRect(bb));
		this.attributesTableDiv.setRect(this._getAttributesRect(bb));
		this.operationsTableDiv.setRect(this._getOperationsRect(bb));
		
		this.eventSourceBoxDiv.setRect(bb);
	},
	
	_getClassNameLabelRect: function(rect) {
		return {x: rect.x+8, y: rect.y+2, width: rect.width-16, height: 20};
	},
	
	_getClassLine: function(rect) {
		return {
			x1: rect.x, y1: rect.y + 24, 
			x2: rect.x+rect.width, y2: rect.y + 24};
	},
	
	_getOperationsLine: function(rect) {
		var yIncr;
		if (this.attributes.length == 0 && this.operations.length != 0) {
			yIncr = 24 + 10;
		} else if (this.attributes.length != 0 && this.operations.length == 0) {
			yIncr = rect.height - 10;
		} else if (this.attributes.length != 0 && this.operations.length != 0) {
			var height = rect.height - 30;
			var normalizedHeight = height/(this.attributes.length+this.operations.length);
			var finalHeight = normalizedHeight * this.attributes.length + 3;
			if (finalHeight < 5) {
				finalHeight = 5;
			} else if (finalHeight > (height-5)) {
				finalHeight = height - 5;
			}
			yIncr = finalHeight + 24;
		} else {
			yIncr = (rect.height-24)/2 + 24
		}
		
		return {
			x1: rect.x, y1: rect.y + yIncr, 
			x2: rect.x+rect.width, y2: rect.y + yIncr};
	},
	
	_getAttributesRect: function(rect) {
		var clLine = this._getClassLine(rect);
		var opLine = this._getOperationsLine(rect);
		
		return {
			x: clLine.x1+8, y: clLine.y1 + 2, 
			width: clLine.x2-clLine.x1-16, height: opLine.y1-clLine.y1-4};
	},
	
	_getOperationsRect: function(rect) {
		var opLine = this._getOperationsLine(rect);
		
		return {
			x: opLine.x1+8, y: opLine.y1 + 2, 
			width: rect.width-16, height: rect.y+rect.height-opLine.y1-4};
	}
});

dojo.declare("diagram.uml.Package", diagram.Shape, {
	// summary: an UML package

	// fills, strokes... for the UML package representation
	fillColor: new dojo.gfx.color.Color(240, 240, 240, 1),
	strokeColor: new dojo.gfx.color.Color(50, 120, 255, 1),
 	strokeWidth: 1,
	stroke: null,
 	textColor: new dojo.gfx.color.Color(0, 0, 0, 1),
 	packageNameFontProperties: {
 		textAlign: "center", fontFamily: "verdana", fontSize: "15px", 
 		fontWeight: "normal", overflow: "hidden", whiteSpace: "pre"},
		
	packageName: null,
	
	initializer: function(surface, packageName, rect, editable) {
		// summary: creates an UML package
		// surface: dojo.gfx.Surface: the surface where the UML package
		// 	will be located
		// packageName: the package name
		// rect: dojo.gfx.Rect: the dimensions of the UML package
		// editable: whether the package attributes (e.g.: package name) 
		//	are editable

		this.surface = surface;	
		this.packageName = packageName;

		this.setEditable(editable);
		
		this.stroke = {
			color: this.strokeColor, 
			width: this.strokeWidth};

		var parentNode = this.surface.rawNode.parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}

		this.packageRect = surface.createRect(this._getPackageRect(rect));
		this.packageRect.setFill(this.fillColor);
		this.packageRect.setStroke(this.stroke);
		
		this.upperRect = surface.createRect(this._getUpperRect(rect));
		this.upperRect.setFill(this.fillColor);
		this.upperRect.setStroke(this.stroke);
		
		this.packageNameLabel = new diagram.Label(
			surface, this.packageName, 
			this._getPackageNameLabelRect(rect),
			this.textColor, this.packageNameFontProperties);

		this.eventSourceBoxDiv = new diagram.BoxDiv(this.surface, rect);
		this.eventSourceBoxDiv.getEventSource().style.cursor = "pointer";
	},
	
	createManipulator: function() {
		return new diagram.ShapeManipulator(
			this.surface, this);	// diagram.ShapeManipulator
	},
	
	edit: function(cursorPosition) {
		new diagram.uml.PackageEditor(this, cursorPosition);
	},

	getHRef: function() {
		return this.packageName;
	},
	
	setPackageName: function(packageName) {
		this.packageName = packageName;
		this.packageNameLabel.setText(packageName);
	},
	
	remove: function() {
		this.surface.remove(this.packageRect);
		this.surface.remove(this.upperRect);
		
		this.packageNameLabel.remove();

		this.eventSourceBoxDiv.remove();
	},
	
	getEventSource: function() {
		// summary: returns a Node, which is used as 
		//	a source of events for this shape
		return this.eventSourceBoxDiv.getEventSource();
	},
	
	getBoundingBox: function() {
		// summary: returns the bounding box
		// return bounding box // dojo.gfx.Rectangle
		return this.eventSourceBoxDiv.getRect();
	},
	
	setBoundingBox: function(newBB, grid) {
		if (newBB.width < 30 || newBB.height < 50) {
			return;
		}
		
		if (grid) {
			newBB.x = diagram.applyGrid(newBB.x, 10);
			newBB.y = diagram.applyGrid(newBB.y, 10);
			newBB.width = diagram.applyGrid(newBB.width, 10);
			newBB.height = diagram.applyGrid(newBB.height, 10);
		}
		
		this.packageRect.setShape(this._getPackageRect(newBB));
		this.packageRect.setFill(this.fillColor);
		this.packageRect.setStroke(this.stroke);
		this.packageRect.setTransform(null);

		this.upperRect.setShape(this._getUpperRect(newBB));
		this.upperRect.setFill(this.fillColor);
		this.upperRect.setStroke(this.stroke);
		this.upperRect.setTransform(null);
		
		this.packageNameLabel.setRect(this._getPackageNameLabelRect(newBB));
		
		this.eventSourceBoxDiv.setRect(newBB);
	},
	
	_getPackageRect: function(rect) {
		return { 
			x: rect.x, y: rect.y + 20, 
			width: rect.width, height: rect.height - 20};
	},
	
	_getUpperRect: function(rect) {
		return { x: rect.x, y: rect.y, width: rect.width/3, height: 20};
	},
	
	_getPackageNameLabelRect: function(rect) {
		return {x: rect.x+8, y: rect.y+22, width: rect.width-16, height: 20};
	}
});


dojo.declare("diagram.uml.ClassEditor", null, {
	umlClass: null,
	tableProperties: {
		multiple: true, maxSortable: 1, valueField: "Name", 
		templateCssPath: dojo.uri.moduleUri("diagram", "templates/TableEdit.css"), 
		headerClass: "headerClass", tbodyClass: "tbodyClass"}, 

 	fontProperties: {
 		textAlign: "left", fontFamily: "verdana", fontSize: "10px", 
 		fontWeight: "normal", overflow: "auto", whiteSpace: "pre"},
	
	initializer: function(umlClass, cursorPosition) {
		this.umlClass = umlClass;
		this.cursorPosition = cursorPosition;

		var containerDiv = document.createElement("div");
		with(containerDiv.style) {
			position = "absolute";
			top = cursorPosition.y + "px";
			left = cursorPosition.x + "px";
			width = "270px";
			height = "490px";
		}
		document.body.appendChild(containerDiv);
	
		var props = {
			title: "Class properties", 
			executeScripts: true,
			hasShadow: true, 
			displayCloseAction: true, 
			resizable: false};

		this.dialog = dojo.widget.createWidget(
			"FloatingPane", props, containerDiv);

		this.attributes = this._clone(this.umlClass.attributes);
		this.operations = this._clone(this.umlClass.operations);
		
		var contents = [
			{type: "TextField", id: "classNameInput", labelText: "Class name:", defaultValue: this.umlClass.className},
			{type: "Empty"},
			{type: "Label", labelText: "Attributes:"},
			{type: "Table", id: "attributesTable", rect: {height: 120, width: 230}, 
				fontProperties: this.fontProperties, 
				tableProperties: this.tableProperties, 
				columns: diagram.uml.attributesColumns,
				data: this.attributes},
			{type: "AddRemoveButtonRow", id: "attributesButtons"},
			{type: "Empty"},
			{type: "Label", labelText: "Operations:"},
			{type: "Table", id: "operationsTable", rect: {height: 120, width: 230}, 
				fontProperties: this.fontProperties, 
				tableProperties: this.tableProperties, 
				columns: diagram.uml.operationsColumns,
				data: this.operations},
			{type: "AddRemoveButtonRow", id: "operationsButtons"},
			{type: "Empty"},
			{type: "OkApplyCancelButtonRow", id: "dialogButtons", hasApply: true}
			];
		
		var ret = diagram.createDialogContent(contents);

		var table = ret.table;
		var items = ret.items;

		this.dialog.setContent(table);
		
		this.classNameInput = items["classNameInput"];
		this.attributesTable = items["attributesTable"];
		this.operationsTable = items["operationsTable"];
		
		dojo.event.connect(items["attributesButtons"].add, 'onClick', this, this.addAttribute);
		dojo.event.connect(items["attributesButtons"].remove, 'onClick', this, this.removeAttribute);

		dojo.event.connect(items["operationsButtons"].add, 'onClick', this, this.addOperation);
		dojo.event.connect(items["operationsButtons"].remove, 'onClick', this, this.removeOperation);
		
		dojo.event.connect(items["dialogButtons"].ok, 'onClick', this, this.okClick);
		dojo.event.connect(items["dialogButtons"].apply, 'onClick', this, this.applyClick);
		dojo.event.connect(items["dialogButtons"].cancel, 'onClick', this, this.cancelClick);
		
		this.dialog.show();
	},
	
	addAttribute: function() {
		var containerDiv = document.createElement("div");
		with(containerDiv.style) {
			position = "absolute";
			top = (this.cursorPosition.y+100) + "px";
			left = (this.cursorPosition.x+150) + "px";
			width = "270px";
			height = "190px";
		}
		document.body.appendChild(containerDiv);
	
		var props = {
			title: "Attributes properties", 
			executeScripts: true,
			hasShadow: true, 
			displayCloseAction: true, 
			resizable: false};

		var dialog = dojo.widget.createWidget(
			"FloatingPane", props, containerDiv);

		var contents = [
			{type: "ComboBox", id: "visibility", labelText: "Visibility:", options: ["+", "#", "~", "-"], defaultOption: "-"},
			{type: "TextField", id: "name", labelText: "Name:", defaultValue: ""},
			{type: "TextField", id: "defaultValue", labelText: "Default value:", defaultValue: ""},
			{type: "Empty"},
			{type: "OkApplyCancelButtonRow", id: "dialogButtons", hasApply: false}
			];
		
		var ret = diagram.createDialogContent(contents);

		var table = ret.table;
		var items = ret.items;
		
		ret.attributesTable = this.attributesTable;
		ret.okClick = function() {
			var visibility = ret.items["visibility"].getValue();
			var name = ret.items["name"].value;
			var defaultValue = ret.items["defaultValue"].value;
			if (defaultValue == "") {
				defaultValue = undefined;
			}
			
			if (name != "") {
				ret.attributesTable.add({
					"Visibility": visibility, "Name": name, 
					"DefaultValue": defaultValue});
			}
			
			dialog.destroy();
		}
		ret.cancelClick = function() {
			dialog.destroy();
		}

		dojo.event.connect(items["dialogButtons"].ok, 'onClick', ret, ret.okClick);
		dojo.event.connect(items["dialogButtons"].cancel, 'onClick', ret, ret.cancelClick);

		dialog.setContent(table);
		dialog.show();
	},
	
	removeAttribute: function() {
		this.attributesTable.removeSelected();
	},
	
	addOperation: function() {
		var containerDiv = document.createElement("div");
		with(containerDiv.style) {
			position = "absolute";
			top = (this.cursorPosition.y+200) + "px";
			left = (this.cursorPosition.x+150) + "px";
			width = "270px";
			height = "210px";
		}
		document.body.appendChild(containerDiv);
	
		var props = {
			title: "Operations properties", 
			executeScripts: true,
			hasShadow: true, 
			displayCloseAction: true, 
			resizable: false};

		var dialog = dojo.widget.createWidget(
			"FloatingPane", props, containerDiv);

		var contents = [
			{type: "ComboBox", id: "visibility", labelText: "Visibility:", options: ["+", "#", "~", "-"], defaultOption: "+"},
			{type: "TextField", id: "name", labelText: "Name:", defaultValue: ""},
			{type: "ComboBox", id: "isAbstract", labelText: "Is abstract:", options: ["yes", "no"], defaultOption: "no"},
			{type: "ComboBox", id: "isStatic", labelText: "Is static:", options: ["yes", "no"], defaultOption: "no"},
			{type: "Empty"},
			{type: "OkApplyCancelButtonRow", id: "dialogButtons", hasApply: false}
			];
		
		var ret = diagram.createDialogContent(contents);

		var table = ret.table;
		var items = ret.items;
		
		ret.operationsTable = this.operationsTable;
		ret.okClick = function() {
			var visibility = ret.items["visibility"].getValue();
			var name = ret.items["name"].value;
			var isAbstract = ret.items["isAbstract"].getValue();
			if (isAbstract != "yes") {
				isAbstract = undefined;
			} else {
				isAbstract = "Abstract";
			}
			var isStatic = ret.items["isStatic"].getValue();
			if (isStatic != "yes") {
				isStatic = undefined;
			} else {
				isStatic = "Static";
			}
			
			if (name != "") {
				ret.operationsTable.add({
					"Visibility": visibility, "Name": name, 
					"IsAbstract": isAbstract, "IsStatic": isStatic});
			}
			
			dialog.destroy();
		}
		ret.cancelClick = function() {
			dialog.destroy();
		}

		dojo.event.connect(items["dialogButtons"].ok, 'onClick', ret, ret.okClick);
		dojo.event.connect(items["dialogButtons"].cancel, 'onClick', ret, ret.cancelClick);


		dialog.setContent(table);
		dialog.show();
	},

	removeOperation: function() {
		this.operationsTable.removeSelected();
	},
	
	okClick: function() {
		this.applyClick();
		this.dialog.destroy();
	},
	
	applyClick: function() {
		this.umlClass.setClassName(this.classNameInput.value);
		this.umlClass.setAttributes(this._clone(this.attributes));
		this.umlClass.setOperations(this._clone(this.operations));
	},

	cancelClick: function() {
		this.dialog.destroy();
	},
	
	_clone: function(arr) {
		var data = [];
		
		for(var i = 0; i < arr.length; i++) {
			data[i] = arr[i];
		}
		
		return data;
	}
});

dojo.declare("diagram.uml.PackageEditor", null, {
	umlPackage: null,
		
	initializer: function(umlPackage, cursorPosition) {
		this.umlPackage = umlPackage;

		var containerDiv = document.createElement("div");
		with(containerDiv.style) {
			position = "absolute";
			top = cursorPosition.y + "px";
			left = cursorPosition.x + "px";
			width = "280px";
			height = "130px";
		}
		document.body.appendChild(containerDiv);
	
		var props = {
			title: "Package properties", 
			executeScripts: true,
			hasShadow: true, 
			displayCloseAction: true, 
			resizable: false};

		this.dialog = dojo.widget.createWidget(
			"FloatingPane", props, containerDiv);

		var contents = [
			{type: "TextField", id: "packageName", labelText: "Package name:", defaultValue: this.umlPackage.packageName},
			{type: "Empty"},
			{type: "OkApplyCancelButtonRow", id: "dialogButtons", hasApply: true}
			];
		
		var ret = diagram.createDialogContent(contents);

		var table = ret.table;
		var items = ret.items;
		
		this.packageNameInput = items["packageName"];

		dojo.event.connect(items["dialogButtons"].ok, 'onClick', this, this.okClick);
		dojo.event.connect(items["dialogButtons"].apply, 'onClick', this, this.applyClick);
		dojo.event.connect(items["dialogButtons"].cancel, 'onClick', this, this.cancelClick);

		this.dialog.setContent(table);

		this.dialog.show();
	},
	
	okClick: function() {
		this.applyClick();
		this.dialog.destroy();
	},
	
	applyClick: function() {
		this.umlPackage.setPackageName(this.packageNameInput.value);
	},

	cancelClick: function() {
		this.dialog.destroy();
	}
});

dojo.declare("diagram.uml.ConnectorEditor", null, {
	connector: null,
		
	initializer: function(connector, cursorPosition) {
		this.connector = connector;

		var containerDiv = document.createElement("div");
		with(containerDiv.style) {
			position = "absolute";
			top = cursorPosition.y + "px";
			left = cursorPosition.x + "px";
			width = "280px";
			height = "220px";
		}
		document.body.appendChild(containerDiv);
	
		var props = {
			title: "Connector properties", 
			executeScripts: true,
			hasShadow: true, 
			displayCloseAction: true, 
			resizable: false};

		this.dialog = dojo.widget.createWidget(
			"FloatingPane", props, containerDiv);

		var defaultOption;
		for (x in diagram.uml.connectorEnum) {
			if (diagram.uml.connectorEnum[x] == this.connector.type) {
				defaultOption = diagram.uml.connectorEnum[x].name;
			}
		}

		var contents = [
			{type: "ComboBox", id: "connector", labelText: "Connector:", options: this._createOptions(), defaultOption: defaultOption},
			{type: "TextField", id: "sourceText", labelText: "Source text:", defaultValue: this.connector.sourceText},
			{type: "TextField", id: "centerText", labelText: "Center text:", defaultValue: this.connector.centerText},
			{type: "TextField", id: "targetText", labelText: "Target text:", defaultValue: this.connector.targetText},
			{type: "Empty"},
			{type: "OkApplyCancelButtonRow", id: "dialogButtons", hasApply: true}
			];
		
		var ret = diagram.createDialogContent(contents);

		var table = ret.table;
		var items = ret.items;
		
		this.connectorComboBox = items["connector"];
		this.sourceTextInput = items["sourceText"];
		this.centerTextInput = items["centerText"];
		this.targetTextInput = items["targetText"];

		dojo.event.connect(items["dialogButtons"].ok, 'onClick', this, this.okClick);
		dojo.event.connect(items["dialogButtons"].apply, 'onClick', this, this.applyClick);
		dojo.event.connect(items["dialogButtons"].cancel, 'onClick', this, this.cancelClick);

		this.dialog.setContent(table);

		this.dialog.show();
	},
	
	okClick: function() {
		this.applyClick();
		this.dialog.destroy();
	},
	
	applyClick: function() {
		var typeName = this.connectorComboBox.getValue();
		var type = this._getType(typeName);		
		
		this.connector.setType(type);
		
		this.connector.setSourceText(this.sourceTextInput.value);
		this.connector.setCenterText(this.centerTextInput.value);
		this.connector.setTargetText(this.targetTextInput.value);
	},

	cancelClick: function() {
		this.dialog.destroy();
	},
	
	_getType: function(typeName) {
		for(x in diagram.uml.connectorEnum) {
			if (diagram.uml.connectorEnum[x].name == typeName) {
				return diagram.uml.connectorEnum[x];
			}
		}
		
		return null;
	},
	
	_createOptions: function() {
		var options = [];
		var i = 0;
		
		for(x in diagram.uml.connectorEnum) {
			options[i++] = diagram.uml.connectorEnum[x].name;
		}
		
		return options;
	}	
});

