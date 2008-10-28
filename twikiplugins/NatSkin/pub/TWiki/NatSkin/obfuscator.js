// (c)opyright 2006 MichaelDaum@WikiRing.com
function wremo(emoas, linkText, id) {
  var elem = document.getElementById(id);
  if (elem) {
    if (elem.firstChild) {
      elem.removeChild(elem.firstChild);
    }

    var anchor = document.createElement("a");
    elem.appendChild(anchor);

    anchor.href = 'ma'+'il'+'to'+':';

    for (var i = 0; i < emoas.length; i++) {
      anchor.href += emoas[i][1] + '@' + emoas[i][0] + '.' + emoas[i][2];
      if (i < emoas.length-1) {
	anchor.href += ', ';
      }
    }

    if (linkText == '') {
      for (var i = 0; i < emoas.length; i++) {
	linkText += emoas[i][1] + '@' + emoas[i][0] + '.' + emoas[i][2] + ' ';
      }
    }
    var anchorText = document.createTextNode(linkText);
    anchor.appendChild(anchorText);
  }
}

