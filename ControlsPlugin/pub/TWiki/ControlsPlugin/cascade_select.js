/*
DepSelectOne: Dependen Select Lists V1.0
copyright 2003 Richard Cornford

constructor parameters for DepSelectOne(masterSelect)
masterSelect = a reference to the select element that is the
first select box in the chain of dependent select boxes.
If more than one instance of the DepSelectOne is required
the name attribute of the masteSelect element for each should
be unique (as the names are used to reference instances of the
Class)

The constructor should additionally be passed one or more
string that contain the same names as the names of the select
elements that are intended to be dependent on the master select
element, in the order in which each shall be dependent on the previous.
The names should be unique within a form.

Example:
&lt;body onload="new DepSelectOne(document.forms['formName'].elements['level_1'], 'level_2', 'level_3', ... , 'level_n');"&gt;

The maximum number of dependent select boxes is not defined in, or
limited by, this code and will probably depend on the JavaScript
implementation. It will be bigger than will ever actually be needed
and performance will drop off if the list gets big, at least in part
because the HTML will become impracticably large.
*/
function DepSelectOne(masterSelect){
	var frm = masterSelect.form;
	this.selectedBlock = 0;
	this.selBoxes = new Array(masterSelect);
	if((frm)&&(typeof Option != 'undefined')){
		for(var c = 1;c < arguments.length;c++){
			var selObj = frm[arguments[c]];
			if((selObj)&&(selObj.type.indexOf('select') == 0)&&(selObj.type.indexOf('mult') < 0)&&(selObj.options.length > 2)){
				this.selBoxes[this.selBoxes.length] = frm[arguments[c]];
			}
		}
		if((this.selBoxes.length >1)&&(this.selBoxes.length == arguments.length)){
			this.selectElement = this.selBoxes[0];
			DepSelectOne.inst[this.index = this.selectElement.name] = this;	//keep global record of this object instance.
			this.selBoxes[0] = this;
			this.optionBlock = new OptionBlock(0, this.selectElement, this.selectElement.options[0].value, this, 0);
			this.next = new DepSelectOneNext(this.selBoxes, 1);
			this.next.setSelection(this.optionBlock.getSelection());
			this.selectElement.onchange = new Function('DepSelectOne.inst[\''+this.index+'\'].handleChange(0)');
		}else{
			//alert('DepSelectOne constructor could not find\nsufficient properly configured SELECT elements\nto initialise.');
		}
	}
}
DepSelectOne.inst = {};	//Globally accessible object to hold instances of the DepSelectOne Class.
//call chain terminating functions.
DepSelectOne.prototype.reset = DepSelectOne.prototype.setSelection = DepSelectOne.prototype.setSelectedFromChild = function(){return true;}
DepSelectOne.prototype.init = function(selectedBlock){
	if(selectedBlock >= 0){
		this.optionBlock.lastSelection = selectedBlock;
	}
	if(this.optionBlock.lastSelection >= 0){
		this.optionBlock.doElement();
		if(window.setTimeout)setTimeout('DepSelectOne.inst[\''+this.index+'\'].refresh();', 5); //fix for Opera 7 timing problem. Harmless otherwise.
	}
}
DepSelectOne.prototype.handleChange = function(ind){
	this.selBoxes[ind].changed();
	if(window.setTimeout)setTimeout('DepSelectOne.inst[\''+this.index+'\'].refresh();', 5); //fix for Opera 7 timing problem. Harmless otherwise.
}
DepSelectOne.prototype.refresh = function(){
	this.selectElement.selectedIndex = this.optionBlock.lastSelection;
	this.next.reset();
}
DepSelectOne.prototype.changed = function(){
	this.optionBlock.readState();
	this.next.setSelection(this.optionBlock.getSelection());
}

function DepSelectOneNext(selBoxes, selBoxIndex){
	this.selectedBlock = -1;
	this.classObj = selBoxes[0];
	this.previous = selBoxes[(selBoxIndex-1)]
	this.selectElement = selBoxes[selBoxIndex];
	selBoxes[selBoxIndex] = this;
	this.selectElement.onchange = new Function('DepSelectOne.inst[\''+this.classObj.index+'\'].handleChange('+selBoxIndex+')');
	this.seperatorOption = new DepOption(this.selectElement.options[0]);
	this.optionBlocks = [];
	var startIndex = 1;
	while(startIndex < this.selectElement.options.length){
		var nextIndex = this.optionBlocks.length;
		this.optionBlocks[nextIndex] = new OptionBlock(startIndex, this.selectElement, this.selectElement.options[0].value, this, nextIndex);
		startIndex += this.optionBlocks[nextIndex].getOptionsTotal();
	}
	for(var cnt = 0,c = 0;c < this.optionBlocks.length;c++){
		this.optionBlocks[c].blockStart = cnt;
		cnt += this.optionBlocks[c].getItems();
	}
	if(++selBoxIndex < selBoxes.length){
		this.next = new DepSelectOneNext(selBoxes, selBoxIndex);
	}else{
		this.next = this.classObj;
		this.previous.init(this.selectedBlock);
	}
}
DepSelectOneNext.prototype.reset = function(){
	if((this.selectedBlock >= 0)&&(this.optionBlocks[this.selectedBlock].lastSelection >= 0)){
		this.selectElement.selectedIndex = this.optionBlocks[this.selectedBlock].lastSelection;
		this.next.reset();
	}
}
DepSelectOneNext.prototype.setSelection = function(selBlock){
	this.selectedBlock = selBlock;
	if(this.selectedBlock < 0){
		var opt = this.selectElement.options;
		opt.length = 0; //clear options
		opt[0] = this.seperatorOption.getOption();
		this.selectElement.selectedIndex = 0;
		this.next.setSelection(-1);
	}else{
		var blk = this.optionBlocks[this.selectedBlock];
		blk.doElement();
		this.next.setSelection(blk.getSelection());
	}
}
DepSelectOneNext.prototype.changed = function(){
	if(this.selectedBlock >= 0){
		var blk = this.optionBlocks[this.selectedBlock];
		blk.readState();
		this.next.setSelection(blk.getSelection());
	}
}
DepSelectOneNext.prototype.setSelectedFromChild = function(blockIndex){
	if(this.selectedBlock < 0){	//only set from OptonBlock on the first attempt.
		this.selectedBlock = blockIndex;
	}
}
DepSelectOneNext.prototype.init = function(selBlock){
	if(selBlock >= 0){
		var blockIndex = 0;
		while(!this.optionBlocks[blockIndex++].nextBlockTest(selBlock));
	}
	this.previous.init(this.selectedBlock);
}

function DepOption(optEl){
	this.value = optEl.value;
	this.text = optEl.text;
}
DepOption.prototype.getOption = function(){
	return new Option(this.text, this.value);
}

function OptionBlock(startIndex, selectElement, seperatorValue, owner, blockIndex){
	this.blockStart = 0;
	this.owner = owner;
	this.index = blockIndex;
	this.selectElement = selectElement;
	this.seperators = [];
	this.optionBlock = [];
	this.lastSelection = -1;
	var opts = this.selectElement.options;
	while((startIndex < opts.length)&&(opts[startIndex].value == seperatorValue)){
		this.seperators[this.seperators.length] = new DepOption(opts[startIndex++]);
	}
	while((startIndex < opts.length)&&(opts[startIndex].value != seperatorValue)){
		if((this.lastSelection < 0)&&(opts[startIndex].selected == true)){
			this.lastSelection = this.optionBlock.length; //record first item selected, if any.
		}
		this.optionBlock[this.optionBlock.length] = new DepOption(opts[startIndex++]);
	}
	if(this.lastSelection >= 0)this.owner.setSelectedFromChild(this.index)
}
OptionBlock.prototype.getOptionsTotal = function(){
	return (this.seperators.length + this.optionBlock.length);
}
OptionBlock.prototype.getItems = function(){
	return this.optionBlock.length;
}
OptionBlock.prototype.nextBlockTest = function(selBlock){
	if((selBlock >= this.blockStart)&&(selBlock < this.blockStart+this.optionBlock.length)){
		this.lastSelection = selBlock - this.blockStart;
		this.owner.selectedBlock = this.index;
		return true;
	}
	return false;
}
OptionBlock.prototype.getSelection = function(){
	return ((this.lastSelection < 0)?-1:(this.blockStart+this.lastSelection));
}
OptionBlock.prototype.doElement = function(){
	var opt = this.selectElement.options;
	opt.length = 0; //clear options
	if((this.lastSelection < 0)&&(this.seperators.length > 0)){
		opt[opt.length] = this.seperators[(this.seperators.length-1)].getOption();
	}
	for(var c = 0;c < this.optionBlock.length;c++){
		opt[opt.length] = this.optionBlock[c].getOption();
	}
	this.selectElement.selectedIndex = ((this.lastSelection < 0)?0:this.lastSelection);
}
OptionBlock.prototype.readState = function(){
	if(this.lastSelection < 0){
		this.lastSelection = (this.selectElement.selectedIndex - 1);
		this.doElement();
	}else{
		this.lastSelection = this.selectElement.selectedIndex;
	}
}
