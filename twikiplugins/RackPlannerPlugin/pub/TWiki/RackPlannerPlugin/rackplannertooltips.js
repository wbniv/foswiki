// --- tooltips (derived from http://www.texsoft.it/index.php?c=software&m=sw.js.htmltooltip&l=it) ---
function rppTooltipFindPos(obj) {
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
var rppTooltipLastVisibleId = new Array();
function rppTooltipShow(tooltipId, parentId, posX, posY,closeAll) {
        var it = document.getElementById(tooltipId);
        if (closeAll) {
                while (rppTooltipLastVisibleId.length>0) {
                        var lv = document.getElementById(rppTooltipLastVisibleId.shift());
                        if (lv) lv.style.visibility = 'hidden';
                }
        }
        rppTooltipLastVisibleId.push(tooltipId);
    
        if (!it) return;

	var img = document.getElementById(parentId); 

	var pos = rppTooltipFindPos(img); 

	it.style.left = (pos[0]+posX) + 'px';
	it.style.top =  (pos[1]+posY) + 'px';


        it.style.visibility = 'visible'; 
}

function rppTooltipHide(id) {
        var it = document.getElementById(id); 
        if (it) it.style.visibility = 'hidden'; 
}

