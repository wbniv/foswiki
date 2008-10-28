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

dojo.provide("diagram.xmi");

dojo.require("dojo.json");
dojo.require("diagram.common");
dojo.require("diagram.editor");
dojo.require("diagram.uml");

dojo.declare("diagram.xmi.Handler", null, {
	initializer: function() {
	},
	
	xmiTextImport: function(text, editor) {
		var doc = diagram.xmlTextParse(text);
		
		this.xmiImport(doc, editor);
	},
	
	xmiFileImport: function(file, editor) {
		var doc = diagram.xmlFileParse(file);

		var start = new Date().getTime();
		this.xmiImport(doc, editor);
		var end = new Date().getTime();
		dojo.debug("xmi import elapsed time: " + (end-start) + "ms");
	},
	
	xmiImport: function(doc, editor) {
		var packages = {};
		var classes = {};
		var associations = {};
		var connectors = {};

		// collect associations
		var oMembers = doc.getElementsByTagName("ownedMember");
		for(var i = 0; i < oMembers.length; i++) {
			if (this._isAssociation(oMembers[i])) {
				var associationId = oMembers[i].getAttribute("xmi:id");
				var isTgtDependency = oMembers[i].getElementsByTagName("ownedEnd").length > 0;
				var associationName = this._fromXML(oMembers[i].getAttribute("name"));
				associations[associationId] = {
					isTgtDependency: isTgtDependency,
					name: associationName};
			}
		}

		// collect packages, classes and connectors
		for(var i = 0; i < oMembers.length; i++) {
			
			if (this._isPackage(oMembers[i])) {
				
				var packageId = oMembers[i].getAttribute("xmi:id");
				var packageName = this._fromXML(oMembers[i].getAttribute("name"));
				packages[packageId] = {packageName: packageName};
				
			} else if (this._isClass(oMembers[i])) {
				
				var classId = oMembers[i].getAttribute("xmi:id");
				var className = this._fromXML(oMembers[i].getAttribute("name"));
				classes[classId] = {className: className, attributes: [], operations: []};
				
				var generalizations = oMembers[i].getElementsByTagName("generalization");
				for( var j = 0; j < generalizations.length; j++) {
					var gId = generalizations[j].getAttribute("xmi:id");
					var general = generalizations[j].getAttribute("general");
					
					connectors[gId] = {
						srcId: general, 
						tgtId: classId, 
						type: diagram.uml.generalization};
				}
				
				var attrCounter = 0;
				var opCounter = 0;
				var oAttributes = oMembers[i].getElementsByTagName("ownedAttribute");
				for( var j = 0; j < oAttributes.length; j++) {
					if (this._isAssociationAttribute(oAttributes[j])) {
						// the attribute is actually an association
						
						var associationId = oAttributes[j].getAttribute("association");
						var aggregationType = oAttributes[j].getAttribute("aggregation");
						var tgtId = oAttributes[j].getAttribute("type");
						var isTgtDependency = associations[associationId].isTgtDependency;
						var associationName = associations[associationId].name;
						
						var type = null;
						if (aggregationType == "shared") {
							if (isTgtDependency) {
								type = diagram.uml.directedAggregation;
							} else {
								type = diagram.uml.aggregation;
							}
						} else if (aggregationType == "composite") {
							if (isTgtDependency) {
								type = diagram.uml.directedComposition;
							} else {
								type = diagram.uml.composition;
							}
						} else {
							if (isTgtDependency) {
								type = diagram.uml.directedAssociation;
							} else {
								type = diagram.uml.association;
							}
						}

						if (connectors[associationId] == null || 
							type != diagram.uml.association) {
							connectors[associationId] = {
								srcId: classId, 
								tgtId: tgtId, 
								type: type,
								centerText: associationName};
						}
					} else {
						// the attribute is a real attribute
						
						var attrName = this._fromXML(oAttributes[j].getAttribute("name"));
						var attrVisibility = oAttributes[j].getAttribute("visibility");
						var defaultValue;
						
						var oaDefaultValues = oAttributes[j].getElementsByTagName("defaultValue");
						for(var k = 0; k < oaDefaultValues.length; k++) {
							defaultValue = this._fromXML(oaDefaultValues[k].getAttribute("value"));
						}
						
						classes[classId].attributes[attrCounter++] = {
							"Visibility": this._textToVisibility(attrVisibility),
							"Name": attrName,
							"DefaultValue": defaultValue};
					}
				}
				
				var oOperations = oMembers[i].getElementsByTagName("ownedOperation");
				for( var j = 0; j < oOperations.length; j++) {
					var opIsAbstract = oOperations[j].getAttribute("isAbstract");
					var opIsStatic = oOperations[j].getAttribute("isStatic");
					var opName = this._fromXML(oOperations[j].getAttribute("name"));
					var opVisibility = oOperations[j].getAttribute("visibility");
					
					classes[classId].operations[opCounter++] = {
						"Visibility": this._textToVisibility(opVisibility),
						"Name": opName,
						"IsAbstract": (opIsAbstract == "true" ? "Abstract" : undefined),
						"IsStatic": (opIsStatic == "true" ? "Static" : undefined)};
				}
				
			}
		}
		
		var wuPackages = doc.getElementsByTagName("wuPackage");
		for(var i = 0; i < wuPackages.length; i++) {
			
			var packageId = wuPackages[i].getAttribute("xmi:id");
			var bb = wuPackages[i].getAttribute("boundingBox");
			var rect = dojo.json.evalJson(bb);
			packages[packageId].rect = rect;
			
		}

		var wuClasses = doc.getElementsByTagName("wuClass");
		for(var i = 0; i < wuClasses.length; i++) {

			var classId = wuClasses[i].getAttribute("xmi:id");
			var bb = wuClasses[i].getAttribute("boundingBox");
			var rect = dojo.json.evalJson(bb);
			classes[classId].rect = rect;
			
		}
		
		var wuConnectors = doc.getElementsByTagName("wuConnector");
		for(var i = 0; i < wuConnectors.length; i++) {

			var connectorId = wuConnectors[i].getAttribute("xmi:id");
			
			connectors[connectorId].sourcePosition = wuConnectors[i].getAttribute("sourcePosition");
			connectors[connectorId].sourceBias = wuConnectors[i].getAttribute("sourceBias");
			connectors[connectorId].targetPosition = wuConnectors[i].getAttribute("targetPosition");
			connectors[connectorId].targetBias = wuConnectors[i].getAttribute("targetBias");
			connectors[connectorId].sourceText = wuConnectors[i].getAttribute("sourceText");
			connectors[connectorId].targetText = wuConnectors[i].getAttribute("targetText");
			
			var centerText = wuConnectors[i].getAttribute("centerText");
			if (centerText && centerText.length > 0) {
				connectors[connectorId].centerText = centerText;
			}
			
		}

		for(var x in packages) {
			var rect;
			if (packages[x].rect) {
				rect = packages[x].rect;
			} else {
				rect = {x: 10, y: 10, width: 100, height: 50}
			}
			
			var p = diagram.uml.addPackage(
				editor, 
				packages[x].packageName, 
				rect);
			packages[x].packageShape = p;
		}
		
		for(var x in classes) {
			var rect;
			if (classes[x].rect) {
				rect = classes[x].rect;
			} else {
				rect = {x: 10, y: 10, width: 100, height: 50}
			}

			var c = diagram.uml.addClass(
				editor, 
				classes[x].className, 
				rect);
			c.setAttributes(classes[x].attributes);
			c.setOperations(classes[x].operations);
			classes[x].classShape = c;
		}
		
		for(var x in connectors) {
			var src = classes[connectors[x].srcId].classShape;
			var tgt = classes[connectors[x].tgtId].classShape;
			if (!src || !tgt) {
				dojo.debug("connector does not have src or tgt");
				continue;
			}
			
			var type = connectors[x].type;

			var c = diagram.uml.addConnector(editor, type, src, tgt);
			 
			if (connectors[x].sourcePosition) {
				c.sourcePosition = connectors[x].sourcePosition;
			}
			if (connectors[x].sourceBias) {
			    c.sourceBias = connectors[x].sourceBias;
			}
			if (connectors[x].targetPosition) {
				c.targetPosition = connectors[x].targetPosition;
			}
			if (connectors[x].targetBias) {
				c.targetBias = connectors[x].targetBias;
			}
			 
			if (connectors[x].sourceText) {
			 	c.setSourceText(connectors[x].sourceText);
			}
			if (connectors[x].centerText) {
			 	c.setCenterText(connectors[x].centerText);
			}
			if (connectors[x].targetText) {
			 	c.setTargetText(connectors[x].targetText);
			}
			 
			c.updatePosition();
		}
	},
	
	_isPackage: function(oMember) {
		var omAttributes = oMember.attributes;
		
		for(var i = 0; i < omAttributes.length; i++) {
			if (omAttributes[i].nodeName == "xmi:type" && omAttributes[i].nodeValue == "uml:Package") {
				return true;
			}
		}
		
		return false;
	},
	
	_isClass: function(oMember) {
		var omAttributes = oMember.attributes;
		
		for(var i = 0; i < omAttributes.length; i++) {
			if (omAttributes[i].nodeName == "xmi:type" && omAttributes[i].nodeValue == "uml:Class") {
				return true;
			}
			// TODO: interfaces are treated like if they were classes
			if (omAttributes[i].nodeName == "xmi:type" && omAttributes[i].nodeValue == "uml:Interface") {
				return true;
			}
		}
		
		return false;
	},
	
	_isAssociation: function(oMember) {
		var omAttributes = oMember.attributes;
		
		for(var i = 0; i < omAttributes.length; i++) {
			if (omAttributes[i].nodeName == "xmi:type" && omAttributes[i].nodeValue == "uml:Association") {
				return true;
			}
		}
		
		return false;
	},

	_isAssociationAttribute: function(oAttribute) {
		return oAttribute.getAttribute("association") != null;
	},

	_navigate: function(node) {
		dojo.debug(node);
		
		for(var i = 0; i < node.childNodes.length; i++) {
			this._navigate(node.childNodes[i]);
		}
	},
	
	xmiExport: function(editor) {
		var shapes = editor.getShapes();
		
		var doc = "<?xml version='1.0' encoding='UTF-8'?>\n";
		doc += "<xmi:XMI xmi:version='2.1' xmlns:uml='http://schema.omg.org/spec/UML/2.0' xmlns:xmi='http://schema.omg.org/spec/XMI/2.1'>\n";
		doc += "\t<xmi:Documentation xmi:Exporter='Web20UML' xmi:ExporterVersion='1.0'/>\n";
		doc += "\t<uml:Model xmi:id='1' name='Data' visibility='public'>\n";

		// evaluate packages
		var packages = {};
		for(shapeId in shapes) {
			var shape = shapes[shapeId];
			if (shape instanceof diagram.uml.Package) {
				packages[shapeId] = {
					model: 
						"\t\t<ownedMember xmi:type='uml:Package' xmi:id='" + 
						shapeId + "' name='" + this._toXML(shape.packageName) + 
						"' visibility='public'>\n",
					extension: 
						"\t\t<wuPackage xmi:id='" + shapeId + "' boundingBox='" + 
						dojo.json.serialize(shape.getBoundingBox()) + "'/>\n"};
			}
		}

		// evaluate classes
		var classes = {};
		for(shapeId in shapes) {
			var shape = shapes[shapeId];
			if (shape instanceof diagram.uml.Class) {
				classes[shapeId] = {
					model: 
						"\t\t<ownedMember xmi:type='uml:Class' xmi:id='" + 
						shapeId + "' name='" + this._toXML(shape.className) + 
						"' visibility='public'>\n",
					extension: 
						"\t\t<wuClass xmi:id='" + shapeId + "' boundingBox='" + 
						dojo.json.serialize(shape.getBoundingBox()) + "'/>\n"};
				
				this._attributesToXMI(shape, shapeId, classes[shapeId]);
				this._operationsToXMI(shape, shapeId, classes[shapeId])
			}
		}
		
		// evaluate connectors
		var connectors = {};
		for(shapeId in shapes) {
			var shape = shapes[shapeId];
			if (shape instanceof diagram.uml.Connector) {
				connectors[shapeId] = {
					model: this._connectorToXMI(
						shapeId, classes, 
						shape.srcConnectorArrow, 
						shape.tgtConnectorArrow,
						shape.sourceShape, 
						shape.targetShape,
						shape.centerText),
					extension: 
						"\t\t<wuConnector xmi:id='" + shapeId + 
						".association' sourcePosition='" + shape.sourcePosition +
						"' sourceBias='" + shape.sourceBias +
						"' targetPosition='" + shape.targetPosition +
						"' targetBias='" + shape.targetBias +
						"' sourceText='" + shape.sourceText +
						"' centerText='" + shape.centerText +
						"' targetText='" + shape.targetText + "'/>\n" };
			}
		}
		
		for(x in packages) {
			doc += packages[x].model + "\t\t</ownedMember>\n";
		}
		for(x in classes) {
			doc += classes[x].model + "\t\t</ownedMember>\n";
		}
		for(x in connectors) {
			doc += connectors[x].model;
		}
		
		doc += "\t</uml:Model>\n";


		doc += "\t<uml:Extension xmi:Extender='Web20UML 1.0'>\n";
		
		for(x in packages) {
			doc += packages[x].extension;
		}
		for(x in classes) {
			doc += classes[x].extension;
		}
		for(x in connectors) {
			doc += connectors[x].extension;
		}

		doc += "\t</uml:Extension>\n";
		
		doc += "</xmi:XMI>\n";

		return doc;		
	},
	
	_toXML: function(text) {
		if (text) {
			text = text.replace(/</g, "&lt;");
			text = text.replace(/>/g, "&gt;");
		}
		
		return text;
	},
	
	_fromXML: function(text) {
		if (text) {
			text = text.replace(/&lt;/g, "<");
			text = text.replace(/&gt;/g, ">");
		}
		
		return text;
	},
	
	_attributesToXMI: function(aClass, shapeId, aClassXMI) {
		var xmiElement = aClassXMI.model;
		
		for(x in aClass.attributes) {
			var attr = aClass.attributes[x];
			
			xmiElement += "\t\t\t<ownedAttribute xmi:type='uml:Property' xmi:id='" +
				shapeId + ".attr." + x + "' name='" + this._toXML(attr.Name) + "' visibility='" +
				this._visibilityToText(attr.Visibility) + "'>\n";
				
			if (attr.DefaultValue) {
				xmiElement += "\t\t\t\t<defaultValue xmi:type='uml:LiteralString' xmi:id='" + 
				shapeId + ".attr." + x + ".0' value='" + this._toXML(attr.DefaultValue) + "' visibility='public'/>\n";
				
			}
			
			xmiElement += "\t\t\t</ownedAttribute>\n";
		}
		
		aClassXMI.model = xmiElement;
	},

	_operationsToXMI: function(aClass, shapeId, aClassXMI) {
		var xmiElement = aClassXMI.model;
		
		for(x in aClass.operations) {
			var op = aClass.operations[x];
			
			xmiElement += "\t\t\t<ownedOperation xmi:type='uml:Operation' xmi:id='" +
				shapeId + ".op." + x + "' isAbstract='" + (op.IsAbstract != undefined) + 
				"' isStatic='" + (op.IsStatic != undefined) +
				"' name='" + this._toXML(op.Name) + "' visibility='" +
				this._visibilityToText(op.Visibility) + "'/>\n";
		}
		
		aClassXMI.model = xmiElement;
	},
	
	_visibilityToText: function(visibility) {
		if (visibility == "-") {
			return "private";
		} else if (visibility == "~") {
			return "package";
		} else if (visibility == "#") {
			return "protected";
		} else {
			return "public";
		}
	},
	
	_textToVisibility: function(text) {
		if (text == "private") {
			return "-";
		} else if (text == "package") {
			return "~";
		} else if (text == "protected") {
			return "#";
		} else {
			return "+";
		}
	},
		
	_connectorToXMI: function(shapeId, classes, srcArrow, tgtArrow, src, tgt, centerText) {
		var doc = "";
		
		var srcShapeId = diagram.editor.getShapeId(src);
		var tgtShapeId = diagram.editor.getShapeId(tgt);
		var srcXMIElement = classes[srcShapeId].model;
		var tgtXMIElement = classes[tgtShapeId].model;
		
		if (srcArrow == diagram.uml.generalizationArrow) {

			tgtXMIElement += "\t\t\t<generalization xmi:type='uml:Generalization' xmi:id='" + 
				shapeId + ".association' general='" + srcShapeId + "'/>\n";

		} else {
			
			doc += this._getAssociation(
				shapeId, srcShapeId, tgtShapeId, tgtArrow, centerText);
			srcXMIElement += this._getSrcXMIElement(
				shapeId, srcShapeId, tgtShapeId, srcArrow);
			tgtXMIElement += this._getTgtXMIElement(
				shapeId, srcShapeId, tgtShapeId, tgtArrow);
			
		}
		
		classes[srcShapeId].model = srcXMIElement;
		classes[tgtShapeId].model = tgtXMIElement;
		
		return doc;
	},
	
	_getAssociation: function(shapeId, srcShapeId, tgtShapeId, tgtArrow, centerText) {
		var doc = "";
		
		doc += "\t\t<ownedMember xmi:type='uml:Association' xmi:id='" + shapeId + ".association' visibility='public'";
		if (centerText && centerText.length > 0) {
			doc += " name='" + centerText + "'";
		}
		doc += ">\n";
		doc += "\t\t\t<memberEnd xmi:idref='" + srcShapeId + "." + shapeId + ".association'/>\n";
		doc += "\t\t\t<memberEnd xmi:idref='" + tgtShapeId + "." + shapeId + ".association'/>\n";
		
		if (tgtArrow == diagram.uml.dependencyArrow) {
			doc += "\t\t\t<ownedEnd xmi:type='uml:Property' xmi:id='" + tgtShapeId + "." + shapeId +
				".association' visibility='private' association='" + shapeId + 
				".association' type='" + srcShapeId + "'/>\n";
		}
		
		doc += "\t\t</ownedMember>\n";
		
		return doc;
	},
	
	_getSrcXMIElement: function(shapeId, srcShapeId, tgtShapeId, srcArrow) {
		var srcXMIElement = "";
		
		srcXMIElement += "\t\t\t<ownedAttribute xmi:type='uml:Property' xmi:id='" + srcShapeId + "." + shapeId +
			".association' ";
			
		if (srcArrow == diagram.uml.aggregationArrow) {
			srcXMIElement += "aggregation='shared' ";
		} else if (srcArrow == diagram.uml.compositionArrow) {
			srcXMIElement += "aggregation='composite' ";
		}
		
		srcXMIElement += "visibility='private' association='" + shapeId + 
			".association' type='" + tgtShapeId + "'/>\n";
		
		return srcXMIElement;
	},
	
	_getTgtXMIElement: function(shapeId, srcShapeId, tgtShapeId, tgtArrow) {
		var tgtXMIElement = "";

		if (tgtArrow == null) {
			tgtXMIElement += "\t\t\t<ownedAttribute xmi:type='uml:Property' xmi:id='" + tgtShapeId + "." + shapeId +
				".association' visibility='private' association='" + shapeId +
				".association' type='" + srcShapeId + "'/>\n";
		}
		
		return tgtXMIElement;
	}
});
