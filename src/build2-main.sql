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
	kx_name text NOT NULL CHECK(char_length(name)<300),  -- cache from info, local name.
	kx_urn text NOT NULL CHECK(char_length(urn)<500),    -- cache from info, like URN LEX.
	UNIQUE(kx_urn)
);    -- need final check for info

CREATE TABLE socker.contacthing (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	thid serial NOT NULL PRIMARY KEY,
	thtype int NOT NULL CHECK(socker.valid_enum(thtype,'thtype')), -- vals 1=telephon, 2=email, etc.
	needcomplement boolean NOT NULL DEFAULT false,
	kx_urn text NOT NULL CHECK(char_length(urn)<500),              -- cache from info
	info JSONb NOT NULL CHECK (trim(info->>'val_main')>''),
	UNIQUE(kx_urn)
);    -- need final check for info

CREATE TABLE socker.contactpoint (
	--
	-- See UML, ContactPoint and https://schema.org/Thing
	--
	id serial NOT NULL PRIMARY KEY,
	agid bigint NOT NULL REFERENCES socker.agent(agid),
	thid bigint NOT NULL REFERENCES socker.telcom(thid),
	isowner boolean,                     	-- null=no information, true=is owner, false=is not. 
	ismain boolean NOT NULL DEFAULT false,
	rule int NOT NULL DEFAULT 0 CHECK(socker.valid_enum(rule,'ctrule')), -- undef, home, work, corresp, etc.
	kx_complement text NOT NULL DEFAULT '',
	info JSONb CHECK (trim(info->>'complement')>''),
	UNIQUE(agid,thid,kx_complement)
);    -- need final check for info

