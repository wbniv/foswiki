function atp_editWindow(url){var win=open(url,"none","titlebar=0,width=900,height=400,resizable,scrollbars");if(win){win.focus();}
return false;}
function atp_update(element,url,field,value){if(window.XMLHttpRequest){var xml=new XMLHttpRequest();}else{var xml=new ActiveXObject("MSXML2.XMLHTTP.3.0");}
url+=";nocache="+parseInt(Math.random()*10000000000);url+=";field="+field;url+=";value="+value;xml.open("GET",url,true);xml.onreadystatechange=function(){if(xml.readyState==4){if(xml.status>=400){if(xml.responseText){alert(xml.responseText);}}else if(element.tagName.toLowerCase()=="select"){var lass=element.className;element.className=lass.replace(/atpState\w+|$/,"atpState"+value);}else{element.style.display="none";}}}
xml.send(null);}