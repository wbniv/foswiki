<?php

/*
 * Quick'n'Dirty TableTool - Copyright (C) 2004 Iwan Mouwen, rhythmstick@gmail.com
 *
 * Basic conversion from MS-Office and OpenOffice spreadsheets to TWiki tables
 *
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details, published at
 * http://www.gnu.org/copyleft/gpl.html
 *
 */

error_reporting (E_ALL | E_STRICT);

/* Convert */

if (isset($_POST['colwidth']) && preg_match('/^[0-9]+$/', $_POST['colwidth'])) {
	$colwidth=$_POST['colwidth'];
} else {
	$colwidth=8;
}

if (isset($_POST['office_table'])) {
	$office_table=$_POST['office_table'];
	$twiki_table="";

	$rows=preg_split('/\s*\n/', $office_table);
	foreach ($rows as $row) {
		$cells=preg_split('/\s*\t\s*/', $row);
		foreach ($cells as $cell) {
			$twiki_table .= sprintf("|%${colwidth}s", $cell);
		}
		$twiki_table .= "|\n";
	}
} else {
	$office_table="Paste your [MS-|Open]Office table here";	
	$twiki_table="";
}

/* Print */

print "
<html>
<head>
	<title>Table Tool</title>
</head>

<body>


<form name=\"tablefrm\" method=\"post\" action=\"tabletool.php\" enctype=\"application/x-www-form-urlencoded\">

<input type=\"submit\" name=\"submit\" value=\"Convert\">
<input type=\"reset\" name=\"reset\" value=\"Reset\">
<p>
Column Width (of generated table):<br>
<input type=\"text\" name=\"colwidth\" value=\"$colwidth\" size=\"5\" maxlength=\"3\">
<p>
Source table:<br>
<textarea name=\"office_table\" rows=\"20\" cols=\"100\">
$office_table
</textarea>
</form>

<p>
TWiki table:<br>
<textarea name=\"twiki_table\" rows=\"20\" cols=\"100\">
$twiki_table
</textarea>

</body>
";

/* Done */

?>
