<?php
require_once ("header.php");
require_once ("pgconfig.php");
$array = array ();

$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
$pg_qlrs = pg_query ($pg, "SET search_path TO $pg_schema");
pg_free_result ($pg_qlrs);
# get max lines
$pg_qlrs = pg_query ($pg, "SELECT MAX(level) FROM nodes");
$array = pg_fetch_row ($pg_qlrs);
$array = array_pop ($array);
if ($array) {
	$array -= 1;
}
else {
	$array = 0;
}
pg_free_result ($pg_qlrs);
# get table
$pg_qlrs = pg_query ($pg, "SELECT visual, id, level, upid, lid, rid, balance FROM nodes ORDER BY level, id");

print ("<table border='1' cellpadding='2' cellspacing='0'>\n<tr>\n");
for ($i = 0; $i < (1 << $array); $i++) {
	print "\t<th>" . ($i + 1) . "</th>\n";
}
print ("</tr><tr>\n");
$i = 0;
$lastid = 0;
while (($pg_row = pg_fetch_array ($pg_qlrs)) != NULL) {
	if ($i != $pg_row["level"]) {
		$i = $pg_row["level"];
		print ("</tr><tr>\n");
	}
	$colspan = (((1 << $array) / (1 << ($pg_row["level"] - 1))));
	#print_r ($pg_row);
	if ($lastid + 1 != $pg_row["id"]) {
		$cc = ($pg_row["id"] - (1 << ($pg_row["level"] - 1)));
		for ($ii = 0; $ii < $cc; $ii++) {
			print ("<td></td>");
		}
	}
	print ("\t<td align='center' colspan='" . $colspan . "'>");
	# assign free cel
	print (($pg_row["id"] . "(" . $pg_row["visual"] . ")" . " @ ". $pg_row["balance"]));
	print ("</td>\n");
	$lastid = $pg_row["id"];
#	print_r ($pg_row);
}
print ("</table>");
pg_free_result ($pg_qlrs);
pg_close ($pg);
require_once ("footer.php");
?>

