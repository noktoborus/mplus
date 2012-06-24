<?php
require_once ("pgconfig.php");
require_once ("header.php");
$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
$pg_qlrs = pg_query ($pg, "SET search_path TO $pg_schema");
pg_free_result ($pg_qlrs);

$pg_qlrs = pg_query ($pg, "SELECT repayments.id, repayments.at, repayments.amount, users.id FROM repayments, users WHERE repayments.payout IS NULL AND users.id = repayments.userid;");
print ("<table cellpadding='3' cellspacing='0' border='1'>");
print ("<tr>\n");
print ("\t<td>#</td><td>Время</td><td>Выплата</td><td>Пользователю</td>\n");
print ("</tr>\n");
while (($pg_row = pg_fetch_row ($pg_qlrs))) {
	print ("<tr>\n");
	foreach ($pg_row as $i) {
		print ("<td>". $i . "</td>");
	}
	print ("</tr>\n");
}
pg_free_result ($pg_qlrs);
print ("</table>");

pg_close ($pg);
require_once ("footer.php");
?>
