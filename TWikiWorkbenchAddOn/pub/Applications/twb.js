function wikify(sourceId, targetId, suffix) {
  var source = document.getElementById(sourceId);
  var target = document.getElementById(targetId);
  if (!source || !target) {
    return;
  }
  var value = source.value;
  value = value.replace(/�/g, "ae");
  value = value.replace(/�/g, "oe");
  value = value.replace(/�/g, "ue");
  value = value.replace(/�/g, "Ae");
  value = value.replace(/�/g, "Oe");
  value = value.replace(/�/g, "Ue");
  value = value.replace(/�/g, "ss");
  value = value.capitalize();
  value = value.replace(/[^a-zA-Z\d]/g, "");
  value = value.replace(/\s/g, "");
  if (suffix) {
    value += suffix;
  }
  target.value = value;
}
