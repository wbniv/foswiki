/*--------------------------------------------------|
| dTree 2.05 | www.destroydrop.com/javascript/tree/ |
|---------------------------------------------------|
| Copyright (c) 2002-2003 Geir Landrö               |
| Copyright (c) 2006-2007 Stéphane Lenclud          |
|                                                   |
|                                                   |
| This script can be used freely as long as all     |
| copyright messages are intact.                    |
|                                                   |
| Updated: 17.04.2003                               |
| Updated: 04 Sep 2005 Thomas Weigert               |
|--------------------------------------------------*/

// Node object
function Node(id, pid, name, url, title, target, icon, iconOpen, open) {
	this.id = id;
	this.pid = pid; //parent id
	this.name = name;
	this.url = url;
	this.title = title;
	this.target = target;
	this.icon = icon;
	this.iconOpen = iconOpen;
	this._io = open || false; //SL: meens "is open".
	this._is = false; //SL: meens "is select"? Not used in by TreeBrowserPlugin.
	this._ls = false; //SL: meens "last sibling"
	this._hc = false; //SL: meens "have children". 
	this._ai = 0;
	this._p;
    this.level = 0; //Depth in the tree, 0 == root, 1 == first level...
};

// Action object, associate an HTML event with a dTree function e.g. onclick/o
function Action(event, func) {
	this.event = event; // an html event e.g. onclick, onmouseover.
	this.func = func; // a dTree function e.g. o, openTo.
};

// Tree object
function dTree(objName) {
	this.config = {
		target	: null,
		folderLinks : true,
		useSelection : true,
		useCookies : true,
		useLines : true,
		usePlusMinus : true,
        noIndent : false,
        noRoot : false,
		useIcons : true,
		useStatusText : false,
		closeSameLevel	: false,
		inOrder	: false,
		iconPath : '',
		shared : false,
        style : 'dtree', //The CSS filename
        autoToggle : false, //Clicking on a node itself will open/close that node, rename activeNode?
        popup : false, //Popup menu style
        closePopupDelay : 1000, //Delay before closing all popup
        popupOffset : {'x':0, 'y':0}, //Allow fine tunning of popup position, in pixel
        firstPopupOffset : {'x':0, 'y':0}, //Allow fine tunning of first popup position, in pixel
        useOpacity : false //Allow fine tunning of first popup position, in pixel        
	};
	this.icon = {
	  root : 'base.gif',
	  folder : 'folder.gif',
	  folderOpen : 'folderopen.gif',
	  node	: 'page.gif',
	  empty	: 'empty.gif',
	  line	: 'line.gif',
	  join	: 'join.gif',
	  joinBottom : 'joinbottom.gif',
	  plus	: 'plus.gif',
	  plusBottom : 'plusbottom.gif',
	  minus : 'minus.gif',
	  minusBottom : 'minusbottom.gif',
	  nlPlus : 'nolines_plus.gif',
	  nlMinus : 'nolines_minus.gif'
	};
	this.obj = objName;
	this.aNodes = [];
	this.aNodeActions = [];
	this.aIndent = [];
	this.root = new Node(-1);
	this.selectedNode = null;
	this.selectedFound = false;
	this.completed = false;
	this.level = -1; //The current depth of the tree, -1==Not rendering, 0==root  
    this.debug = 1;
    this.popupTimeout = 0;
};

// Must be called if iconPath was changed
dTree.prototype.updateIconPath = function() {
	this.icon = {
	  root : this.config.iconPath + 'base.gif',
	  folder : this.config.iconPath + 'folder.gif',
	  folderOpen : this.config.iconPath + 'folderopen.gif',
	  node	: this.config.iconPath + 'page.gif',
	  empty	: this.config.iconPath + 'empty.gif',
	  line	: this.config.iconPath + 'line.gif',
	  join	: this.config.iconPath + 'join.gif',
	  joinBottom : this.config.iconPath + 'joinbottom.gif',
	  plus	: this.config.iconPath + 'plus.gif',
	  plusBottom : this.config.iconPath + 'plusbottom.gif',
	  minus : this.config.iconPath + 'minus.gif',
	  minusBottom : this.config.iconPath + 'minusbottom.gif',
	  nlPlus : this.config.iconPath + 'nolines_plus.gif',
	  nlMinus : this.config.iconPath + 'nolines_minus.gif'
	};
};

// Adds a new action to the node actions array
dTree.prototype.addAction = function(event, func) {
	this.aNodeActions[this.aNodeActions.length] = new Action(event, func);
};

// Adds a new node to the node array
dTree.prototype.add = function(id, pid, name, url, title, target, icon, iconOpen, open) {
	this.aNodes[this.aNodes.length] = new Node(id, pid, name, url, title, target, icon, iconOpen, open);
};

// Open/close all nodes
dTree.prototype.openAll = function() {
	this.oAll(true);
};

dTree.prototype.closeAll = function() {
	this.oAll(false);
};

// Outputs the tree to the page
dTree.prototype.toString = function() {
	var str = '<div class="'+ this.getClassTree() + '">\n';
	if (document.getElementById) {
		if (this.config.useCookies) this.selectedNode = this.getSelected();
      //SL: add the root node
		str += this.addNode(this.root);
	} else str += 'Browser not supported.';
	str += '</div>';
	if (!this.selectedFound) this.selectedNode = null;
	this.completed = true;
	return str;
};

// Creates the tree structure
dTree.prototype.addNode = function(pNode) {
	var str = '';
	var n=0;
   this.level++; //increment level
	if (this.config.inOrder) n = pNode._ai;
   //SL: for each children
	for (n; n<this.aNodes.length; n++) {	
		if (this.aNodes[n].pid == pNode.id) { //SL: Testing if node n is a child of pNode
			var cn = this.aNodes[n];
			cn._p = pNode;
			cn._ai = n;
			this.setCS(cn);
			if (!cn.target && this.config.target) cn.target = this.config.target;
			if (cn._hc && !cn._io && this.config.useCookies) cn._io = this.isOpen(cn.id);
			if (!this.config.folderLinks && cn._hc) cn.url = null;
			if (this.config.useSelection && cn.id == this.selectedNode && !this.selectedFound) {
					cn._is = true;
					this.selectedNode = n;
					this.selectedFound = true;
			}
         //SL: render this node
            cn.level = this.level; //Set node level first
			str += this.node(cn, n);
			if (cn._ls) break;
		}
	}
   this.level--; //decrement level
	return str;
};

// Creates the node icon, url and text
dTree.prototype.node = function(node, nodeId) {
   var isRoot = (this.root.id == node.pid)?true:false; //Check if we are dealing with the tree root
	//Set icons according to config and properties
	if (this.config.useIcons) {
		if (!node.icon) node.icon = (this.root.id == node.pid) ? this.icon.root : ((node._hc) ? this.icon.folder : this.icon.node);
		if (!node.iconOpen) node.iconOpen = (node._hc) ? this.icon.folderOpen : this.icon.node;
		if (isRoot) {
			node.icon = this.icon.root;
			node.iconOpen = this.icon.root;
		}
	}
	var str = '';
	//SL: Render node icon and text unless it's the root of the tree and noroot specified
	if (!isRoot || (isRoot && !this.config.noRoot))	{
      var myClass='';
      var nodeScript='';  
      //SL: Set the node class & actions: 
      //If the node has children then it's either opened or closed
      //If the node has no children then it's a leaf
        if (node._hc) {
            (node._io ? myClass = this.getClassNodeOpened() : myClass = this.getClassNodeClosed());
            if (this.config.autoToggle){
                if (!(this.aNodeActions.length>0)) {
                    //No specific actions defined, default is click for toggle
                    nodeScript= 'onclick="javascript: ' + this.obj + '.o(' + nodeId + ');"';
                }
                else {
                    //Build the event script according the defined actions
                    for (var n=0; n<this.aNodeActions.length; n++)
                        nodeScript+= this.aNodeActions[n].event + '="javascript: ' + this.obj + '.' + this.aNodeActions[n].func + '(' + nodeId + ');" ';
                }
            }; //alert(\'debug\');  
        }
        else {
            myClass = this.getClassLeaf();
            if (this.config.popup) {
                //Make sure hovering over a leaf closes level sub-menu
                nodeScript='onmouseover="javascript: ' + this.obj + '.closeAllChildren(' + this.obj +'.aNodes['+node.pid+']);"';
            }
        }
        if (isRoot) {myClass += ' ' + this.getClassRoot();}
		str += '<div id="n' + this.obj + nodeId + '" class="'+ myClass +'" '+ nodeScript + '>' + this.indent(node, nodeId);
		if (this.config.useIcons) str += '<img id="i' + this.obj + nodeId + '" src="' + ((node._io) ? node.iconOpen : node.icon) + '" alt="" />';
		//str += (node.name + this.level); //Debug level
        str += node.name;
		str += '</div>';
       
	}
	
   //SL: If the node has children, create <div> for children encapsulation
	if (node._hc) {
      //SL: Display that group of children if this node is root OR this node is open BUT NOT in popup menu style.   
      //We also add automatic popup closing functionality for popup menu using timeout
      str += '<div id="d' + this.obj + nodeId + '" class="'+ this.getClassChildren() + ' ' + this.getClassLevel() + '" style="display:' + ((isRoot || (node._io && !this.config.popup )) ? 'block' : 'none') + ';" ' + (this.config.popup? 'onmouseout="javascript: clearTimeout('+ this.obj +'.popupTimeout);' + this.obj + '.popupTimeout=setTimeout(\''+ this.obj +'.oAll(false)\',' + this.config.closePopupDelay + ');" onmouseover="clearTimeout('+ this.obj +'.popupTimeout);"' : '') + '>';
        //Same as above line but with debug output built-in
        //str += '<div id="d' + this.obj + nodeId + '" class="'+ this.getClassChildren() + ' ' + this.getClassLevel() + '" style="display:' + ((isRoot || (node._io && !this.config.popup )) ? 'block' : 'none') + ';" ' + (this.config.popup? 'onmouseout="javascript: writeDebug(\'onmouseout:' + this.obj + ' \');clearTimeout('+ this.obj +'.popupTimeout);' + this.obj + '.popupTimeout=setTimeout(\''+ this.obj +'.oAll(false)\',' + this.config.closePopupDelay + ');" onmouseover="javascript: writeDebug(\'onmouseover:' + this.obj + ' \');clearTimeout('+ this.obj +'.popupTimeout);"' : '') + '>';
    	str += this.addNode(node);
		str += '</div>';


        //Here comes a trick to have opaque text on translucent background
        if (this.config.useOpacity)
            {
            str += '<div id="dbkg' + this.obj + nodeId + '" class="'+ this.getClassTranslucentBackground() + ' ' + this.getClassLevel() +'" style="display:none;">';
		    str += this.fakeChildren(node);
            str += '</div>';            
            }

	}
	this.aIndent.pop();
	return str;
};

// Adds the empty and line icons
dTree.prototype.indent = function(node, nodeId) {
   var str = '';
   if (this.config.noIndent) return str;
	if (this.root.id != node.pid) {
		for (var n=0; n<this.aIndent.length; n++)
			str += '<img src="' + ( (this.aIndent[n] == 1 && this.config.useLines) ? this.icon.line : this.icon.empty ) + '" alt="" />';
		(node._ls) ? this.aIndent.push(0) : this.aIndent.push(1);
		if (node._hc) {
         if (!this.config.usePlusMinus) 
            { //Just indent without + or - icon      
            str += '<img src="' + ( (this.aIndent[n] == 1 && this.config.useLines) ? this.icon.line : this.icon.empty ) + '" alt="" />';
            return str;
            }
			str += '<a href="javascript: ' + this.obj + '.o(' + nodeId + ');"><img id="j' + this.obj + nodeId + '" src="';
			if (!this.config.useLines) str += (node._io) ? this.icon.nlMinus : this.icon.nlPlus;
			else str += ( (node._io) ? ((node._ls && this.config.useLines) ? this.icon.minusBottom : this.icon.minus) : ((node._ls && this.config.useLines) ? this.icon.plusBottom : this.icon.plus ) );
			str += '" alt="" /></a>';
		} else str += '<img src="' + ( (this.config.useLines) ? ((node._ls) ? this.icon.joinBottom : this.icon.join ) : this.icon.empty) + '" alt="" />';
	}
	return str;
};

// Checks if a node has any children and if it is the last sibling
dTree.prototype.setCS = function(node) {
	var lastId;
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.id) node._hc = true;
		if (this.aNodes[n].pid == node.pid) lastId = this.aNodes[n].id;
	}
	if (lastId==node.id) node._ls = true;
};

// Returns the selected node
dTree.prototype.getSelected = function() {
	var sn = this.getCookie('cs' + this.obj);
	return (sn) ? sn : null;
};

// Highlights the selected node
dTree.prototype.s = function(id) {
	if (!this.config.useSelection) return;
	var cn = this.aNodes[id];
	if (cn._hc && !this.config.folderLinks) return;
	if (this.selectedNode != id) {
		if (this.selectedNode || this.selectedNode==0) {
			eOld = document.getElementById("s" + this.obj + this.selectedNode);
			eOld.className = "node";
		}
		eNew = document.getElementById("s" + this.obj + id);
		eNew.className = "nodeSel";
		this.selectedNode = id;
		if (this.config.useCookies) this.setCookie('cs' + this.obj, cn.id);
	}
};

// Toggle Open or close, synonym
dTree.prototype.toggle = function(id) {
    this.o(id);
};

// Opens a node, synonym
dTree.prototype.open = function(id) {
	var cn = this.aNodes[id];
	this.nodeStatus(true, id, cn._ls);
	cn._io = true;
	if (this.config.closeSameLevel) this.closeLevel(cn);
	if (this.config.useCookies) this.updateCookie();
};

// Closes a node, synonym
dTree.prototype.close = function(id) {
	var cn = this.aNodes[id];
	this.nodeStatus(false, id, cn._ls);
	cn._io = false;
	if (this.config.closeSameLevel) this.closeLevel(cn);
	if (this.config.useCookies) this.updateCookie();
};

// Toggle Open or close
dTree.prototype.o = function(id) {
	var cn = this.aNodes[id];
	this.nodeStatus(!cn._io, id, cn._ls);
	cn._io = !cn._io;
	if (this.config.closeSameLevel) this.closeLevel(cn);
	if (this.config.useCookies) this.updateCookie();
};

// Open or close all nodes
dTree.prototype.oAll = function(status) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n]._hc && this.aNodes[n].pid != this.root.id) { //org
			this.nodeStatus(status, n, this.aNodes[n]._ls); //org
			this.aNodes[n]._io = status; //org
		}
	}
	if (this.config.useCookies) this.updateCookie();
};

// Opens the tree to a specific node
dTree.prototype.openTo = function(nId, bSelect, bFirst) {
	if (!bFirst) {
		for (var n=0; n<this.aNodes.length; n++) {
			if (this.aNodes[n].id == nId) {
				nId=n;
				break;
			}
		}
	}
	var cn=this.aNodes[nId];
	if (cn.pid==this.root.id || !cn._p) return;
	cn._io = true;
	cn._is = bSelect;
	if (this.completed && cn._hc) this.nodeStatus(true, cn._ai, cn._ls);
	if (this.completed && bSelect) this.s(cn._ai);
	else if (bSelect) this._sn=cn._ai;
	this.openTo(cn._p._ai, false, true);
};

// Closes all nodes on the same level as certain node
dTree.prototype.closeLevel = function(node) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.pid && this.aNodes[n].id != node.id && this.aNodes[n]._hc) {
			this.nodeStatus(false, n, this.aNodes[n]._ls);
			this.aNodes[n]._io = false;
			this.closeAllChildren(this.aNodes[n]);
		}
	}
}// Closes all children of a node
dTree.prototype.closeAllChildren = function(node) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.id && this.aNodes[n]._hc) {
			if (this.aNodes[n]._io) this.nodeStatus(false, n, this.aNodes[n]._ls);			
            //this.nodeStatus(false, n, this.aNodes[n]._ls);
            this.aNodes[n]._io = false;
			this.closeAllChildren(this.aNodes[n]);		
		}
	}
}

// Change the status of a node(open or closed)
dTree.prototype.nodeStatus = function(status, id, bottom)
    {
	eDiv	= document.getElementById('d' + this.obj + id);
    var eDivBkg;
    if (this.config.useOpacity)
        {
    	eDivBkg	= document.getElementById('dbkg' + this.obj + id);
        }
    var eJoin;
    if (this.config.usePlusMinus) eJoin	= document.getElementById('j' + this.obj + id);
	if (this.config.useIcons) 
        {
		eIcon	= document.getElementById('i' + this.obj + id);
		eIcon.src = (status) ? this.aNodes[id].iconOpen : this.aNodes[id].icon;
	    }
    if (this.config.usePlusMinus) eJoin.src = (this.config.useLines)?
	((status)?((bottom)?this.icon.minusBottom:this.icon.minus):((bottom)?this.icon.plusBottom:this.icon.plus)):
	((status)?this.icon.nlMinus:this.icon.nlPlus);
    //eDiv.style.display = (status) ? 'block': 'none'; //was there, moved to the end coz IE rendering is too slow
    //SL: Change the class of the node div
    var nodeIdString = 'n' + this.obj + id; 
    var eNodeDiv = document.getElementById('n' + this.obj + id);
    eNodeDiv.className = (status) ? this.getClassNodeOpened() : this.getClassNodeClosed();
    var isRoot=(this.root.id == this.aNodes[id].pid);
    if (isRoot) { eNodeDiv.className += ' ' + this.getClassRoot(); } //Add root class to the root 

    // Set position for popup menu
    if (this.config.popup && status && !isRoot)
        {    
        //TODOs: Decide which position API to use and move them to JavaScriptPlugin. extend HTMLElement class
        //If level>1 it means that we are dealing with a submenu i.e. a child from a popup menu
        if (this.aNodes[id].level>1)
            {
            //Submenu for non IE browser
            eDiv.style.position = 'absolute';
            eDiv.style.left = eNodeDiv.offsetLeft + eNodeDiv.offsetWidth + this.config.popupOffset.x + 'px'; 
            eDiv.style.top = eNodeDiv.offsetTop + this.config.popupOffset.y + 'px';    
            if (this.config.useOpacity && eDivBkg) 
                {
                eDivBkg.style.position = 'absolute';
                eDivBkg.style.left = eNodeDiv.offsetLeft + eNodeDiv.offsetWidth + this.config.popupOffset.x + 'px'; 
                eDivBkg.style.top = eNodeDiv.offsetTop + this.config.popupOffset.y + 'px';    
                }
            }
        else 
            {
            //Position first level of popup menu
            var nodePos = Position.get(eNodeDiv); //That API is slow especially with IE, consider using getAbsoluteLeft and getAbsoluteTop instead     
            eDiv.style.position = 'absolute';
            eDiv.style.left = nodePos.left + nodePos.width + this.config.popupOffset.x + this.config.firstPopupOffset.x + 'px';
            eDiv.style.top = nodePos.top + this.config.popupOffset.y + this.config.firstPopupOffset.y +'px';
            if (this.config.useOpacity && eDivBkg) 
                {
                eDivBkg.style.position = 'absolute';
                eDivBkg.style.left = nodePos.left + nodePos.width + this.config.popupOffset.x + this.config.firstPopupOffset.x + 'px';
                eDivBkg.style.top = nodePos.top + this.config.popupOffset.y + this.config.firstPopupOffset.y +'px';
                }
            }

            /*        
        if (writeDebug)
            {
            showDebug();
            writeDebug(navigator.appName);         
            }    
            */
        }
    
    //Do that last, hide and show the children div TODO: should really hide at the beginning if needed.     
    if (navigator.appName=='Microsoft Internet Explorer' && this.config.popup)
        {
        //This pile of over complicated code is IE specific
        //It was implemented to workaround IE problems with display:none property in submenus.     
        //So instead of hidding element using the display property we just set their x coordinate to something off the screen
        if (!status)
            {
            eDiv.style.left="100000px"; //send it to hell
            }
        else
            {
       	    eDiv.style.display = 'block';
            }

        if (this.config.useOpacity && eDivBkg) 
            {
            if (!status)
                {
                eDivBkg.style.left="100000px"; //send it to hell
                this.setChildrenDisplay(eDivBkg,'none');        
                }
            else
                {
       	        eDivBkg.style.display = 'block';
                this.setChildrenDisplay(eDivBkg,'block');                
                }
            }
        }
    else
        {
        //Non IE nice and easy :)
  	    eDiv.style.display = (status) ? 'block': 'none'; //TODO: should really hide at the beginning if needed.
        if (this.config.useOpacity && eDivBkg) 
            {
            var styleDisplay=(status) ? 'block': 'none';
      	    eDivBkg.style.display = styleDisplay; //TODO: should really hide at the beginning if needed.
            this.setChildrenDisplay(eDivBkg,styleDisplay); //IE Debug: Doing this prevents the need to have FakeItem set to display:block in CSS
            }
        }
        
    //Closes submenu when going back one level
    if (this.config.popup)
        {
        this.closeAllChildren(this.aNodes[id]);
        }
    };

dTree.prototype.onload = function() {
/*
    //Just an idea
    if (this.config.useOpacity)
        {
    	eDivBkg	= document.getElementById('dbkg' + this.obj + '0');
    	eDiv	= document.getElementById('d' + this.obj + '0');
        }
*/
    //foswiki.js addLoadEvent
};

// [Cookie] Clears a cookie
dTree.prototype.clearCookie = function() {
	var now = new Date();
	var yesterday = new Date(now.getTime() - 1000 * 60 * 60 * 24);
	this.setCookie('co'+this.obj, 'cookieValue', yesterday);
	this.setCookie('cs'+this.obj, 'cookieValue', yesterday);
};

// [Cookie] Sets value in a cookie
dTree.prototype.setCookie = function(cookieName, cookieValue, expires, path, domain, secure) {
	document.cookie =
		escape(cookieName) + '=' + escape(cookieValue)
		+ (expires ? '; expires=' + expires.toGMTString() : '')
	        + ((this.config.shared) ? '; path=/' : (path ? '; path=' + path : ''))
		+ (domain ? '; domain=' + domain : '')
		+ (secure ? '; secure' : '');
};

// [Cookie] Gets a value from a cookie
dTree.prototype.getCookie = function(cookieName) {
	var cookieValue = '';
	var posName = document.cookie.indexOf(escape(cookieName) + '=');
	if (posName != -1) {
		var posValue = posName + (escape(cookieName) + '=').length;
		var endPos = document.cookie.indexOf(';', posValue);
		if (endPos != -1) cookieValue = unescape(document.cookie.substring(posValue, endPos));
		else cookieValue = unescape(document.cookie.substring(posValue));
	}
	return (cookieValue);
};

// [Cookie] Returns ids of open nodes as a string
dTree.prototype.updateCookie = function() {
	var str = '';
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n]._io && this.aNodes[n].pid != this.root.id) {
			if (str) str += '.';
			str += this.aNodes[n].id;
		}
	}
	this.setCookie('co' + this.obj, str);
};

// [Cookie] Checks if a node id is in a cookie
dTree.prototype.isOpen = function(id) {
	var aOpen = this.getCookie('co' + this.obj).split('.');
	for (var n=0; n<aOpen.length; n++)
		if (aOpen[n] == id) return true;
	return false;
};


//Not used

dTree.prototype.childCount = function(pNode) {
    var count=0;
	for (var n=0; n<this.aNodes.length; n++)
        {	
		if (this.aNodes[n].pid == pNode.id) //SL: Testing if node n is a child of pNode
            {
            count++;
            }
        }
    return count;
}

//Returns n times fake children for the node, used for translucent background
dTree.prototype.fakeChildren = function(pNode) {
    var str='';
	for (var n=0; n<this.aNodes.length; n++)
        {	
		if (this.aNodes[n].pid == pNode.id) //SL: Testing if node n is a child of pNode
            {
            str+='<div class="' + this.getClassFakeItem() + '"><br /></div>';
            }
        }
    return str;
}

//Set the display property for the style of the children
dTree.prototype.setChildrenDisplay = function(ele,disp) {
    if (!ele || !ele.childNodes) return;
	for (var n=0; n<ele.childNodes.length; n++)
        {	
        ele.childNodes[n].style.display=disp;
        }
}

//SL: The getClass functions are used to get the CSS class

dTree.prototype.getClassFakeItem = function() {
    return this.config.style + 'FakeItem';
}

dTree.prototype.getClassTranslucentBackground = function() {
    return this.config.style + 'TranslucentBackground';
}

dTree.prototype.getClassTree = function() {
    return this.config.style;
}

dTree.prototype.getClassLeaf = function() {
    return this.config.style + 'Leaf';
}

dTree.prototype.getClassNodeOpened = function() {
    return this.config.style + 'NodeOpened';
}

dTree.prototype.getClassNodeClosed = function() {
    return this.config.style + 'NodeClosed';
}

dTree.prototype.getClassChildren = function() {
    return this.config.style + 'Children';
}

dTree.prototype.getClassLevel = function() {
    return this.config.style + 'Level' + this.level;
}

dTree.prototype.getClassRoot = function() {
    return this.config.style + 'Root';
}


// If Push and pop is not implemented by the browser
if (!Array.prototype.push) {
	Array.prototype.push = function array_push() {
		for(var i=0;i<arguments.length;i++)
			this[this.length]=arguments[i];
		return this.length;
	}
};
if (!Array.prototype.pop) {
	Array.prototype.pop = function array_pop() {
		lastElement = this[this.length-1];
		this.length = Math.max(this.length-1,0);
		return lastElement;
	}
};

/************************************************************/
//Element position related code

function getAbsoluteLeft(objectId) {
	// Get an object left position from the upper left viewport corner
	// Tested with relative and nested objects
	o = document.getElementById(objectId)
	oLeft = o.offsetLeft            // Get left position from the parent object
	while(o.offsetParent!=null) {   // Parse the parent hierarchy up to the document element
		oParent = o.offsetParent    // Get parent object reference
		oLeft += oParent.offsetLeft // Add parent left position
		o = oParent
	}
	// Return left postion
	return oLeft
}

function getAbsoluteTop(objectId) {
	// Get an object top position from the upper left viewport corner
	// Tested with relative and nested objects
	o = document.getElementById(objectId)
	oTop = o.offsetTop            // Get top position from the parent object
	while(o.offsetParent!=null) { // Parse the parent hierarchy up to the document element
		oParent = o.offsetParent  // Get parent object reference
		oTop += oParent.offsetTop // Add parent top position
		o = oParent
	}
	// Return top position
	return oTop
}

/// From www.javascripttoolbox.com

var Position = (function() {
  // Resolve a string identifier to an object
  // ========================================
  function resolveObject(s) {
    if (document.getElementById && document.getElementById(s)!=null) {
      return document.getElementById(s);
    }
    else if (document.all && document.all[s]!=null) {
      return document.all[s];
    }
    else if (document.anchors && document.anchors.length && document.anchors.length>0 && document.anchors[0].x) {
      for (var i=0; i<document.anchors.length; i++) {
        if (document.anchors[i].name==s) { 
          return document.anchors[i]
        }
      }
    }
  }
  
  var pos = {};
  pos.$VERSION = 1.0;
  
  // Set the position of an object
  // =============================
  pos.set = function(o,left,top) {
    if (typeof(o)=="string") {
      o = resolveObject(o);
    }
    if (o==null || !o.style) {
      return false;
    }
    
    // If the second parameter is an object, it is assumed to be the result of getPosition()
    if (typeof(left)=="object") {
      var pos = left;
      left = pos.left;
      top = pos.top;
    }
    
    o.style.left = left + "px";
    o.style.top = top + "px";
    return true;
  };
  
  // Retrieve the position and size of an object
  // ===========================================
  pos.get = function(o) {
    var fixBrowserQuirks = true;
      // If a string is passed in instead of an object ref, resolve it
    if (typeof(o)=="string") {
      o = resolveObject(o);
    }
    
    if (o==null) {
      return null;
    }
    
    //SL: that code won't work since o.style.position return no value!?!
    /*
    if (o.style.position=='absolute') {
        writeDebug('absolute');
        return {'left':o.offsetLeft, 'top':o.offsetTop, 'width':o.offsetWidth, 'height':o.offsetHeight};
    }
    */        
    
    var left = 0;
    var top = 0;
    var width = 0;
    var height = 0;
    var parentNode = null;
    var offsetParent = null;
  
    
    offsetParent = o.offsetParent;
    var originalObject = o;
    var el = o; // "el" will be nodes as we walk up, "o" will be saved for offsetParent references
    while (el.parentNode!=null) {
      el = el.parentNode;
      if (el.offsetParent==null) {
      }
      else {
        var considerScroll = true;
        /*
        In Opera, if parentNode of the first object is scrollable, then offsetLeft/offsetTop already 
        take its scroll position into account. If elements further up the chain are scrollable, their 
        scroll offsets still need to be added in. And for some reason, TR nodes have a scrolltop value
        which must be ignored.
        */
        if (fixBrowserQuirks && window.opera) {
          if (el==originalObject.parentNode || el.nodeName=="TR") {
            considerScroll = false;
          }
        }
        if (considerScroll) {
          if (el.scrollTop && el.scrollTop>0) {
            top -= el.scrollTop;
          }
          if (el.scrollLeft && el.scrollLeft>0) {
            left -= el.scrollLeft;
          }
        }
      }
      // If this node is also the offsetParent, add on the offsets and reset to the new offsetParent
      if (el == offsetParent) {
        left += o.offsetLeft;
        if (el.clientLeft && el.nodeName!="TABLE") { 
          left += el.clientLeft;
        }
        top += o.offsetTop;
        if (el.clientTop && el.nodeName!="TABLE") {
          top += el.clientTop;
        }
        o = el;
        if (o.offsetParent==null) {
          if (o.offsetLeft) {
            left += o.offsetLeft;
          }
          if (o.offsetTop) {
            top += o.offsetTop;
          }
        }
        offsetParent = o.offsetParent;
      }
    }
    
  
    if (originalObject.offsetWidth) {
      width = originalObject.offsetWidth;
    }
    if (originalObject.offsetHeight) {
      height = originalObject.offsetHeight;
    }
    
    return {'left':left, 'top':top, 'width':width, 'height':height
        };
  };
  
  // Retrieve the position of an object's center point
  // =================================================
  pos.getCenter = function(o) {
    var c = this.get(o);
    if (c==null) { return null; }
    c.left = c.left + (c.width/2);
    c.top = c.top + (c.height/2);
    return c;
  };
  
  return pos;
})();















