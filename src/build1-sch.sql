--
-- BUILD1. See https://github.com/ppKrauss/socKer-complete
--

DROP SCHEMA IF EXISTS socker CASCADE;
CREATE SCHEMA socker;

CREATE EXTENSION file_fdw;  -- for CSV import
CREATE SERVER files FOREIGN DATA WRAPPER file_fdw;

-----------
-- PREPARE:

CREATE TABLE socker.enum_item (
	--
	-- Any string used as controlled constant in this database.
	--
	id serial NOT NULL PRIMARY KEY,
	namespace text NOT NULL CHECK(char_length(def_url)<50), -- valid ns.
	label text NOT NULL CHECK(char_length(def_url)<100),    -- the ENUM string
	val int,       -- local ID (constant value)
	def_url text CHECK(char_length(def_url)<500),           -- item definition
	info jSONb,     -- when demand (eg. Schema.org url)
	UNIQUE(namespace,label),
	UNIQUE(namespace,val)
);

CREATE FUNCTION socker.valid_enum(text,text DEFAULT '_ns') RETURNS boolean AS $func$
	--
	-- Check valid enum-namespace. Return true when valid.
	--
  SELECT COALESCE(
	  (SELECT true FROM socker.enum_item WHERE namespace=$2 AND label=$1),
	  false
  );
$func$ LANGUAGE SQL IMMUTABLE;
CREATE FUNCTION socker.valid_enum(int,text DEFAULT '_ns') RETURNS boolean AS $func$
  SELECT COALESCE(
	  (SELECT true FROM socker.enum_item WHERE namespace=$2 AND val=$1),
	  false
  );
$func$ LANGUAGE SQL IMMUTABLE;

ALTER TABLE socker.enum_item ADD CONSTRAINT enum_chk
  CHECK (namespace='_ns' OR socker.valid_enum(namespace,'_ns'))
;
INSERT INTO socker.enum_item(namespace,val,label,def_url) VALUES
	('_ns',1,'agtype','https://github.com/ppKrauss/socKer-complete'),
	('_ns',2,'org-type',''),
	('_ns',3,'org-legaltype',''),
	('_ns',4,'person-type',''),
	('_ns',5,'group-type',''),
	('_ns',6,'robot-type',''),
	('_ns',7,'status-type',''),

	('_ns',100,'rel-org-org',''), ('_ns',101,'rel-org-prs',''), ('_ns',102,'rel-org-grp',''),
	('_ns',103,'rel-org-bot',''), ('_ns',104,'rel-org-ag',''),
	('_ns',120,'rel-prs-prs',''), ('_ns',121,'rel-prs-org',''), ('_ns',122,'rel-prs-grp',''),
	('_ns',123,'rel-prs-bot',''), ('_ns',124,'rel-prs-ag',''),
	('_ns',130,'rel-grp-grp',''), ('_ns',131,'rel-grp-org',''), ('_ns',132,'rel-grp-prs',''),
	('_ns',133,'rel-grp-bot',''), ('_ns',134,'rel-grp-ag',''),
	('_ns',140,'rel-bot-bot',''), ('_ns',141,'rel-bot-org',''), ('_ns',142,'rel-bot-prs',''),
	('_ns',143,'rel-bot-grp',''), ('_ns',144,'rel-bot-ag','')
;
