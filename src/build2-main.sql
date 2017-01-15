--
-- BUILD2. See https://github.com/ppKrauss/socKer-complete
--

CREATE SEQUENCE socker.agent_id_seq START 101; -- reserve 1-100.

CREATE TABLE socker.agent (
	--
	-- See UML and http://xmlns.com/foaf/spec/#term_Agent
	--
	agId bigint DEFAULT nextval('socker.agent_id_seq') NOT NULL PRIMARY KEY,
	agtype int NOT NULL CHECK(socker.valid_enum(agtype,'agtype')), -- vals 1=person, 2=org, 3=group, 4=robot, etc.
	legaltype bigint REFERENCES socker.enum_item(id), -- see http://gs1.org/voc/organizationRole
	status smallint DEFAULT  '001'::bit(3)::int CHECK(socker.valid_enum(status,'status-type')),
     -- STATUS CONVENTION: bit3=not/endorsed, bit1=informal/formal, bit0=inactive/ative.
	info JSONb NOT NULL CHECK (trim(info->>'name_main')>''),
	kx_name text NOT NULL CHECK(char_length(kx_name)<300),  -- cache from info, local name.
	kx_urn text CHECK(char_length(kx_urn)<500),    -- is an ID (like URN LEX) cached from info. NULL for status informal
	created timestamp NOT NULL DEFAULT now(),
	updated timestamp NOT NULL DEFAULT now(),
	UNIQUE(kx_urn)
);    -- need final check for info

CREATE TABLE socker.contacthing (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	thId serial NOT NULL PRIMARY KEY,
	thType int NOT NULL CHECK(socker.valid_enum(thtype,'thtype')), -- vals 1=telephon, 2=email, etc.
	needComplement boolean NOT NULL DEFAULT false,
	kx_urn text NOT NULL CHECK(char_length(kx_urn)<500),              -- cache from info
	info JSONb NOT NULL CHECK (trim(info->>'val')>''),
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
	p_agid bigint,                 -- input agent ID
	p_check bolean DEFAULT false   -- flag to check status
) RETURNS int AS $func$
	SELECT  CASE WHEN $2 AND NOT(status&3) THEN 0 ELSE agtype END
	FROM socker.agent WHERE agid=$1;
$func$ LANGUAGE SQL IMMUTABLE;


------------------


INSERT INTO socker.agent(agtype,legaltype,kx_name,status,info)
-- usar formato vCard padrão
  WITH t AS (
		SELECT jsonb_array_elements(info::JSONb) as jvc
  	FROM socker.csv_tmp2  -- middlename
  ) SELECT
			 1 as agtype, NULL as legaltype, socker.make_agname(jvc,1) as kx_name,
			 1 as status, jvc as info  -- falta um filtro para preservar só campos válidos validfields(j,agtype)
			 -- URN based on vatID!
			 -- name-base is 'urn:person:br:'||regexp_replace(lower(socker.make_agname(jvc,1)), '[\s]+', '.', 'g')
    FROM t;
  ;
