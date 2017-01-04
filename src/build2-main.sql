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
	kx_name text NOT NULL CHECK(char_length(name)<300),  -- std(info). Local name.
	kx_urn text NOT NULL CHECK(char_length(urn)<500),    -- std(info). <=Like URN LEX.
	UNIQUE(kx_urn)
);    -- need final check for info
