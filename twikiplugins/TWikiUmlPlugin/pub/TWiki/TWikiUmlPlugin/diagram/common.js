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

dojo.provide("diagram.common");

dojo.require("dojo.gfx.*");

diagram.createDialogContent = function(items) {
	var table = document.createElement("table");
	table.style.fontSize = "12px";
	
	var retItems = [];
	var rowCounter = 0;
	for(x in items) {
		if (items[x].type == "TextField") {
		
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);
			cell0.colSpan = 2;
			cell0.appendChild(document.createTextNode(items[x].labelText));
			var cell1 = row.insertCell(1);
			cell1.colSpan = 3;
			var input = document.createElement("input");
			cell1.appendChild(input);
			input.type = "text";
			input.size = 20;
			input.value = items[x].defaultValue;
			
			retItems[items[x].id] = input;
			
		} else if (items[x].type == "Label") {
			
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);
			cell0.colSpan = 2;
			cell0.appendChild(document.createTextNode(items[x].labelText));
			
		} else if (items[x].type == "Empty") {
			
	 		var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);
			cell0.colSpan = 5;
			cell0.innerHTML = '&nbsp;';
			
		} else if (items[x].type == "Table") {
	
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);
			cell0.colSpan = 5;
		
			var tableDiv = new diagram.TableDiv(
				cell0, items[x].rect,
				null, items[x].fontProperties, items[x].tableProperties,
				true, items[x].columns, items[x].data);
			
			retItems[items[x].id] = tableDiv;

		} else if (items[x].type == "OkApplyCancelButtonRow") {
			
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);

			var cell1 = row.insertCell(1);
			cell1.align = "right";
			var okButtonContainer = document.createElement("div");
			cell1.appendChild(okButtonContainer);
			var okButton = dojo.widget.createWidget(
				"Button", {caption: "OK"}, okButtonContainer);

			var applyButton;
			if (items[x].hasApply) {
				var cell2 = row.insertCell(2);
				cell2.align = "center";
				var applyButtonContainer = document.createElement("div");
				cell2.appendChild(applyButtonContainer);
				applyButton = dojo.widget.createWidget(
					"Button", {caption: "Apply"}, applyButtonContainer);
			}
			
			var cell3 = row.insertCell(items[x].hasApply ? 3:2);
			cell3.align = "left";
			var cancelButtonContainer = document.createElement("div");
			cell3.appendChild(cancelButtonContainer);
			var cancelButton = dojo.widget.createWidget(
				"Button", {caption: "Cancel"}, cancelButtonContainer);
			
			retItems[items[x].id] = 
				{ok: okButton, apply: applyButton, cancel: cancelButton};
				
		} else if (items[x].type == "AddRemoveButtonRow") {
			
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);

			var cell1 = row.insertCell(1);

			var cell2 = row.insertCell(2);
			cell2.align = "right";
			var addButtonContainer = document.createElement("div");
			cell2.appendChild(addButtonContainer);
			var addButton = dojo.widget.createWidget(
				"Button", {caption: "Add"}, addButtonContainer);

			var cell3 = row.insertCell(3);
			cell3.align = "left";
			var removeButtonContainer = document.createElement("div");
			cell3.appendChild(removeButtonContainer);
			var removeButton = dojo.widget.createWidget(
				"Button", {caption: "Remove"}, removeButtonContainer);
			
			retItems[items[x].id] = 
				{add: addButton, remove: removeButton};

		} else if (items[x].type == "ComboBox") {
	
			var row = table.insertRow(rowCounter++);
			var cell0 = row.insertCell(0);
			cell0.colSpan = 2;
			cell0.appendChild(document.createTextNode(items[x].labelText));
			
			var cell1 = row.insertCell(1);
			cell1.colSpan = 3;
			var cell1Select = document.createElement("select");
			cell1.appendChild(cell1Select);
			
			for(var y in items[x].options) {
				var option = document.createElement("option");
				option.appendChild(document.createTextNode(items[x].options[y]));
				cell1Select.appendChild(option);
			}
			
			var connectorComboBox = dojo.widget.createWidget(
				"ComboBox", {forceValidOption: true}, cell1Select);

			connectorComboBox.setValue(items[x].defaultOption);
			
			retItems[items[x].id] = connectorComboBox;
			
		}
	}
	
	return {table: table, items: retItems};
};

dojo.lang.mixin(diagram, {
	xmlTextParse: function(text) {
		if (window.ActiveXObject) {
			// code for IE
			var xmlDoc = new ActiveXObject("Microsoft.XMLDOM");
  			xmlDoc.async = false;
  			xmlDoc.loadXML(text);
  		} else {
			// code for Mozilla, Firefox, Opera, etc.
		    var parser = new DOMParser();
		    var xmlDoc = parser.parseFromString(text, "text/xml");
  		}

		return xmlDoc.documentElement;
	},
	
	xmlFileParse: function(file) {
		if (window.ActiveXObject) {
			// code for IE
			var xmlDoc = new ActiveXObject("Microsoft.XMLDOM");
  			xmlDoc.async = false;
  			xmlDoc.load(file);
  		} else {
			// code for Mozilla, Firefox, Opera, etc.
			var xmlDoc = document.implementation.createDocument("", "", null);
			xmlDoc.async = false;
  			xmlDoc.load(file);
		}
		
		return xmlDoc.documentElement;
	}	
});

dojo.lang.mixin(diagram, {
	getBestConnectorPosition: function(src, tgt) {
		var srcBB = src.getBoundingBox();
		var tgtBB = tgt.getBoundingBox();
		
		var srcCenter = {x: srcBB.x + srcBB.width/2, y: srcBB.y + srcBB.height/2};
		var tgtCenter = {x: tgtBB.x + tgtBB.width/2, y: tgtBB.y + tgtBB.height/2};
	
		var deg = -diagram.getAngle(srcCenter, tgtCenter);
	
		if (deg <= 45) {
			srcPos = "east";
			tgtPos = "west";
		} else if (deg <= 135) {
			srcPos = "south";
			tgtPos = "north";
		} else if (deg <= 225) {
			srcPos = "west";
			tgtPos = "east";
		} else if (deg < 315) {
			srcPos = "north";
			tgtPos = "south";
		} else {
			srcPos = "east";
			tgtPos = "west";
		}
	
		return {srcPos: srcPos, tgtPos: tgtPos};		
	},
	
	getAngle: function(p1, p2) {
		var p3 = {x: p2.x - p1.x, y: p2.y - p1.y};
		var angle = Math.atan( p3.y/p3.x );
		var deg = dojo.math.radToDeg(angle);

		if (p3.x < 0) {
			deg = -(deg + 180);
		} else if (p3.y < 0) {
			deg = -(deg + 360);
		} else {
			deg = -deg;
		}
		
		return deg;
	},
	
	getRect: function(text, fontProperties) {
		var span = document.createElement("span");
		
		for(var x in fontProperties) {
			span.style[x] = fontProperties[x];
		}
		document.body.appendChild(span);
		var rect = dojo.html.measureFragment(
			span, 
			text, 
			dojo.html.boxSizing.MARGIN_BOX);
		document.body.removeChild(span);

		return rect;		
	},
	
	applyGrid: function(x, grid) {
		var xMod = x % grid;
		if (xMod < grid/2) {
			return x - xMod;
		} else {
			return x + (grid-xMod);
		}
	}
	
});

dojo.declare("diagram.SelectionListener", null, {
	selectionChanged: function(newSelection) {
	}
});

var _boxDivId = 0;
dojo.declare("diagram.BoxDiv", null, {
	rect: null,
	
	initializer: function(surface, rect, fillColor) {
		this.surface = surface;
		
		var parentNode = this.surface.rawNode.parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}
		
		this.boxDiv = document.createElement("div");
		this.boxDiv.id = "diagram.BoxDiv" + _boxDivId++;
		
		if (fillColor == null) {
			fillColor = new dojo.gfx.color.Color(255, 255, 255, 0);
		}
		this.boxDiv.style.backgroundColor = fillColor.toCss();
		this.boxDiv.style.filter = "alpha(opacity=" + (fillColor.a*100) + ")";
		this.boxDiv.style.MozOpacity = fillColor.a;

		// having a font size of 1px is needed in order for IE to properly 
		// size the box (otherwise size of the box is determined by font size)
		this.boxDiv.style.fontSize = "1px";
		this.boxDiv.style.lineHeight = "normal";
		this.boxDiv.style.fontFamily = "arial";
		
		this.setRect(rect);
		
		// adding text to the div allows proper scrolling in firefox when
		// moving the div
		this.boxDiv.innerHTML = ".";

		parentNode.appendChild(this.boxDiv);
	},
	
	getRect: function() {
		return this.rect;
	},
	
	setRect: function(rect) {
		this.rect = rect;
		
		with(this.boxDiv.style) {
			position = "absolute";
			top = rect.y + "px";
			left = rect.x + "px";
			width = rect.width + "px";
			height = rect.height + "px";
		}
	},
	
	getEventSource: function() {
		return this.boxDiv;
	},
	
	remove: function() {
		var parentNode = this.surface.rawNode.parentNode;
		parentNode.removeChild(this.boxDiv);
	}
});

dojo.declare("diagram.Editable", null, {
	// summary: a prototype for editable objects

	editable: false,
	
	isEditable: function() {
		// summary: whether this editor is in an editable state or not
		return editable;	// boolean	
	},
	
	setEditable: function(isEditable) {
		// summary: sets whether this editor is in editable state or not
		// isEditable: boolean
		editable = isEditable;
	}
});

dojo.declare("diagram.Manipulator", null, {
	getShape: function() {
		return null;
	},
	
	setGrid: function(grid) {
	},
	
	destroy: function() {
	}
});

dojo.declare("diagram.Shape", [dojo.gfx.Shape, diagram.Editable], {
	setBoundingBox: function(newBB, grid) {
	},
	
	createManipulator: function() {
	},
	
	edit: function(cursorPosition) {
	},
	
	getHRef: function() {
	}
});

dojo.declare("diagram.ConnectorArrow", null, {
	initializer: function(shapePoints, fillColor, stroke) {
		this.shapePoints = shapePoints;
		this.fillColor = fillColor;
		this.stroke = stroke;	
	}
});

dojo.declare("diagram.Connector", diagram.Shape, {
	setSource: function(shape, position, bias) {
		// summary: sets the source of this connector
		//	shape: diagram.Shape: the source shape
		// 	position: "north", "south", "east", "west": side of the bounding
		//	box of the given shape
		//  bias: a number from 0 to 1 that indicates the bias from one side
		//  to the other of the side of the bounding box of the given shape
		this.sourceShape = shape;
		this.sourcePosition = position;
		this.sourceBias = bias;

		dojo.event.connect(shape, shape.setBoundingBox, this, this.updatePosition);
	},
	
	setTarget: function(shape, position, bias) {
		// summary: sets the target of this connector
		//	shape: diagram.Shape: the target shape
		// 	position: 'north', "south", "east", "west": side of the bounding
		//	box of the given shape
		//  bias: a number from 0 to 1 that indicates the bias from one side
		//  to the other of the side of the bounding box of the given shape
		this.targetShape = shape;
		this.targetPosition = position;
		this.targetBias = bias;
		
		dojo.event.connect(shape, shape.setBoundingBox, this, this.updatePosition);
	},
	
	remove: function() {
		dojo.event.disconnect(this.sourceShape, this.sourceShape.setBoundingBox, this, this.updatePosition);
		this.sourceShape = null;

		dojo.event.disconnect(this.targetShape, this.targetShape.setBoundingBox, this, this.updatePosition);
		this.targetShape = null;
	},
	
	getPoints: function() {
		return [this.getSourcePoint(), this.getTargetPoint()];
	},
	
	updatePosition: function() {
	},
	
	getSourcePoint: function() {
		// summary: returns the source location
		return this._getPoint(
			this.sourceShape, 
			this.sourcePosition, 
			this.sourceBias);	// dojo.gfx.Point
	},

	getTargetPoint: function() {
		// summary: returns the target location
		return this._getPoint(
			this.targetShape, 
			this.targetPosition, 
			this.targetBias);	// dojo.gfx.Point
	},
	
	_getPoint: function(shape, position, bias) {
		var bb = shape.getBoundingBox();
		
		var x = 0;
		var y = 0;
		
		if (position == 'north') {
			x = bb.x + bias*bb.width;
			y = bb.y;
		} else if (position == 'south') {
			x = bb.x + bias*bb.width;
			y = bb.y + bb.height;
		} else if (position == 'west') {
			x = bb.x;
			y = bb.y + bias*bb.height;
		} else if (position == 'east') {
			x = bb.x + bb.width;
			y = bb.y + bias*bb.height;
		}

		return {x: x, y: y};	// dojo.gfx.Point
	}	
});

dojo.declare("diagram.TableDiv", null, {
	parentNode: null,
	tableDiv: null,
	table: null,
	filteringTable: null,
	
	initializer: function(
		parentNode, rect, textColor, fontProperties, tableProperties, 
		hasHeader, columns, data) {

		this.parentNode = parentNode;
		if (parentNode.style.position != "relative") {
			parentNode.style.position = "relative";
		}

		this.tableDiv = document.createElement("div");
		this.table = document.createElement("table");
		
		if (rect.x != null) {
			this.tableDiv.style.position = "absolute";
		}
		if (textColor != null) {
			this.tableDiv.style.color = textColor.toCss();
		}

		for(var x in fontProperties) {
			this.tableDiv.style[x] = fontProperties[x];
			this.table.style[x] = fontProperties[x];
		}
		
		parentNode.appendChild(this.tableDiv);
		this.tableDiv.appendChild(this.table);
		
		if (!hasHeader) {
			// create dummy header
			thead = document.createElement("thead");
			tr = document.createElement("tr");
			thead.appendChild(tr);
			this.table.appendChild(thead);
			
			for(x in columns) {
				tr.appendChild(document.createElement("td"));
			}
		}

		this.filteringTable = dojo.widget.createWidget(
			"dojo:FilteringTable", 
			tableProperties,
			this.table);
		
		for (var x = 0; x < columns.length; x++) {
			this.filteringTable.columns.push(
				this.filteringTable.createMetaData(columns[x]));
		}
		
	
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
		this.filteringTable.store.setData(data);
		this.data = data;
	},
	
	add: function(item) {
		this.filteringTable.store.addData(item);
		this.data.push(item);
	},
	
	removeSelected: function() {
		var idx = [];
		var counter = 0;
		for(var i = 0; i < this.data.length; i++) {
			if (this.filteringTable.isIndexSelected(i)) {
				idx[counter++] = i;
			}
		}
		
		for(var i = idx.length - 1; i >= 0; i--) {
			this.filteringTable.store.removeDataByIndex(idx[i]);
			this.data.splice(idx[i], 1);
		}
	},
	
	remove: function() {
		this.parentNode.removeChild(this.tableDiv);
	}
});

dojo.declare("diagram.Label", null, {
	surface: null,
	text: null,
	labelDiv: null,
	labelText: null,
	editBoxDiv: null,

	initializer: function( 
		surface, text, rect, textColor, fontProperties) {
		// summary: creates a label
		
		this.surface = surface;

		var node = surface.getEventSource();
		node = node.parentNode;
		if (node.style.position != "relative") {
			node.style.position = "relative";
		}

		this.labelDiv = document.createElement("div");
		
		with(this.labelDiv.style) {
			position = "absolute";
			color = textColor.toCss();
		}
		for(var x in fontProperties) {
			this.labelDiv.style[x] = fontProperties[x];
		}
		
		this.text = text;
		this.labelText = document.createTextNode(this.text);
		
		this.labelDiv.appendChild(this.labelText);
		
		node.appendChild(this.labelDiv);

		this.setRect(rect);
	},
	
	setText: function(text) {
		this.text = text;
		this.labelText.data = text;
	},
	
	setRect: function(rect) {
		with(this.labelDiv.style) {
			top = rect.y + "px";
			left = rect.x + "px";
			width = rect.width + "px";
			height = rect.height + "px";
		}
	},
	
	remove: function() {
		var parentNode = this.surface.rawNode.parentNode;
		parentNode.removeChild(this.labelDiv);
	}
});
