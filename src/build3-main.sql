--
-- BUILD3. See https://github.com/ppKrauss/socKer-complete
--

CREATE SEQUENCE socker.agent_id_seq START 101; -- reserve 1-100.

CREATE TABLE socker.source (  -- source of data in the insert operations
	srcid serial NOT NULL PRIMARY KEY,
	srctype int NOT NULL  CHECK(socker.valid_enum(srctype,'srctype')),
	label text NOT NULL,
	info JSONb, -- for url, author, licence, etc.
	UNIQUE(label)
);
INSERT INTO socker.source (label,srctype)  VALUES
	('unknow-source',1), ('test-suite-v1',3)
;
CREATE TABLE socker.log (  --change-log for all tables and operations.
	id bigserial NOT NULL PRIMARY KEY,
	tname text NOT NULL,  -- table name ('agent','contacthing',etc.)
	instant timestamp NOT NULL DEFAULT now(),
	srcid int REFERENCES socker.source(srcid),
	op int NOT NULL CHECK(socker.valid_enum(op,'operation')),
	op_agid bigint NOT NULL,  -- user or robot
	input_info JSONb -- operation input info. Used to restore and simulations.
	--UNIQUE(tname,instant)
);

CREATE TABLE socker.agent (
	--
	-- See UML and http://xmlns.com/foaf/spec/#term_Agent
	--
	agId bigint DEFAULT nextval('socker.agent_id_seq') NOT NULL PRIMARY KEY,
	agtype int NOT NULL CHECK(socker.valid_enum(agtype,'agtype')), -- vals 1=person, 2=org, 3=group, 4=robot, etc.
	legaltype bigint REFERENCES socker.enum_item(id), -- see eg. http://gs1.org/voc/organizationRole
	status smallint DEFAULT  '001'::bit(3)::int CHECK(socker.valid_enum(status,'status-type')),
     -- STATUS CONVENTION: bit3=not/endorsed, bit1=informal/formal, bit0=inactive/ative.
	info JSONb NOT NULL CHECK (trim(info->>'name_main')>''),
	kx_name text NOT NULL CHECK(char_length(kx_name)<300),  -- cache from info, local name.
	kx_urn text CHECK(char_length(kx_urn)<500),    -- is an ID (like URN LEX) cached from info. NULL for status informal
	created timestamp NOT NULL DEFAULT now(),
	UNIQUE(kx_urn)
);    -- need final check for info

INSERT INTO socker.agent(agid,agtype,status,info, kx_name, kx_urn)
VALUES (
	1,1,3,'{"givenName":"the","familyName":"master","birthPlace":"br","vatID":1}'::JSONb,
	'the master', 'urn:person:br:1'
);
-- id is?

ALTER TABLE socker.log ADD CONSTRAINT aglink FOREIGN KEY (op_agid) REFERENCES socker.agent(agid);


CREATE TABLE socker.contacthing (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	thId serial NOT NULL PRIMARY KEY,
	thType int NOT NULL CHECK(socker.valid_enum(thtype,'thtype')), -- vals 1=telephon, 2=email, etc.
	needComplement boolean NOT NULL DEFAULT false,
	kx_urn text NOT NULL CHECK(char_length(kx_urn)<500),              -- cache from info
	info JSONb NOT NULL , --CHECK (trim(info->>'value')>''),
	UNIQUE(kx_urn)
);    -- need final check for info


CREATE TABLE socker.contactpoint (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	id serial NOT NULL PRIMARY KEY,
	agid bigint NOT NULL REFERENCES socker.agent(agid),
	thid bigint NOT NULL REFERENCES socker.contacthing(thid),
	isowner boolean,                     	-- null=no information, true=is owner, false=is not.
	ismain boolean NOT NULL DEFAULT false,
	rule int NOT NULL DEFAULT 0 CHECK(socker.valid_enum(rule,'ctrule')), -- undef, home, work, corresp, etc.
	kx_complt text NOT NULL DEFAULT '', -- cache for normalized complement, like an URN
	infopt JSONb CHECK (trim(infopt->>'complement')>''), -- info-point, NULL for no complement.
	UNIQUE(agid,thid,kx_complt)
);    -- need final check for info


----- VIEWS

CREATE VIEW socker.contactpoint_full AS
   SELECT *
	 FROM socker.contactpoint cp NATURAL JOIN socker.contacthing ct
;

--------------------

CREATE OR REPLACE FUNCTION socker.jcard_upsert(
	JSONb,        -- all the input data
	p_srcid int,  -- source (or flag "agent's source")
	p_agid int,   -- user or robot operating the system to insert source
	p_op int DEFAULT 1,  -- operation
	p_enforce boolean DEFAULT true
) RETURNS int AS $f$
DECLARE
 ret_id bigint;
 q_rule int;
BEGIN
	IF p_op=1 AND $1->'vatID' IS NOT NULL THEN  -- informal jCard input
	 INSERT INTO socker.agent(agtype,legaltype,kx_name,     status, info, kx_urn)
	   VALUES (
			 	1, NULL, socker.make_agname($1,1),
				3, socker.valid_info($1,'agent',1), 'urn:person:br:'|| ($1->>'vatID')
	 		) RETURNING agid INTO ret_id;

	ELSIF p_op=1 THEN
		INSERT INTO socker.agent(agtype,legaltype,kx_name,     status, info)
			VALUES (1, NULL, socker.make_agname($1,1),     1, socker.valid_info($1,'agent',1)  )
			RETURNING agid INTO ret_id;

	ELSEIF p_op=5 AND $1->'value' IS NOT NULL THEN  -- add contacThing type tel
		INSERT INTO socker.contacthing(thType,needComplement,  kx_urn,info)  --tel=thtype 100
			VALUES (100, false, 'urn:tel:55:'||($1->>'value'),  $1 - 'agid')
			RETURNING thId INTO ret_id;
		IF $1->'agid' IS NOT NULL THEN
			q_rule = 0;
			IF $1->'type' IS NOT NULL THEN
				IF 'home' = ANY(jsonb_arr2text_arr($1->'type')) THEN q_rule = 4; END IF;
				IF 'work' = ANY(jsonb_arr2text_arr($1->'type')) THEN q_rule = 2; END IF;
			END IF;
			INSERT INTO socker.contactpoint(agid,thid,ismain,rule)
			VALUES (($1->>'agid')::bigint,  ret_id,  ('pref' = ANY(jsonb_arr2text_arr($1->'type')) ),  q_rule);
		END IF;
	ELSEIF p_op=5  THEN  -- add contacThing type tel
			ret_id=-1;
	ELSE
			ret_id=-2;
	END IF;
	IF ret_id>1 THEN -- on sucess log it
		INSERT INTO socker.log (tname,srcid,op,   op_agid,input_info)
		VALUES ('agent',p_srcid, p_op,    p_agid, $1);
	END IF;
	RETURN ret_id;
END;
$f$ LANGUAGE PLpgSQL;


-- -- -- -- -- -- -- -- -- -- -- -- -- --
-- LIB for triggers and basic validations

CREATE FUNCTION socker.thtype_from_thid(bigint) RETURNS integer AS $func$
	SELECT thtype FROM socker.contacthing WHERE thid=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION socker.make_agname(JSONb, agtype integer) RETURNS text AS $func$
	SELECT CASE
		WHEN $2=1 AND $1->'familyName' IS NOT NULL AND $1->'givenName' IS NOT NULL THEN
			$1->>'givenName' || ' ' || COALESCE($1->>'additionalName'||' ','') || ($1->>'familyName')
		WHEN $2=1 THEN
			$1->>'fn'
		ELSE
			$1->>'name_main' ||' ' || COALESCE($1->>'name_suffix'||' ','')
	END;
$func$ LANGUAGE SQL IMMUTABLE;



CREATE FUNCTION socker.get_agtype(
	--
	-- Gets from agent its agtype with option for zero when informal or inactive.
	--
	p_agid bigint,                  -- input agent ID
	p_check boolean DEFAULT false   -- flag to check status
) RETURNS int AS $func$
	SELECT  CASE WHEN $2 AND NOT((status&3)::boolean) THEN 0 ELSE agtype END
	FROM socker.agent WHERE agid=$1;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION socker.valid_info(JSONb,text,int) RETURNS JSONb AS $func$
	-- Greps the top-level keys for info in a table and its type.
	-- To merge use old||valid_info()
	SELECT CASE
		WHEN $2='agent' AND $3=1 THEN lib.jsonb_grep($1,array[
			'title','givenName','middlename','familyName','honorificPrefix','honorificSuffix',
			'vatID', 'deathDate', 'deathPlace', 'birthDate', 'birthPlace', 'gender', 'nationality',
			'weight', 'height', 'alternateName', 'image'
			])
		WHEN $2='agent' AND $3=2 THEN $1
		WHEN $2='contacthing' THEN $1
		-- WHEN $2='contacthing' AND $3=1 THEN $1->'tel'
		END;
$func$ LANGUAGE SQL IMMUTABLE;

---------------------


WITH t AS (
	SELECT jsonb_array_elements(info::JSONb) as jvc
	FROM socker.csv_tmp2
) SELECT socker.jcard_upsert(
		jvc,        -- all the input data
		1,  -- source (or flag "agent's source")
		1,   -- the master-bot
		1,  -- operation
		false  -- not enforce
	) FROM t;

WITH t1 AS (
		SELECT jsonb_array_elements(info::JSONb) as jvc
		FROM socker.csv_tmp2
) SELECT
		agid, socker.jcard_upsert(tel||jsonb_build_object('agid',agid),1,1,5) as ud
  FROM (
		SELECT  a.agid, jsonb_array_elements(jvc->'tel') AS tel
		FROM t1 INNER JOIN socker.agent a ON a.kx_name=socker.make_agname(jvc,1)
) t2;
