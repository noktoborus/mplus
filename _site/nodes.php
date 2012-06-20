<?php
require_once ("pgconfig.php");
require_once ("header.php");
$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
$pg_qlrs = pg_query ($pg, "SET search_path TO $pg_schema");
pg_free_result ($pg_qlrs);


if (isset ($_POST["nodes_checkpost"])) {
	$sq = "";
	$args = array ();
	$pays = array ("300k" => 300000, "250k" => 250000, "200k" => 200000, "150k" => 150000, "100k" => 100000, "50k" => 50000);
	$pay = (isset ($pays[(isset ($_POST["pay"]) ? $_POST["pay"] : false)]) ? $pays[$_POST["pay"]] : 0);
	$op_parent = ($_POST["parent"] != '' ? $_POST["parent"] : false);
	$sq .= "INSERT INTO nodes (";
	if ($op_parent) $sq .= "upid,";
	$sq .= "balance, userid) VALUES (";
	if ($op_parent) $sq .= "(SELECT id FROM nodes WHERE visual = $3), ";
	$sq .= "$1, (SELECT id FROM users WHERE username = $2)) RETURNING visual, level, balance;";
	pg_prepare ($pg, "nodes_ins", $sq);
	array_push ($args, $pay);
	array_push ($args, $_POST["username"]);
	if ($op_parent) array_push ($args, $op_parent);
	$pg_qlrs = pg_execute ($pg, "nodes_ins", $args);
	if ($pg_qlrs) {
		$array = pg_fetch_array ($pg_qlrs);
		print ("node created with id: " . $array["visual"] . ", on level " . $array["level"] . ", with balance " . $array["balance"]);
		pg_free_result ($pg_qlrs);
	} else
	{
		print ("<br/><b>" . pg_last_error ($pg) . "</b><br/>");
	}

}
?>
<form action='#' method='POST'/>
	<table cellpadding='3' cellspacing='0' border='1'>
	<tr>
		<td>Assign to user</td><td><input type='text' name='username' value='<?php echo isset ($_POST["username"]) ? $_POST["username"] : ""; ?>'/></td>
	</tr><tr>
		<td>Assign to parent node</td><td><input type='text' name='parent' value='<?php echo isset ($_POST["parent"]) ? $_POST["parent"] : ""; ?>'/></td>
	</tr><tr>
		<td>Startup</td>
			<td>
				<input type='radio' name='pay' value='300k'>300 000 RUB<br>
				<input type='radio' name='pay' value='250k'>250 000 RUB<br>
				<input type='radio' name='pay' value='200k'>200 000 RUB<br>
				<input type='radio' name='pay' value='150k'>150 000 RUB<br>
				<input type='radio' name='pay' value='100k'>100 000 RUB<br>
				<input type='radio' name='pay' value='50k'>50 000 RUB<br>
			</td>
	</tr><tr>
		<td colspan='2' align='right'><input type='submit' name='nodes_checkpost'/></td>
	</tr>
	</table>
</form>
<?php
pg_close ($pg);
require_once ("footer.php");
?>

