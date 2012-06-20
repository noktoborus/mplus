<?php
require_once ("header.php");
require_once ("pgconfig.php");
$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
pg_query ($pg, "SET search_path TO $pg_schema;");

if (isset ($_POST["usernew_checkpost"])) {
	$phone = "";
	if ((isset ($_POST["phone1"]) && isset ($_POST["phone2"])) && (strlen ($_POST["phone1"]) && strlen ($_POST["phone2"]))) {
		$phone = "+7" . $_POST["phone1"] . $_POST["phone2"];
	}
	$pg_qlrs = pg_prepare ($pg, "insertu", "INSERT INTO users (username, password, firstname, patronymic, surname, email, phone, taxid, cardno, account, bankid, bankname, paydir) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)");
	$pg_qlrs = pg_execute ($pg, "insertu",
		array ($_POST["username"],
			$_POST["password"],
			$_POST["firstname"],
			$_POST["patronymic"],
			$_POST["surname"],
			$_POST["email"],
			$phone,
			$_POST["taxid"],
			$_POST["cardno"],
			$_POST["account"],
			$_POST["bankid"],
			$_POST["bankname"],
			$_POST["paydir"]));
	if ($pg_qlrs) {
		pg_free_result ($pg_qlrs);
		print ("user " . $_POST["username"] . "created");
	}
	else {
		print ("<b>" . pg_last_error () . "</b><br>");
	}
}

function c ($n) {
	if (isset ($_POST[$n])) {
		print ($_POST[$n]);
	}
}

pg_close ($pg);
?>

<form method='post' action='#'>
	<table>
	<tr>
		<td>Логин</td><td><input type='text' value='<?php echo @$_POST["username"]?>' name='username'/></td>
	</tr> <tr>
		<td>Пароль</td><td><input type='password' value='' name='password'/></td>
	</tr> <tr>
		<td>Имя</td><td><input type='text' name='firstname' value='<?php if (isset ($_POST["firstname"])) echo $_POST["firstname"]; ?>'/></td>
	</tr> <tr>
		<td>Фамилия</td><td><input type='text' name='surname' value='<?php if (isset ($_POST["surname"])) echo $_POST["surname"]; ?>'/></td>
	</tr> <tr>
		<td>Отчество</td><td><input type='text' name='patronymic' value='<?php if (isset ($_POST["patronymic"])) echo $_POST["patronymic"]; ?>'/></td>
	</tr> <tr>
		<td>e-Mail</td><td><input type='text' name='email' value='<?php if (isset ($_POST["email"])) echo $_POST["email"]; ?>'/></td>
	</tr> <tr>
		<td>Телефон</td><td>+7 (<input type='text' size='3' maxlength='3' name='phone1' value='<?php c ("phone1"); ?>'/>) <input type='text' size='7' maxlength='7' name='phone2' value='<?php c ("phone2"); ?>'/></td>
	</tr> <tr>
	<td>ИНН</td><td><input type='text' size='12' maxlength='12' name='taxid' value='<?php c ("taxid"); ?>'/></td>
	</tr> <tr>
		<td>Номер Карты</td><td><input type='text' size='20' maxlength='20' name='cardno' value='<?php c ("cardno"); ?>'/></td>
	</tr> <tr>
		<td>Номер счёта</td><td><input type='text' size='20' maxlength='20' name='account' value='<?php c ("account"); ?>'/></td>
	</tr> <tr>
		<td>БИК</td><td><input type='text' size='9' maxlength='9' name='bankid' value='<?php c ("bankid"); ?>'/></td>
	</tr> <tr>
		<td>Банк</td><td><input type='text' size='30' name='bankname' value='<?php c ("bankname"); ?>'/></td>
	</tr> <tr>
		<td>Назначение платежа</td><td><input type='text' maxlength='256' name='paydir' value='<?php echo (isset ($_POST["paydir"]) ? $_POST["paydir"] : "Перевод частному лицу"); ?>'/></td>
	</tr> <tr>
		<td colspan='2' align='right'><input type='submit' name='usernew_checkpost'/></td>
	</tr>
	</table>
</form>
<?php require_once ("footer.php"); ?>
