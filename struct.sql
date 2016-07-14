/* vim: ft=pgsql
*/
-- library
-- f_IsValidEmail(text):
-- http://stackoverflow.com/questions/4908211/postgres-function-to-validate-email-address
CREATE OR REPLACE FUNCTION checkemail(varchar)
RETURNS BOOLEAN AS $$
	SELECT $1 ~ '^[^@\s]+@[^@\s]+(\.[^@\s]+)+$' AS result
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION now_work()
RETURNS timestamp AS $$
BEGIN
	RETURN (SELECT workday + starttime FROM bank);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION now_payday()
RETURNS float AS $$
DECLARE
	_nt timestamp;
	_n float;
BEGIN
	SELECT INTO _nt now_work();
	SELECT INTO _n (extract(day FROM _nt)::float / extract(day FROM date_trunc('month', _nt + INTERVAL '1 month') - INTERVAL '1 day')::float);
	RETURN _n;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION node_visual()
RETURNS varchar AS $$
BEGIN
	RETURN (SELECT substring(md5(now()::text || random()::text), 1, 12));
END $$ LANGUAGE plpgsql;

CREATE SEQUENCE seq_users;
CREATE TABLE users
(
	id bigint NOT NULL DEFAULT (7000000000 + nextval('seq_users'::regclass)) UNIQUE,
	password varchar(128) NOT NULL DEFAULT '' CHECK (char_length(password) >= 6),
	-- contact data:
	firstname varchar(256) NOT NULL CHECK (firstname != ''),
	patronymic varchar(256) NOT NULL CHECK (patronymic != ''),
	surname varchar(256) NOT NULL CHECK (surname != ''),
	email varchar(256) NOT NULL CHECK (char_length(email) > 4 AND checkemail(email)),
	phone bigint NOT NULL,
	-- banking data:
	cardno varchar(20) NOT NULL CHECK (cardno != ''),
	account varchar(20) NOT NULL CHECK (account != ''),
	bankid varchar(9) NOT NULL CHECK (char_length(bankid) = 9),
	bankname varchar(256) NOT NULL CHECK (bankname != ''),
	taxid varchar(12) NOT NULL CHECK (char_length(taxid) = 12),
	paydir varchar(256) NOT NULL CHECK (paydir != '')
);

CREATE SEQUENCE bank_seq;
CREATE TABLE bank
(
	id integer NOT NULL DEFAULT nextval('bank_seq'::regclass),
	loan bigint DEFAULT 0,
	debt bigint DEFAULT 0,
	balance bigint DEFAULT 0,
	starttime date DEFAULT now(),
	workday interval DEFAULT '0 day'::interval
);
COMMENT ON COLUMN bank.workday IS 'debug value, for increment current data (WARN: use now_work() istead now() in code)';
INSERT INTO bank (loan, debt) VALUES (0, 0);

CREATE TABLE repayrules
(
	minimal bigint NOT NULL DEFAULT 0,
	maximal bigint DEFAULT NULL,
	repay float NOT NULL DEFAULT 0.0
);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (0, 50000, 0.10);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (50000, 100000, 0.11);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (100000, 150000, 0.12);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (150000, 200000, 0.13);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (200000, 250000, 0.14);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (250000, 300000, 0.15);
INSERT INTO repayrules (minimal, maximal, repay) VALUES (300000, NULL, 0.15);

CREATE SEQUENCE seq_repayments;
CREATE TABLE repayments
(
	id integer NOT NULL DEFAULT nextval('seq_repayments'::regclass) UNIQUE,
	at timestamp NOT NULL DEFAULT now_work(),
	userid bigint NOT NULL REFERENCES users(id),
	amount bigint NOT NULL DEFAULT 0,
	payout timestamp DEFAULT NULL
);

CREATE TABLE nodes
(
	-- ident
	visual varchar(12) NOT NULL DEFAULT node_visual(),
	-- tree
	id bigint NOT NULL DEFAULT 1 UNIQUE,
	branch integer DEFAULT 0,
	level integer DEFAULT 0,
	upid bigint DEFAULT NULL REFERENCES nodes(id),
	lid integer DEFAULT NULL,
	rid integer DEFAULT NULL,
	-- payment
	balance bigint NOT NULL DEFAULT 0,
	repay float NOT NULL DEFAULT 0.0,
	-- payday: WHERE extract('day', now()) = (nodes.payday * extract(day FROM date_trunc('month', now()) + INTERVAL '1 month' - INTERVAL '1 day'))::integer
	payday float NOT NULL DEFAULT now_payday(),
	times_expire integer NOT NULL DEFAULT 12,
	times_active integer NOT NULL DEFAULT 0,
	-- user info
	invited integer NOT NULL DEFAULT 0,
	userid bigint NOT NULL REFERENCES users(id),
	CHECK (balance > 0)
);
COMMENT ON COLUMN nodes.branch IS 'link to branch table';
COMMENT ON COLUMN nodes.repay IS 'pre-calced percent for repayment (100% as 1.0, 5% as 0.05)';
COMMENT ON COLUMN nodes.invited IS 'how many have this node personaly invited nodes';
COMMENT ON COLUMN nodes.upid IS 'expect link to users.id, automaticaly converted to link on nodes.id';

CREATE SEQUENCE seq_branches;
CREATE TABLE branches
(
	id integer DEFAULT nextval('seq_branches'::regclass),
	nodeid integer NOT NULL DEFAULT 0
);

