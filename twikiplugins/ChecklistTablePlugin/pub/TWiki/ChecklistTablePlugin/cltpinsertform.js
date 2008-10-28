// --- tooltips (derived from hcltp://www.texsoft.it/index.php?c=software&m=sw.js.htmltooltip&l=it) ---
function cltpFindPos(obj) {
	var curleft;
	var curtop;
	curleft = 0; curtop = 0;

	if (obj.offsetParent) {
		curleft = obj.offsetLeft;
		curtop = obj.offsetTop;
		while ((obj = obj.offsetParent)) {
			if (obj.offsetLeft) curleft += obj.offsetLeft;
			if (obj.offsetTop) curtop += obj.offsetTop;
		}
	} else if (obj.x && obj.y) {
		curleft = obj.x;
		curtop = obj.y;
	}
	return [curleft,curtop];
}
var cltpInsertFormLastVisibleId = new Array();
function cltpShowInsertForm(tooltipId, parentId, posX, posY,closeAll, tablenum, rownum) {
        var it = document.getElementById(tooltipId);
        if (closeAll) {
                while (cltpInsertFormLastVisibleId.length>0) {
                        var lv = document.getElementById(cltpInsertFormLastVisibleId.shift());
                        if (lv) lv.style.visibility = 'hidden';
                }
        }
        cltpInsertFormLastVisibleId.push(tooltipId);
    
        if (!it) return 0;

	var img = document.getElementById(parentId); 

	var pos = cltpFindPos(img); 

	it.style.right = (pos[0]+posX) + 'px';
	it.style.top =  (pos[1]+posY) + 'px';

	var newForm;
	if (rownum>=0) {
		newForm = it.innerHTML.replace(/cltp_action_\d+_(addrow_\d+|insertfirst)/g, 'cltp_action_'+tablenum+'_addrow_'+rownum);
	} else {
		newForm = it.innerHTML.replace(/cltp_action_\d+_(addrow_\d+|insertfirst)/g, 'cltp_action_'+tablenum+'_insertfirst');
		rownum=0;
	}
	newForm = newForm.replace(/cltp_val_ins_\d+_\d+_(\d+)/g,'cltp_val_ins_'+tablenum+'_'+rownum+'_$1');

	it.innerHTML = newForm;


        it.style.visibility = 'visible'; 

	return 1;
}

function cltpCloseInputForm(id) {
        var it = document.getElementById(id); 
        if (it) it.style.visibility = 'hidden'; 
}
