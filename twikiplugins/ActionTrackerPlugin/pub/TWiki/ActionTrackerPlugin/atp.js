// Handler when an action is edited
function atp_editWindow(url) {
    var win = open(url, "none",
                   "titlebar=0,width=900,height=400,resizable,scrollbars");
    if (win) {
        win.focus();
    }
    return false;
}

// Handler when an action status is changed
function atp_update(element, url, field) {
    if (window.XMLHttpRequest){
        var xml = new XMLHttpRequest();
    }else{
        var xml = new ActiveXObject("MSXML2.XMLHTTP.3.0");
    }
    url += ";nocache="+parseInt(Math.random() * 10000000000);
    url += ";field="+field;
    url += ";value="+element.value;
    xml.open("GET", url, true);
    xml.onreadystatechange = function() {
        if (xml.readyState == 4) {
            if (xml.status >= 400) {
                // Something went wrong!
                if (xml.responseText) {
                    alert(xml.responseText);
                }
            } else {
                // Change the CSS class of the element to
                // reflect the new value
                var lass = element.className;
                element.className = lass.replace(
                    /atpState\w+|$/, "atpState"+element.value);
            }
        }
    }
    xml.send(null);
}
