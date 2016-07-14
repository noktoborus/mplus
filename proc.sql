/* vim: syntax=pgsql
*/
CREATE OR REPLACE FUNCTION bank_onupdate()
RETURNS TRIGGER AS $$
BEGIN
	IF (OLD.loan != NEW.loan OR OLD.debt != NEW.debt) THEN
		NEW.balance = NEW.loan - NEW.debt;
	END IF;
	RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_bank_onupdate ON bank;
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

DROP TRIGGER IF EXISTS tr_repayments_oninsert ON repayments;
CREATE TRIGGER tr_repayments_oninsert AFTER INSERT ON repayments FOR EACH ROW EXECUTE PROCEDURE repayments_oninsert();

CREATE OR REPLACE FUNCTION nodes_oninsert()
RETURNS TRIGGER AS $$
DECLARE
	node RECORD;
	branchl integer;
	branchid integer;
BEGIN
	-- SELECT parent node, if present
	IF NEW.upid IS NOT NULL THEN
		SELECT id INTO NEW.upid FROM nodes WHERE userid = (SELECT id FROM users WHERE users.id = NEW.upid LIMIT 1) ORDER BY (times_active < times_expire) DESC, times_active, invited, (nodes.lid IS NOT NULL), (nodes.rid IS NOT NULL), id LIMIT 1;
	END IF;
	SELECT id, rid, lid, level, branch INTO node FROM nodes WHERE nodes.id = NEW.upid;
	IF node.id IS NOT NULL THEN
		UPDATE nodes SET invited = (nodes.invited + 1) WHERE nodes.id = node.id;
		IF (node.lid IS NOT NULL AND node.rid IS NOT NULL) THEN
			-- SELECT last node FROM branch on wanted node
			-- SELECT INTO node * FROM nodes WHERE nodes.branch = node.branch AND (nodes.lid IS NULL OR nodes.rid IS NULL) LIMIT 1;
			SELECT id, rid, lid, level, branch INTO node FROM nodes WHERE nodes.branch IN (SELECT id FROM branches WHERE nodeid = 1 GROUP BY id) AND (nodes.lid IS NULL OR nodes.rid IS NULL) LIMIT 1;
		END IF;
	ELSEIF node.id IS NULL THEN
		-- SELECT last node
		SELECT id, rid, lid, level, branch INTO node FROM nodes WHERE nodes.rid IS NULL OR nodes.lid IS NULL ORDER BY level, id LIMIT 1;
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
		NEW.upid = node.id;
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

DROP TRIGGER IF EXISTS tr_nodes_oninsert ON nodes;
CREATE TRIGGER tr_nodes_oninsert BEFORE INSERT ON nodes FOR EACH ROW EXECUTE PROCEDURE nodes_oninsert();

CREATE OR REPLACE FUNCTION nodes_onupdate()
RETURNS TRIGGER AS $$
BEGIN
	-- calc payment with updated active time
	IF NEW.times_active > OLD.times_active THEN
		-- update balance
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

DROP TRIGGER IF EXISTS tr_nodes_onupdate ON nodes;
CREATE TRIGGER tr_nodes_onupdate BEFORE UPDATE ON nodes FOR EACH ROW EXECUTE PROCEDURE nodes_onupdate();

CREATE OR REPLACE FUNCTION update_balance()
RETURNS void AS $$
DECLARE
	node RECORD;
	_n timestamp;
	_r float;
BEGIN
	SELECT INTO _n now_work();
	FOR node IN (SELECT * FROM nodes WHERE invited >= 2) LOOP
		-- recalc pay percentes
		-- set base percent
		_r = (SELECT repay FROM repayrules WHERE minimal <= NEW.balance AND (maximal >= NEW.balance OR maximal IS NULL) LIMIT 1);
		-- collect bonuses
		IF NEW.invited >= 2 THEN
			-- collect first
			IF ((SELECT COUNT(*) FROM nodes WHERE level > node.level AND branch IN (SELECT id FROM branches WHERE nodeid = node.id)) = 14) THEN
				SELECT INTO _r (_r + 1.0);
				IF ((SELECT COUNT(*) FROM nodes WHERE level > node.level AND branch IN (SELECT id FROM branches WHERE nodeid = node.id)) = 30) THEN
					SELECT INTO _r (_r + 1.0);
					IF ((SELECT COUNT(*) FROM nodes WHERE level > node.level AND branch IN (SELECT id FROM branches WHERE nodeid = node.id)) = 62) THEN
						SELECT INTO _r (_r + 1.0);
					END IF;
				END IF;
			END IF;
		END IF;
		IF (_r > 15.0) THEN
			_r = 15.0;
		END IF;
	END LOOP;
	-- calc pay
	UPDATE nodes SET times_active = (nodes.times_active + 1)
		WHERE nodes.times_expire > 0
			AND node.repay != 0.0
			AND nodes.balance != 0
			AND extract('day' FROM _n) = (nodes.payday * extract(day FROM date_trunc('month', _n) + INTERVAL '1 month' - INTERVAL '1 day'))::integer;
END $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_day()
RETURNS void AS $$
BEGIN
	UPDATE bank SET workday = (workday + '1 day'::interval);
	PERFORM update_balance();
END $$ LANGUAGE plpgsql;

