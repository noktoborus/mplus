<?php
require_once ("pgconfig.php");
// options
$show_payout = (isset ($_GET['po']) ? true : false);
$show_user = (isset ($_GET['us']) ? $_GET['us'] : false);
// code
$pg = pg_connect ("host=$pg_host dbname=$pg_db user=$pg_user password=$pg_pass") or die ("Connection failed");
pg_query ($pg, "SET search_path TO $pg_schema;");
pg_prepare ($pg, "sel_prep", "SELECT * FROM repayments WHERE repayments.payout IS " . ($show_payout ? "NOT " : "") . "NULL"));
$pg_qlrs = pg_execute ($pg, "sel_prep", array ($show_for_users));

pg_close ($pg);
?>
