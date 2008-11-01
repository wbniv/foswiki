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

dojo.provide("diagram.editor");

dojo.require("diagram.common");
dojo.require("dojo.gfx.*");
dojo.require("dojo.html.*");
dojo.require("dojo.html.metrics");
dojo.require("dojo.widget.Menu2");

diagram.addConnectorPosBias = function(
	connectorClass, editor, 
	src, srcPos, srcBias, srcConnectorArrow,
	tgt, tgtPos, tgtBias, tgtConnectorArrow) {
	// summary: adds a connector to an editor
	// editor: diagram.Editor: the editor where the UML class is added
	// connectorClass: the class of connector to create	
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
	var c = new connectorClass(
		editor.getSurface(), 
		src, srcPos, srcBias, srcConnectorArrow,
		tgt, tgtPos, tgtBias, tgtConnectorArrow,
		editor.isEditable());

	editor.registerShape(c);
	
	return c;	// connector type instance
};

diagram.addConnector = function(
	connectorClass, editor, 
	src, srcConnectorArrow,
	tgt, tgtConnectorArrow) {
	// summary: adds a connector to an editor
	// editor: diagram.Editor: the editor where the UML class is added
	// connectorClass: the class of connector to create	
	// src: diagram.Shape: the source shape
	// srcConnectorArrow: diagram.ConnectorArrow: the connector arrow
	//	used in the source side of the connector
	// tgt: diagram.Shape: the target shape
	// tgtConnectorArrow: diagram.ConnectorArrow: the connector arrow
	//	used in the target side of the connector

	var bestPos = diagram.getBestConnectorPosition(src, tgt);

	var c = new connectorClass(
		editor.getSurface(), 
		src, bestPos.srcPos, 0.5, srcConnectorArrow,
		tgt, bestPos.tgtPos, 0.5, tgtConnectorArrow,
		editor.isEditable());

	editor.registerShape(c);
	
	return c;	// connector type instance
};

var _shapeIdAttrName = 'diagram-shape-id';

dojo.lang.mixin(diagram.editor, {
	setShapeId: function(shape, shapeId) {
		shape.getEventSource().setAttribute(_shapeIdAttrName, shapeId);
	},
	
	getShapeId: function(shape) {
		return shape.getEventSource().getAttribute(_shapeIdAttrName);
	}
});

dojo.lang.mixin(diagram.editor, {
	getDimensions: function(surface) {
		var d = surface.getDimensions();
		
		return {width: parseInt(d.width), height: parseInt(d.height)};
	},
	
	redimensionSurface: function(surface, bb) {
		var d = diagram.editor.getDimensions(surface);
		
		if ((bb.x + bb.width) > d.width) {
			surface.setDimensions(bb.x + bb.width, d.height);
		}
		if ((bb.y + bb.height) > d.height) {
			surface.setDimensions(d.width, bb.y + bb.height);
		}			
	}
});

dojo.declare("diagram.Editor", diagram.Editable, {
	// summary: a diagram editor

	backgroundColor: new dojo.gfx.color.Color(245, 245, 220, 1),
	container: null,
	surface: null,
	shapes: {},
	shapeCounter: 0,
	selection: null,
	shapeManipulators: null,
	selectionListeners: null,
	hrefTranslate: null,
	
	gridColor: new dojo.gfx.color.Color(150, 150, 150, 0.3),
	gridStroke: null,
	grid: null,
	gridLines: [],
	
	initializer: function(container, editable, hrefTranslate) {
		// summary: creates a diagram editor
		// container: Node: the node where the diagram is located
		// editable: whether the diagram is editable

		gridStroke = {color: this.gridColor, width: 1};

		this.container = container;
		this.hrefTranslate = hrefTranslate;
		
		this.shapeManipulators = Array();
		this.selectionListeners = Array();
		
		container.style.position = "relative";
		container.style.overflow = "scroll";
		container.style.backgroundColor = this.backgroundColor.toCss();

		var bb = dojo.html.getBorderBox(this.container);
		var sb = dojo.html.getScrollbar();
		this.surface = dojo.gfx.createSurface(
			this.container, bb.width - sb.width, bb.height - sb.width);

		dojo.event.connect(
			this.container, 'onclick', this, this.handleSurfaceOnClick);
			
		// container popup menu
		this.containerPopupMenu = dojo.widget.createWidget(
			"PopupMenu2", {targetNodeIds: [this.container.id]});
		this.containerPopupMenu.addChild(
			dojo.widget.createWidget("MenuItem2", {caption: "Help"}));
		
		// shape popup menu
		this.shapePopupMenu = dojo.widget.createWidget(
			"PopupMenu2", {targetNodeIds: []});
		this.editMenuItem = this.shapePopupMenu.addChild(
			dojo.widget.createWidget("MenuItem2", {caption: "Edit"}));
		dojo.event.connect(this.editMenuItem, 'onClick', this, this.handleEditShape);
		this.shapePopupMenu.addChild(
			dojo.widget.createWidget("MenuSeparator2"));
		this.deleteMenuItem = this.shapePopupMenu.addChild(
			dojo.widget.createWidget("MenuItem2", {caption: "Delete"}));
		dojo.event.connect(this.deleteMenuItem, 'onClick', this, this.handleDeleteShape);

		this.setEditable(editable);
	},
	
	addSelectionListener: function(listener) {
		this.selectionListeners.push(listener);
	},
	
	notifySelectionListeners: function() {
		for(i = 0; i < this.selectionListeners.length; i++) {
			this.selectionListeners[i].selectionChanged(this.shapeManipulators);
		}
	},
	
	getSurface: function() {
		// summary: returns the surface used in this editor
		return this.surface; 	// dojo.gfx.Surface
	},
	
	setEditable: function(editable) {
		// TODO: this should iterate through all shapes and call setEditable
		diagram.Editor.superclass.setEditable.apply(this, [editable]);

		this.editMenuItem.setDisabled(!editable);
		this.deleteMenuItem.setDisabled(!editable);

		this.removeManipulators();
		this.notifySelectionListeners();
	},
	
	setGrid: function(grid) {
		this.grid = grid;
		for(i = 0; i < this.shapeManipulators.length; i++) {
			this.shapeManipulators[i].setGrid(grid);
		}
		
		if (grid) {
			var d = diagram.editor.getDimensions(this.surface);
			
			var gridCounter = 0;
			for(var i = 0; i < d.width; i += 20) {
				this.gridLines[gridCounter] = this.surface.createRect({x: i, y: 0, width: 10, height: d.height});
				this.gridLines[gridCounter++].setStroke(gridStroke);
			}
			for(var i = 0; i < d.height; i += 20) {
				this.gridLines[gridCounter] = this.surface.createRect({x: 0, y: i, width: d.width, height: 10});
				this.gridLines[gridCounter++].setStroke(gridStroke);
			}
		} else {
			for(x in this.gridLines) {
				this.surface.remove(this.gridLines[x]);
			}
		}
	},
	
	registerShape: function(shape) {
		// summary: registers the given shape to this editor
		// shape: diagram.Shape: a shape to register
		
		dojo.event.connect(
			shape.getEventSource(), 'onclick', this, this.handleShapeOnClick);
		
		shapeId = 'id_' + this.shapeCounter++;
		
		diagram.editor.setShapeId(shape, shapeId);
		this.shapes[shapeId] = shape;
		
		this.shapePopupMenu.bindDomNode(shape.getEventSource());
		
		// redimension surface if necessary
		var bb = shape.getBoundingBox();
		if (bb) {
			diagram.editor.redimensionSurface(this.surface, bb);
		}
	},
	
	unregisterShape: function(shape) {
		// summary: unregisters and destroys the given shape from this editor
		// shape: diagram.Shape: a shape to unregister and destroy
		
		// unregister connectors pointing to this shape
		if (!(shape instanceof diagram.Connector)) {
			for(x in this.shapes) {
				if (this.shapes[x] instanceof diagram.Connector) {
					if (this.shapes[x].sourceShape == shape || 
					    this.shapes[x].targetShape == shape) {
						this.unregisterShape(this.shapes[x]);
					}
				}
			}
		}
		
		dojo.event.disconnect(
			shape.getEventSource(), 'onclick', this, this.handleShapeOnClick);
		
		var shapeId = diagram.editor.getShapeId(shape);
		
		this.shapes[shapeId] = null;
		
		this.shapePopupMenu.unBindDomNode(shape.getEventSource());
		
		// if there is a manipulator active to the given shape then destroy it
		for(i = 0; i < this.shapeManipulators.length; i++) {
			var iManipulator = this.shapeManipulators[i];
			var iShapeId = diagram.editor.getShapeId(iManipulator.getShape());

			if (shapeId == iShapeId) {
				this.shapeManipulators.splice(i, 1);
				iManipulator.destroy();
			}
		}

		shape.remove();

		this.notifySelectionListeners();
	},
	
	getShapes: function() {
		return this.shapes;
	},
	
	getShape: function(event) {
		var shapeId = event.target.getAttribute(_shapeIdAttrName);

		return shapeId ? this.shapes[shapeId] : null;
	},
	
	handleEditShape: function() {
		var event = this.shapePopupMenu.openEvent;

		var cursorPosition = {
			x: this.shapePopupMenu.explodeSrc.left, 
			y: this.shapePopupMenu.explodeSrc.top};
		var shape = this.getShape(event);
		if (shape != null) {
			shape.edit(cursorPosition);
		}
	},
	
	handleDeleteShape: function() {
		var event = this.shapePopupMenu.openEvent;

		var shape = this.getShape(event);
		if (shape != null) {
			this.unregisterShape(shape);
		}
	},
	
	handleShapeOnClick: function(event) {
		if (!event.ctrlKey) {
			this.removeManipulators();
		}
		
		var shape = this.getShape(event);
		
		if (shape != null) {
			if (this.isEditable()) {
				this.createManipulator(shape, event.ctrlKey);
			} else {
				var href = shape.getHRef();
				
				if (href != null && href.length > 0) {
					if (this.hrefTranslate != null) {
						location.href = this.hrefTranslate(href);
					} else {
						location.href = href;
					}
				}
			}
		}
		
		this.notifySelectionListeners();
		
		dojo.event.browser.stopEvent(event);
	},

	handleSurfaceOnClick: function(event) {
		if (event.target.getAttribute('manipulatorId') == null) {
			// remove the manipulator only if it is not the target of the click
			this.removeManipulators();
			
			this.notifySelectionListeners();
		}
	},
	
	createManipulator: function(shape, isCtrlKey) {
		// There can be only one connector manipulator selected at a one
		// single time
		if (	this.shapeManipulators.length > 0 && 
				this.shapeManipulators[0].declaredClass == "diagram.ConnectorManipulator") {
			return;
		}

		// If CTRL is pressed then check if the gesture is unselection
		// instead of selection
		if (isCtrlKey) {
			var shapeId = diagram.editor.getShapeId(shape);
					
			for(i = 0; i < this.shapeManipulators.length; i++) {
				var iManipulator = this.shapeManipulators[i];
				var iShapeId = diagram.editor.getShapeId(iManipulator.getShape());

				if (shapeId == iShapeId) {
					this.shapeManipulators.splice(i, 1);
					iManipulator.destroy();
				
					return;
				}
			}
		}
			
		var manipulator = shape.createManipulator(this.surface);
		manipulator.setGrid(this.grid);

		// Selected manipulators must be all of the same type		
		if (	this.shapeManipulators.length == 0 || 
				this.shapeManipulators[0].declaredClass == manipulator.declaredClass) {
			this.shapeManipulators.push(manipulator);
		} else {
			manipulator.destroy();
		}
	},
	
	removeManipulators: function() {
		while(this.shapeManipulators.length > 0) {
			this.shapeManipulators.pop().destroy();
		}
	}
});

dojo.declare("diagram.ShapeManipulator", diagram.Manipulator, {
	// summary: a shape manipulator
	
	fillColor: new dojo.gfx.color.Color(150, 150, 150, 0.5),
	
	container: null,
	containerPosition: null,
	activeManipulator: null,
	moveManipulator: null,
	nwManipulator: null,
	neManipulator: null,
	swManipulator: null,
	seManipulator: null,
	surface: null,
	shape: null,
	grid: null,
	
	initializer: function(surface, shape) {
		// summary: creates a shape manipulator
		// surface: dojo.gfx.Surface: the surface where the manipulator is created
		// shape: diagram.Shape: the shape to manipulate

		this.container = surface.rawNode.parentNode;
		this.containerPosition = dojo.html.abs(this.container);
		this.surface = surface;
		this.shape = shape;

		this.moveManipulator = new diagram.BoxDiv(
			surface, this._getMoveManipulatorShape(), this.fillColor);
		this.moveManipulator.getEventSource().style.cursor = "move";
		this.moveManipulator.getEventSource().setAttribute(
			'manipulatorId', 'move');

		this.nwManipulator = new diagram.BoxDiv(
			surface, this._getNWManipulatorShape(), this.fillColor);
		this.nwManipulator.getEventSource().style.cursor = "nw-resize";
		this.nwManipulator.getEventSource().setAttribute(
			'manipulatorId', 'nw');

		this.neManipulator = new diagram.BoxDiv(
			surface, this._getNEManipulatorShape(), this.fillColor);
		this.neManipulator.getEventSource().style.cursor = "ne-resize";
		this.neManipulator.getEventSource().setAttribute(
			'manipulatorId', 'ne');

		this.swManipulator = new diagram.BoxDiv(
			surface, this._getSWManipulatorShape(), this.fillColor);
		this.swManipulator.getEventSource().style.cursor = "sw-resize";
		this.swManipulator.getEventSource().setAttribute(
			'manipulatorId', 'sw');

		this.seManipulator = new diagram.BoxDiv(
			surface, this._getSEManipulatorShape(), this.fillColor);
		this.seManipulator.getEventSource().style.cursor = "se-resize";
		this.seManipulator.getEventSource().setAttribute(
			'manipulatorId', 'se');

		this.lastPosition = {x: 0, y: 0};
		
		dojo.event.connect(
			this.container, 
			'onmousedown', 
			this, 
			this.handleOnMouseDown);
		dojo.event.connect(
			dojo.body(),
			'onmouseup',
			this,
			this.handleOnMouseUp);
		dojo.event.connect(
			dojo.body(),
			'onmousemove',
			this,
			this.handleOnMouseMove);			
	},
	
	setGrid: function(grid) {
		this.grid = grid;
	},
	
	handleOnMouseDown: function(event) {
		this.lastPosition = {
			x: event.clientX - this.containerPosition.x,
			y: event.clientY - this.containerPosition.y
		};
		
		if (event.target.getAttribute('manipulatorId') == 'move') {
			this.activeManipulator = this.moveManipulator;
     	} else if (event.target.getAttribute('manipulatorId') == 'nw') {
     		this.activeManipulator = this.nwManipulator;
     	} else if (event.target.getAttribute('manipulatorId') == 'ne') {
     		this.activeManipulator = this.neManipulator;
     	} else if (event.target.getAttribute('manipulatorId') == 'sw') {
     		this.activeManipulator = this.swManipulator;
     	} else if (event.target.getAttribute('manipulatorId') == 'se') {
     		this.activeManipulator = this.seManipulator;
     	}
	},

	handleOnMouseUp: function(event) {
		this.activeManipulator = null;
		
		// when mouse is up then the shape is aligned to grid (in case grid
		// is turned on)
		this.setBoundingBox(this.shape.getBoundingBox(), this.grid);
	},
	
	handleOnMouseMove: function(event) {
		var newPosition = {
			x: event.clientX - this.containerPosition.x,
			y: event.clientY - this.containerPosition.y
		}
			
		if (this.activeManipulator == this.moveManipulator) {
			var bb = this.shape.getBoundingBox();
			var newBB = {
				x: bb.x + (newPosition.x - this.lastPosition.x),
				y: bb.y + (newPosition.y - this.lastPosition.y),
				width: bb.width,
				height: bb.height };

			this.setBoundingBox(newBB);				
		} else if (this.activeManipulator == this.nwManipulator) {
			var bb = this.shape.getBoundingBox();
			var newBB = {
				x: bb.x + (newPosition.x - this.lastPosition.x),
				y: bb.y + (newPosition.y - this.lastPosition.y),
				width: bb.width - (newPosition.x - this.lastPosition.x),
				height: bb.height - (newPosition.y - this.lastPosition.y)};
				
			this.setBoundingBox(newBB);				
		} else if (this.activeManipulator == this.neManipulator) {
			var bb = this.shape.getBoundingBox();
			var newBB = {
				x: bb.x,
				y: bb.y + (newPosition.y - this.lastPosition.y),
				width: bb.width + (newPosition.x - this.lastPosition.x),
				height: bb.height - (newPosition.y - this.lastPosition.y)};
				
			this.setBoundingBox(newBB);				
		} else if (this.activeManipulator == this.swManipulator) {
			var bb = this.shape.getBoundingBox();
			var newBB = {
				x: bb.x + (newPosition.x - this.lastPosition.x),
				y: bb.y,
				width: bb.width - (newPosition.x - this.lastPosition.x),
				height: bb.height + (newPosition.y - this.lastPosition.y)};
				
			this.setBoundingBox(newBB);				
		} else if (this.activeManipulator == this.seManipulator) {
			var bb = this.shape.getBoundingBox();
			var newBB = {
				x: bb.x,
				y: bb.y,
				width: bb.width + (newPosition.x - this.lastPosition.x),
				height: bb.height + (newPosition.y - this.lastPosition.y)};
				
			this.setBoundingBox(newBB);				
		}
		
		this.lastPosition = newPosition;
	},
	
	setBoundingBox: function(newBB, grid) {
		if (newBB.x > 0 && newBB.y > 0) {
			// check if surface dimensions need to be increased
			// redimension surface if necessary
			diagram.editor.redimensionSurface(this.surface, newBB);
			
			this.shape.setBoundingBox(newBB, grid);

			this.moveManipulator.setRect(this._getMoveManipulatorShape());
			this.nwManipulator.setRect(this._getNWManipulatorShape());
			this.neManipulator.setRect(this._getNEManipulatorShape());
			this.swManipulator.setRect(this._getSWManipulatorShape());
			this.seManipulator.setRect(this._getSEManipulatorShape());
		}
	},
	
	getShape: function() {
		return this.shape;
	},
	
	destroy: function() {
		this.moveManipulator.remove();
		
		this.nwManipulator.remove();
		this.neManipulator.remove();
		this.swManipulator.remove();
		this.seManipulator.remove();
		
		dojo.event.disconnect(
			this.container, 
			'onmousedown', 
			this, 
			this.handleOnMouseDown);
		dojo.event.disconnect(
			dojo.body(),
			'onmouseup',
			this,
			this.handleOnMouseUp);
		dojo.event.disconnect(
			dojo.body(),
			'onmousemove',
			this,
			this.handleOnMouseMove);			
	},
	
	_getMoveManipulatorShape: function() {
		var bb = this.shape.getBoundingBox();
		
		return {
			x: bb.width/2 + bb.x - 5, y: bb.height/2 + bb.y - 5, 
			width: 10, height: 10};
	},
	
	_getNWManipulatorShape: function() {
		var bb = this.shape.getBoundingBox();
		
		return {x: bb.x - 5, y: bb.y - 5, width: 10, height: 10};
	},
	
	_getNEManipulatorShape: function() {
		var bb = this.shape.getBoundingBox();
		
		return {x: bb.x + bb.width - 5, y: bb.y - 5, width: 10, height: 10};
	},	
	
	_getSWManipulatorShape: function() {
		var bb = this.shape.getBoundingBox();
		
		return {x: bb.x - 5, y: bb.y + bb.height - 5, width: 10, height: 10};
	},	
	
	_getSEManipulatorShape: function() {
		var bb = this.shape.getBoundingBox();
		
		return {
			x: bb.x + bb.width - 5, y: bb.y + bb.height - 5, 
			width: 10, height: 10};
	}
});

dojo.declare("diagram.ConnectorManipulator", diagram.Manipulator, {
	// summary: a connector manipulator
	
	fillColor: new dojo.gfx.color.Color(150, 150, 150, 0.5),
	
	container: null,
	containerPosition: null,
	activeManipulator: null,
	moveManipulator: [],
	surface: null,
	connector: null,
	
	initializer: function(surface, connector) {
		// summary: creates a shape manipulator
		// surface: dojo.gfx.Surface: the surface where the manipulator is created
		// shape: diagram.Connector: the connector to manipulate

		this.container = surface.rawNode.parentNode;
		this.containerPosition = dojo.html.abs(this.container);
		this.surface = surface;
		this.connector = connector;
		
		var points = this.connector.getPoints();
		for(var i = 0; i < points.length; i++) {
			var p = points[i];

			this.moveManipulator[i] = new diagram.BoxDiv(
				surface, 
				{x: p.x - 5, y: p.y - 5, width: 10, height: 10}, 
				this.fillColor);
			this.moveManipulator[i].getEventSource().style.cursor = "move";
			this.moveManipulator[i].getEventSource().setAttribute(
				'manipulatorId', i);
		}
		
		this.sourceManipulator = this.moveManipulator[0];
		this.targetManipulator = this.moveManipulator[this.moveManipulator.length-1];
		
		this.lastPosition = {x: 0, y: 0};
		
		dojo.event.connect(
			this.container, 
			'onmousedown', 
			this, 
			this.handleOnMouseDown);
		dojo.event.connect(
			dojo.body(),
			'onmouseup',
			this,
			this.handleOnMouseUp);
		dojo.event.connect(
			dojo.body(),
			'onmousemove',
			this,
			this.handleOnMouseMove);			
	},
	
	handleOnMouseDown: function(event) {
		this.lastPosition = {
			x: event.clientX - this.containerPosition.x,
			y: event.clientY - this.containerPosition.y
		};
		
		var manipulatorId = event.target.getAttribute('manipulatorId');
		if (manipulatorId != null) {
			this.activeManipulator = this.moveManipulator[manipulatorId];
     	}
	},

	handleOnMouseUp: function(event) {
		this.activeManipulator = null;
	},
	
	handleOnMouseMove: function(event) {
		var newPosition = {
			x: event.clientX - this.containerPosition.x,
			y: event.clientY - this.containerPosition.y
		}
		
		if (this.activeManipulator) {
			var dx = newPosition.x - this.lastPosition.x;
			var dy = newPosition.y - this.lastPosition.y;
			
			var bb = null;
			var position = null;
			if (this.activeManipulator == this.sourceManipulator) {
				// source
				bb = this.connector.sourceShape.getBoundingBox();
				position = this.connector.sourcePosition;
			} else if (this.activeManipulator == this.targetManipulator) {
				// target
				bb = this.connector.targetShape.getBoundingBox();
				position = this.connector.targetPosition;
			} else {
				return;
			}
			
			var newX = 0;
			var newY = 0;
			var newBias = 0;
			var newPos = position;
			if (position == "north" || position == "south") {
				newX = this.activeManipulator.getRect().x + dx;
				newY = this.activeManipulator.getRect().y;

				newBias = ((newX + 5) - bb.x)/bb.width;
				if (newBias < 0) {
					newPos = "west";
					newX = bb.x - 5;
					if (position == "north") {
						newBias = 0;
					} else {
						newBias = 1;
					}
				} else if (newBias > 1) {
					newPos = "east";
					newX = bb.x + bb.width - 5;
					if (position == "north") {
						newBias = 0;
					} else {
						newBias = 1;
					}
				}
			} else {
				newX = this.activeManipulator.getRect().x;
				newY = this.activeManipulator.getRect().y + dy;

				newBias = ((newY + 5) - bb.y)/bb.height;
				if (newBias < 0) {
					newPos = "north";
					newY = bb.y - 5;
					if (position == "west") {
						newBias = 0;
					} else {
						newBias = 1;
					}
				} else if (newBias > 1) {
					newPos = "south";
					newY = bb.y + bb.height - 5;
					if (position == "east") {
						newBias = 0;
					} else {
						newBias = 1;
					}
				}
			}
			
			if (this.activeManipulator == this.sourceManipulator) {
				// source
				this.connector.sourcePosition = newPos;
				this.connector.sourceBias = newBias;
			} else if (this.activeManipulator == this.targetManipulator) {
				// target
				this.connector.targetPosition = newPos;
				this.connector.targetBias = newBias;
			}

			this.activeManipulator.setRect(
				{x: newX, y: newY, width: 10, height: 10});
			
			this.connector.updatePosition();
		}
		
		this.lastPosition = newPosition;
	},
	
	getShape: function() {
		return this.connector;
	},
	
	destroy: function() {
		var points = this.connector.getPoints();
		for(var i = 0; i < points.length; i++) {
			this.moveManipulator[i].remove();
		}
		
		dojo.event.disconnect(
			this.container, 
			'onmousedown', 
			this, 
			this.handleOnMouseDown);
		dojo.event.disconnect(
			dojo.body(),
			'onmouseup',
			this,
			this.handleOnMouseUp);
		dojo.event.disconnect(
			dojo.body(),
			'onmousemove',
			this,
			this.handleOnMouseMove);			
	}
});
