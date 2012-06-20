<?php
if (file_exists ("config.php")) {
	require_once ("config.php");
}
else {
	die ("edit config.php");
}
if (!isset ($pg_host)) $pg_host = "localhost";
if (!isset ($pg_user)) $pg_user = "";
if (!isset ($pg_pass)) $pg_pass = "";
if (!isset ($pg_db)) $pg_db = "";
if (!isset ($pg_schema)) $pg_schema = "mplus";
$err_list = array ();


function errors_print () {
	global $err_list;
	return $err_list;
}

function error_handler ($errno, $errstr, $errfile, $errline) {
	global $err_list;
	$errs = array (E_NOTICE => "Notice", E_ERROR => "Error", E_WARNING => "Warning");
	if (isset ($errs[$errno]))
		$errno = $errs[$errno];
	array_push ($err_list, "$errno ($errline): $errstr");
}
set_error_handler ("error_handler");

?>

