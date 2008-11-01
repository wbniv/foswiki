var twiki;if(!twiki)twiki={};twiki.getMetaTag=function(inKey){if(twiki.metaTags==null||twiki.metaTags.length==0){var head=document.getElementsByTagName("META");head=head[0].parentNode.childNodes;twiki.metaTags=new Array();for(var i=0;i<head.length;i++){if(head[i].tagName!=null&&head[i].tagName.toUpperCase()=='META'){twiki.metaTags[head[i].name]=head[i].content;}}}
return twiki.metaTags[inKey];};twiki.getElementsByClassName=function(root,tag,className){var elms=root.getElementsByTagName(tag);className=className.replace(/\-/g,"\\-");var re=new RegExp("\\b"+className+"\\b");var el;var hits=new Array();for(var i=0;i<elms.length;i++){el=elms[i];if(re.test(el.className)){hits.push(el);}}
return hits;}
twiki.Window={POPUP_WINDOW_WIDTH:600,POPUP_WINDOW_HEIGHT:480,POPUP_ATTRIBUTES:"titlebar=0,resizable,scrollbars",openPopup:function(inUrl,inOptions,inAltWindow){if(!inUrl)return null;var paramsString="";var name="";var pathString=inUrl;var windowAttributes=[];var width=twiki.Window.POPUP_WINDOW_WIDTH;var height=twiki.Window.POPUP_WINDOW_HEIGHT;var attributes=twiki.Window.POPUP_ATTRIBUTES;if(inOptions){var pathElements=[];if(inOptions.web!=undefined)pathElements.push(inOptions.web);if(inOptions.topic!=undefined){pathElements.push(inOptions.topic);}
pathString+=pathElements.join("/");var params=[];if(inOptions.skin!=undefined){params.push("skin="+inOptions.skin);}
if(inOptions.template!=undefined){params.push("template="+inOptions.template);}
if(inOptions.section!=undefined){params.push("section="+inOptions.section);}
if(inOptions.cover!=undefined){params.push("cover="+inOptions.cover);}
if(inOptions.urlparams!=undefined){params.push(inOptions.urlparams);}
paramsString=params.join(";");if(paramsString.length>0){paramsString="?"+paramsString;}
if(inOptions.topic!=undefined){name=inOptions.topic;}
if(inOptions.name!=undefined){name=inOptions.name;}
if(inOptions.width!=undefined)width=inOptions.width;if(inOptions.height!=undefined)height=inOptions.height;if(inOptions.attributes!=undefined)attributes=inOptions.attributes;}
windowAttributes.push("width="+width);windowAttributes.push("height="+height);windowAttributes.push(attributes);var attributesString=windowAttributes.join(",");var url=pathString+paramsString;var window=open(url,name,attributesString);if(window){window.focus();return window;}
if(inAltWindow&&inAltWindow.document){inAltWindow.document.location.href=pathString;}
return null;}}
function launchWindow(inWeb,inTopic){var scripturlpath=twiki.getMetaTag('SCRIPTURLPATH');var scriptsuffix=twiki.getMetaTag('SCRIPTSUFFIX');twiki.Window.openPopup(scripturlpath+'/view'+
scriptsuffix+'/',{web:inWeb,topic:inTopic,template:"viewplain"});return false;}
twiki.Event={addLoadEvent:function(inFunction,inDoPrepend){if(typeof(inFunction)!="function"){return;}
var oldonload=window.onload;if(typeof window.onload!='function'){window.onload=function(){inFunction();};}else{var prependFunc=function(){inFunction();oldonload();};var appendFunc=function(){oldonload();inFunction();};window.onload=inDoPrepend?prependFunc:appendFunc;}}};twiki.HTML={setHtmlOfElementWithId:function(inId,inHtml){var elem=document.getElementById(inId);return twiki.HTML.setHtmlOfElement(elem,inHtml);},setHtmlOfElement:function(el,inHtml){if(!el||inHtml==undefined)return null;el.innerHTML=inHtml;return el;},getHtmlOfElementWithId:function(inId){var elem=document.getElementById(inId);return twiki.HTML.getHtmlOfElement(elem);},getHtmlOfElement:function(el){if(!el)return null;return el.innerHTML;},clearElementWithId:function(inId){var elem=document.getElementById(inId);return twiki.HTML.clearElement(elem);},clearElement:function(el){if(!el)return null;twiki.HTML.setHtmlOfElement(el,"");return el;},deleteElementWithId:function(inId){var elem=document.getElementById(inId);return twiki.HTML.deleteElement(elem);},deleteElement:function(el){if(!el)return null;el.parentNode.removeChild(el);return el;},insertAfterElement:function(el,inType,inHtmlContents,inAttributes){if(!el||!inType)return null;var newElement=twiki.HTML._createElementWithTypeAndContents(inType,inHtmlContents,inAttributes);if(newElement){el.appendChild(newElement);return newElement;}
return null;},insertBeforeElement:function(el,inType,inHtmlContents,inAttributes){if(!el||!inType)return null;var newElement=twiki.HTML._createElementWithTypeAndContents(inType,inHtmlContents,inAttributes);if(newElement){el.parentNode.insertBefore(newElement,el);return newElement;}
return null;},replaceElement:function(el,inType,inHtmlContents,inAttributes){if(!el||!inType)return null;var newElement=twiki.HTML._createElementWithTypeAndContents(inType,inHtmlContents,inAttributes);if(newElement){el.parentNode.replaceChild(newElement,el);return newElement;}
return null;},_createElementWithTypeAndContents:function(inType,inHtmlContents,inAttributes){var newElement=document.createElement(inType);if(inHtmlContents!=undefined){newElement.innerHTML=inHtmlContents;}
if(inAttributes!=undefined){twiki.HTML.setElementAttributes(newElement,inAttributes);}
return newElement;},setNodeAttributesInList:function(inNodeList,inAttributes){if(!inNodeList)return;var i,ilen=inNodeList.length;for(i=0;i<ilen;++i){var elem=inNodeList[i];twiki.HTML.setElementAttributes(elem,inAttributes);}},setElementAttributes:function(el,inAttributes){for(var attr in inAttributes){if(attr=="style"){var styleObject=inAttributes[attr];for(var style in styleObject){el.style[style]=styleObject[style];}}else{el[attr]=inAttributes[attr];}}}};twiki.CSS={removeClass:function(el,inClassName){if(!el)return;var classes=twiki.CSS.getClassList(el);if(!classes)return;var index=twiki.CSS._indexOf(classes,inClassName);if(index>=0){classes.splice(index,1);twiki.CSS.setClassList(el,classes);}},addClass:function(el,inClassName){if(!el)return;var classes=twiki.CSS.getClassList(el);if(!classes)return;if(twiki.CSS._indexOf(classes,inClassName)<0){classes[classes.length]=inClassName;twiki.CSS.setClassList(el,classes);}},replaceClass:function(el,inOldClass,inNewClass){if(!el)return;twiki.CSS.removeClass(el,inOldClass);twiki.CSS.addClass(el,inNewClass);},getClassList:function(el){if(!el)return;if(el.className&&el.className!=""){return el.className.split(' ');}
return[];},setClassList:function(el,inClassList){if(!el)return;el.className=inClassList.join(' ');},hasClass:function(el,inClassName){if(!el)return;if(el.className){var classes=twiki.CSS.getClassList(el);if(classes)return(twiki.CSS._indexOf(classes,inClassName)>=0);return false;}},_indexOf:function(inArray,el){if(!inArray||inArray.length==undefined)return null;var i,ilen=inArray.length;for(i=0;i<ilen;++i){if(inArray[i]==el)return i;}
return-1;}}
twiki.Form={KEYVALUEPAIR_DELIMITER:";",formData2QueryString:function(inForm,inFormatOptions){if(!inForm)return null;var opts=inFormatOptions||{};var str='';var formElem;var lastElemName='';for(i=0;i<inForm.elements.length;i++){formElem=inForm.elements[i];switch(formElem.type){case'text':case'hidden':case'password':case'textarea':case'select-one':str+=formElem.name
+'='
+encodeURI(formElem.value)
+twiki.Form.KEYVALUEPAIR_DELIMITER;break;case'select-multiple':var isSet=false;for(var j=0;j<formElem.options.length;j++){var currOpt=formElem.options[j];if(currOpt.selected){if(opts.collapseMulti){if(isSet){str+=','
+encodeURI(currOpt.text);}else{str+=formElem.name
+'='
+encodeURI(currOpt.text);isSet=true;}}else{str+=formElem.name
+'='
+encodeURI(currOpt.text)
+twiki.Form.KEYVALUEPAIR_DELIMITER;}}}
if(opts.collapseMulti){str+=twiki.Form.KEYVALUEPAIR_DELIMITER;}
break;case'radio':if(formElem.checked){str+=formElem.name
+'='
+encodeURI(formElem.value)
+twiki.Form.KEYVALUEPAIR_DELIMITER;}
break;case'checkbox':if(formElem.checked){if(opts.collapseMulti&&(formElem.name==lastElemName)){if(str.lastIndexOf('&')==str.length-1){str=str.substr(0,str.length-1);}
str+=','
+encodeURI(formElem.value);}
else{str+=formElem.name
+'='
+encodeURI(formElem.value);}
str+=twiki.Form.KEYVALUEPAIR_DELIMITER;lastElemName=formElem.name;}
break;}}
str=str.substr(0,str.length-1);return str;},makeSafeForTableEntry:function(inForm){if(!inForm)return null;var formElem;for(i=0;i<inForm.elements.length;i++){formElem=inForm.elements[i];switch(formElem.type){case'text':case'password':case'textarea':formElem.value=twiki.Form._makeTextSafeForTableEntry(formElem.value);break;}}},_makeTextSafeForTableEntry:function(inText){if(inText.length==0)return"";var safeString=inText;var re;re=new RegExp(/\r/g);safeString=safeString.replace(re,"\n");re=new RegExp(/\|/g);safeString=safeString.replace(re,"/");re=new RegExp(/\n\s*\n/g);safeString=safeString.replace(re,"%<nop>BR%%<nop>BR%");re=new RegExp(/\n/g);safeString=safeString.replace(re,"%<nop>BR%");safeString+=" ";return safeString;},getFormElement:function(inFormName,inElementName){return document[inFormName][inElementName];},setFocus:function(inFormName,inInputFieldName){try{var el=twiki.Form.getFormElement(inFormName,inInputFieldName);el.focus();}catch(er){}},initBeforeFocusText:function(el,inText){el.FP_defaultValue=inText;if(!el.value||el.value==inText){twiki.Form._setDefaultStyle(el);}},clearBeforeFocusText:function(el){if(!el.FP_defaultValue){el.FP_defaultValue=el.value;}
if(el.FP_defaultValue==el.value){el.value="";}
twiki.CSS.addClass(el,"twikiInputFieldFocus");twiki.CSS.removeClass(el,"twikiInputFieldBeforeFocus");},restoreBeforeFocusText:function(el){if(!el.value&&el.FP_defaultValue){twiki.Form._setDefaultStyle(el);}
twiki.CSS.removeClass(el,"twikiInputFieldFocus");},_setDefaultStyle:function(el){el.value=el.FP_defaultValue;twiki.CSS.addClass(el,"twikiInputFieldBeforeFocus");}};;
