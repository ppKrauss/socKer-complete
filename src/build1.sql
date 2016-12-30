-- 
-- BUILD1. See https://github.com/ppKrauss/socKer-complete
--

DROP SCHEMA IF EXISTS socker CASCADE; 
CREATE SCHEMA socker;

CREATE SEQUENCE socker.agent_id_seq START 101; -- bigint, commom for Person and Organization

CREATE TABLE socker.agent ( 
	-- 
	-- Generalization of Person and Organization, see http://xmlns.com/foaf/spec/#term_Agent
	--
	agid bigint NOT NULL PRIMARY KEY,
	agtype int NOT NULL CHECK(agtype=1 OR agtype=2), -- 1=org, 2=person
	name text NOT NULL CHECK(char_length(name)<200),  -- a standard convertion from metadata, for mnemonic and pre-searching. 
	agstatus int DEFAULT 1 -- 0=inactive... center of control here.
);

CREATE TABLE socker.organization (
	-- 
	-- Organization info, see https://schema.org/Organization
	--
	id bigint DEFAULT nextval('socker.agent_id_seq') NOT NULL PRIMARY KEY,
	vatID text,
	info JSONb NOT NULL CHECK (trim(info->>'name_main')>''),
	UNIQUE(vatID)
);

CREATE TABLE socker.person (
	-- 
	-- Person info, see https://schema.org/Person
	--
	id bigint DEFAULT nextval('socker.agent_id_seq') NOT NULL PRIMARY KEY,
	vatID text,
	info JSONb NOT NULL CHECK (trim(info->>'name_main')>'' AND trim(info->>'name_surname')>''),
	UNIQUE(vatID)
);

CREATE TABLE socker.telcom_type (
	-- 
	-- The ENUM of telecommunication types and properties. 
	--
	id serial NOT NULL PRIMARY KEY,
	jSONb info NOT NULL CHECK (trim(info->>'name')>''),  -- name, validation_regex, subTypeOf, etc.
	UNIQUE(info->>'name') -- "telephone", "email", "home", "skype", "facebook", etc. must be unique
);

CREATE TABLE socker.telcom (
	-- 
	-- A telecommunication (telcom) address, like telephone or e-mail.
	--
	id bigserial NOT NULL PRIMARY KEY,
	ttype bigint REFERENCES socker.telcom_type(id), -- 1=telephone, 2=email, 3=url_home, 4=twiter, etc.
	tvalue text, -- the telecommunication "address" (URI) normalized value
	UNIQUE(ttype,tvalue)
);

CREATE TABLE socker.place (
	-- 
	-- A geographic place or lot-address. See https://schema.org/Place
	--
	id bigserial NOT NULL PRIMARY KEY,
	kx_urn text NOT NULL, -- cached translation of JSON standard metadata into standard URN. Need trigger and algorithm. 
	info JSONb NOT NULL,
	UNIQUE(urn) 
);

CREATE TABLE socker.agent_contactpoint(
	-- 
	-- Agent-ContactPoint relationship. See https://schema.org/ContactPoint
	--
	ctid serial NOT NULL PRIMARY KEY,
	agid bigint REFERENCES socker.agent(agid),
	istelcom boolean NOT NULL,  -- define the type of contactPoint (telcom=true or place=false) 
	id_telcom bigint REFERENCES socker.telcom(id),  -- NULL WHEN NOT(istelcom)
	id_place bigint REFERENCES socker.place(id),  -- NULL WHEN istelcom
	ismain boolean  DEFAULT false, -- only one main per [agid,ttype(id_telcom)], see trigger.
	isowner boolean,  -- null=no information, true=is the owner, false=is not. 
	rule int NOT NULL DEFAULT 0 CHECK(rule>=0 AND rule<100), -- 0=undef, 2=home, 3=work, 4=mobile, 5=corresp, etc.
	UNIQUE(agid,id_telcom)
);

-----
-----
-- GENERAL LIB

CREATE FUNCTION socker.telcom_ttype(bigint) RETURNS integer AS $func$
	-- 
	-- Get telcom.ttype from telcom.id.
	--
	SELECT ttype FROM socker.telcom WHERE id=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION socker.name_join(JSONb, agtype integer) RETURNS text AS $func$
	-- 
	-- Concatenate structured name parts, according to the Agent type.
	--
	SELECT $1->>'name_main' ||
	 COALESCE(' ' || CASE WHEN $2=1 THEN $1->>'name_suffix' ELSE $1->>'name_surname' END, '')
	;   
$func$ LANGUAGE SQL IMMUTABLE;

-----
-----
-- TRIGGERS

CREATE FUNCTION socker.ctrl_agent_tg() RETURNS TRIGGER AS $func$
	-- 
	-- Copy ID to Agent, or delete it.
	--  
	DECLARE
	    theid bigint;
	    ttype int DEFAULT 2;
	BEGIN
	    IF TG_TABLE_NAME='organization' THEN ttype=1; END IF;
	    IF TG_OP = 'INSERT' THEN
		theid = NEW.id;
		INSERT INTO socker.agent (agid,agtype,name) VALUES (theid,ttype,socker.name_join(NEW.info,ttype));
	    	RETURN NEW;
	    ELSE -- DELETE
		theid = OLD.id;
		DELETE FROM socker.agent WHERE agid = theid;
		RETURN OLD;
	    END IF;
	END;
$func$ LANGUAGE PLpgSQL;

CREATE TRIGGER org_agent_tg AFTER INSERT OR DELETE ON socker.organization 
	FOR EACH ROW EXECUTE PROCEDURE socker.ctrl_agent_tg()
;

CREATE TRIGGER person_agent_tg AFTER INSERT OR DELETE ON socker.person 
	FOR EACH ROW EXECUTE PROCEDURE socker.ctrl_agent_tg()
;


CREATE FUNCTION socker.agentelcom_radio_tg() RETURNS TRIGGER AS $func$
	-- 
	-- Ensures the "radio" behaviour (like HTML's input type="radio") of the ismain flag.
	--  
	DECLARE
	  refval int;
	BEGIN
	    IF NEW.ismain THEN
		refval :=  socker.telcom_ttype(NEW.id_telcom);
		UPDATE socker.agent_telcom 
		SET ismain=false
		WHERE ismain AND agid=NEW.agid AND id_telcom!=NEW.id_telcom AND socker.telcom_ttype(id_telcom)=refval;
	    END IF;
	    RETURN NEW;
	END;
$func$ LANGUAGE PLpgSQL;

CREATE TRIGGER agentelcom_radio_tg AFTER INSERT OR UPDATE ON socker.agent_telcom 
	FOR EACH ROW EXECUTE PROCEDURE socker.agentelcom_radio_tg()
;


-----
-----
-- COMPLEMENTAR VIEWS

-- CREATE VIEW socker.agent_telcom_full AS 
-- CREATE VIEW socker.agent_place_full AS
-- ...
