<?php
require_once ("pgconfig.php");
require_once ("header.php");
$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
$pg_qlrs = pg_query ($pg, "SET search_path TO $pg_schema");
pg_free_result ($pg_qlrs);
$pg_qlrs = pg_query ($pg, "SELECT username, firstname, patronymic, surname, email, phone, (SELECT SUM(nodes.balance) * SUM(nodes.repay) FROM nodes WHERE nodes.userid = users.id) FROM users;");
print ("<table cellpadding='3' cellspacing='0' border='1'>");
print ("<tr>\n");
print ("<th>Логин</th><th>Имя</th><th>Отчество</th><th>Фамилия</th><th>e-Mail</th><th>Телефон</th><th>Ежемесечная выплата</th>");
print ("</tr>\n");
while (($pg_row = pg_fetch_row ($pg_qlrs))) {
	print ("<tr>\n");
	foreach ($pg_row as $key) {
		print ("<td>${key}</td>");
	}
	print ("</tr>\n");
}
print ("</table>");
?>

<?php
pg_close ($pg);
require_once ("footer.php");
?>
