function RatingClicked(inputID, valueID, index, elPX) {
    var el = document.getElementById(inputID);
    el.value = index;
    if (el.onchange != null) {
        el.onchange();
    }

    var myPick = document.getElementById(valueID);
    if (myPick != null) {
        myPick.style.width = (index * elPX) + "px";
    }
}
