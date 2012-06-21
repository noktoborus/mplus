/* vim: ft=pgsql
*/
DROP SCHEMA mplus CASCADE;
CREATE SCHEMA mplus;
SET search_path TO mplus;
-- library
-- f_IsValidEmail(text):
-- http://stackoverflow.com/questions/4908211/postgres-function-to-validate-email-address
CREATE OR REPLACE FUNCTION checkemail(varchar)
RETURNS BOOLEAN AS $$
	SELECT $1 ~ '^[^@\s]+@[^@\s]+(\.[^@\s]+)+$' AS result
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION now_now()
RETURNS timestamp AS $$
BEGIN
	RETURN (now() + (SELECT nowfix FROM bank));
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION now_payday()
RETURNS float AS $$
DECLARE
	_nt timestamp;
	_n float;
BEGIN
	SELECT INTO _nt now_now();
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
	phone varchar(12) NOT NULL CHECK (phone != ''),
	-- banking data:
	cardno varchar(20) NOT NULL CHECK (cardno != ''),
	account varchar(20) NOT NULL CHECK (account != ''),
	bankid varchar(9) NOT NULL CHECK (char_length(bankid) = 9),
	bankname varchar(256) NOT NULL CHECK (bankname != ''),
	taxid varchar(12) NOT NULL CHECK (char_length(taxid) = 12),
	paydir varchar(256) NOT NULL CHECK (paydir != '')
);

CREATE TABLE bank
(
	loan bigint DEFAULT 0,
	debt bigint DEFAULT 0,
	balance bigint DEFAULT 0,
	nowfix interval DEFAULT '0 day'::interval
);
COMMENT ON COLUMN bank.nowfix IS 'debug value, for increment current data (WARN: use now_now() istead now() in code)';
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
	at timestamp NOT NULL DEFAULT now_now(),
	userid integer NOT NULL REFERENCES users(id),
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
	times_expire integer NOT NULL DEFAULT 0,
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

CREATE OR REPLACE FUNCTION bank_onupdate()
RETURNS TRIGGER AS $$
BEGIN
	IF (OLD.loan != NEW.loan OR OLD.debt != NEW.debt) THEN
		NEW.balance = NEW.loan - NEW.debt;
	END IF;
	RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bank_onupdate BEFORE UPDATE ON bank FOR EACH ROW EXECUTE PROCEDURE bank_onupdate();

CREATE OR REPLACE FUNCTION repayments_oninsert()
RETURNS TRIGGER AS $$
BEGIN
	-- update debt
	IF NEW.amount > 0 THEN
		UPDATE bank SET debt = (bank.debt + NEW.amount);
	END IF;
	RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tr_repayments_oninsert AFTER INSERT ON repayments FOR EACH ROW EXECUTE PROCEDURE repayments_oninsert();

CREATE OR REPLACE FUNCTION nodes_oninsert()
RETURNS TRIGGER AS $$
DECLARE
	node RECORD;
	branchl integer;
	branchid integer;
BEGIN
	SELECT INTO node NULL;
	-- SELECT parent node, if present
	IF NEW.upid IS NOT NULL THEN
		SELECT id INTO NEW.id FROM nodes WHERE userid = (SELECT id FROM users WHERE users.id = NEW.upid LIMIT 1) ORDER BY nodes.lid, nodes.rid, id LIMIT 1;
		-- TODO: ...
		SELECT * INTO node FROM nodes WHERE nodes.id = NEW.upid;
		IF node IS NOT NULL THEN
			UPDATE nodes SET invited = (node.invited + 1) WHERE nodes.id = node.id;
			IF (node.lid IS NOT NULL AND node.rid IS NOT NULL) THEN
				-- SELECT last node FROM branch on wanted node
				-- SELECT * INTO node FROM nodes WHERE nodes.branch = node.branch AND (nodes.lid IS NULL OR nodes.rid IS NULL) LIMIT 1;
				SELECT * INTO node FROM nodes WHERE nodes.branch IN (SELECT id FROM branches WHERE nodeid = 1 GROUP BY id) AND (nodes.lid IS NULL OR nodes.rid IS NULL) LIMIT 1;
			END IF;
		END IF;
	END IF;
	IF node IS NULL THEN
		-- SELECT last node
		SELECT * INTO node FROM nodes WHERE nodes.rid IS NULL OR nodes.lid IS NULL ORDER BY level, id LIMIT 1;
	END IF;
	-- update loan
	UPDATE bank SET loan = (bank.loan + NEW.balance);
	-- get repayment factor
	NEW.repay = (SELECT repay FROM repayrules WHERE minimal <= NEW.balance AND (maximal >= NEW.balance OR maximal IS NULL) LIMIT 1);
	IF node.id IS NOT NULL THEN
		-- UPDATE node
		IF node.lid IS NULL THEN
			-- set id for node (level + 1)
			NEW.id = (node.id * 2);
			-- if left leaf is NULL, attach here
			UPDATE nodes SET lid = NEW.id WHERE nodes.id = node.id;
		ELSIF node.rid IS NULL THEN
			-- set id for node (level + 1 and + 1 from branch)
			NEW.id = ((node.id * 2) + 1);
			-- if right leaf is NULL, attach here
			UPDATE nodes SET rid = NEW.id WHERE nodes.id = node.id;
		END IF;
		-- CREATE new branch OR add to current
		IF (node.rid IS NULL AND node.lid IS NULL) THEN
			-- add to current
			INSERT INTO branches (id, nodeid) VALUES (node.branch, NEW.id);
			NEW.branch = node.branch;
		ELSE
			-- create new branch
			INSERT INTO branches (nodeid) VALUES (NEW.id);
			SELECT currval INTO branchid FROM currval('seq_branches'::regclass);
			NEW.branch = branchid;
			-- add all preverios, except left leaf, because it have similar branch with parent.
			FOR branchl IN SELECT nodeid FROM branches WHERE branches.id = node.branch AND branches.nodeid != node.lid LOOP
				INSERT INTO branches (id, nodeid) VALUES (branchid, branchl);
			END LOOP;
		END IF;
		NEW.level = node.level + 1;
		RETURN NEW;
	ELSE
		-- create a first branch
		INSERT INTO branches (nodeid) VALUES (NEW.id);
		SELECT currval INTO branchid FROM currval('seq_branches'::regclass);
		-- ADD a first node
		NEW.branch = branchid;
		NEW.level = 1;
		NEW.id = 1;
		RETURN NEW;
	END IF;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tr_nodes_oninsert BEFORE INSERT ON nodes FOR EACH ROW EXECUTE PROCEDURE nodes_oninsert();

CREATE OR REPLACE FUNCTION nodes_onupdate()
RETURNS TRIGGER AS $$
BEGIN
	-- calc payment with updated active time
	IF NEW.times_active > OLD.times_active THEN
		IF (OLD.balance != 0 AND OLD.repay != 0.0) THEN
			INSERT INTO repayments (userid, amount) VALUES (OLD.userid, OLD.balance * OLD.repay);
		END IF;
	END IF;
	-- recalc payment factor
	IF NEW.balance != OLD.balance THEN
		NEW.repay = (SELECT repay FROM repayrules WHERE minimal <= NEW.balance AND (maximal >= NEW.balance OR maximal IS NULL) LIMIT 1);
	END IF;
	RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tr_nodes_onupdate BEFORE UPDATE ON nodes FOR EACH ROW EXECUTE PROCEDURE nodes_onupdate();

CREATE OR REPLACE FUNCTION balance_update()
RETURNS void AS $$
DECLARE
	node RECORD;
	_n timestamp;
BEGIN
	SELECT INTO _n now_now();
	-- collect bonuses
	-- TODO
	SELECT * FROM nodes WHERE nodes.invited >= 2;
	-- calc pay
	UPDATE nodes SET times_active = (nodes.times_active)
		WHERE nodes.times_expire > 0
			AND node.repay != 0.0
			AND nodes.balance != 0
			AND extract('day' FROM _n) = (nodes.payday * extract(day FROM date_trunc('month', _n) + INTERVAL '1 month' - INTERVAL '1 day'))::integer;
END $$ LANGUAGE plpgsql;

