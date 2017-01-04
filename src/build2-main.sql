--
-- BUILD2. See https://github.com/ppKrauss/socKer-complete
--

CREATE SEQUENCE socker.agent_id_seq START 101; -- reserve 1-100.

CREATE TABLE socker.agent (
	--
	-- See UML and http://xmlns.com/foaf/spec/#term_Agent
	--
	agId bigint DEFAULT nextval('socker.agent_id_seq') NOT NULL PRIMARY KEY,
	agtype int NOT NULL CHECK(socker.valid_enum(agtype,'agtype')), -- vals 1=org, 2=person, 3=group, 4=robot, etc.
	legaltype bigint REFERENCES socker.enum_item(id), -- see http://gs1.org/voc/organizationRole
	status smallint DEFAULT  '001'::bit(3)::int CHECK(socker.valid_enum(status,'status-type')),
     -- STATUS CONVENTION: bit3=not/endorsed, bit1=informal/formal, bit0=inactive/ative.
	info JSONb NOT NULL CHECK (trim(info->>'name_main')>''),
	kx_name text NOT NULL CHECK(char_length(kx_name)<300),  -- cache from info, local name.
	kx_urn text CHECK(char_length(kx_urn)<500),    -- cache from info, like URN LEX. NULL for status informal
	UNIQUE(kx_urn)
);    -- need final check for info

CREATE TABLE socker.contacthing (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	thid serial NOT NULL PRIMARY KEY,
	thtype int NOT NULL CHECK(socker.valid_enum(thtype,'thtype')), -- vals 1=telephon, 2=email, etc.
	needcomplement boolean NOT NULL DEFAULT false,
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
	kx_urn text NOT NULL DEFAULT '', -- cache for normalized complement.
	info JSONb CHECK (trim(info->>'complement')>''), -- NULL for no complement
	UNIQUE(agid,thid,kx_urn)
);    -- need final check for info


-- -- -- -- -- -- -- -- -- -- -- -- -- --
-- LIB for triggers and basic validations

CREATE FUNCTION socker.thtype_from_thid(bigint) RETURNS integer AS $func$
	SELECT thtype FROM socker.contacthing WHERE thid=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION socker.make_agname(JSONb, agtype integer) RETURNS text AS $func$

	SELECT $1->>'name_main' || COALESCE(' ' || CASE 
		   -- WHEN $2=2 THEN $1->>'name_suffix' -- Organization
		   WHEN $2=1 THEN $1->>'name_surname' -- Person
		   ELSE $1->>'name_suffix'
		END, '')
	;  
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION socker.make_urn(
	--
	-- Like a LEX URN. See https://tools.ietf.org/html/draft-spinosa-urn-lex-10
	--
	JSONb, 			-- 1. the source parts of a URN
	subtype integer, 	-- 2. table subtype (agtype, thtype, etc.)
	classtype int DEFAULT 0,-- 3. table 0=Agent, 1=Contacthing, 2=ContactPoint
	null_aserror boolean DEFAULT true
) RETURNS text AS $func$
	SELECT CASE
		   WHEN $3=1 THEN COALESCE(make_cthing_urn($1),'')
		   WHEN $3=2 THEN COALESCE(make_ctpoint_urn($1),'')  -- ELSE $3=0
		   WHEN $2=1 THEN make_org_urn($1) -- can be null
		   WHEN $2=2 THEN make_person_urn($1) -- can be null
		   WHEN $2=3 THEN make_robot_urn($1) -- can be null
		   WHEN $2=4 THEN make_group_urn($1) -- can be null
		   ELSE CASE WHEN $4 THEN NULL ELSE 'ERROR_ON_MAKE_URN' END
	END
	;  
$func$ LANGUAGE SQL IMMUTABLE;

