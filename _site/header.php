<?php
	header ("Content-Type: text/html; charset=UTF-8");
?>
<!DOCTYPE html>
<!-- vim: ft=html ff=unix fenc=utf-8
 file: i.html
-->
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
		<meta name="Template" content="vim: html/Mon 18 Jun 2012 11:06:02 AM VLAT" />
		<title>i.html</title>
	</head>
	<body>
<div class="nvbar">
<?php
$larr = array ("Добавить пользователя" => "usernew.php", "Список пользвателей" => "users.php", "Добавить узел" => "nodes.php", "Список узлов" => "index.php");
foreach ($larr as $title => $link) {
	if ("/" . $link != $_SERVER["SCRIPT_NAME"]) {
		print ("<span><a href='$link' titile='$title'>$title</a></span>");
	}
	else
	{
		print ("<span>$title</span>");
	}
	print (" | ");
}
?>
</div>

