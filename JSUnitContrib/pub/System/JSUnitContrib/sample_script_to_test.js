function multiplyAndAddFive (value1, value2) {
	if (value1 == undefined || value2 == undefined) return null;
	// commented out to show error output
	// if (isNaN(value1) || isNaN(value2)) return null;
	return value1 * value2 + 5;
}