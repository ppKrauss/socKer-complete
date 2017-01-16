--
-- BUILD2. See https://github.com/ppKrauss/socKer-complete
--

DROP SCHEMA IF EXISTS socker CASCADE;
CREATE SCHEMA socker;

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
	('_ns',2,'thtype','https://github.com/ppKrauss/socKer-complete'),
	('_ns',3,'srctype',''),
	('_ns',4,'operation',''),
	('_ns',5,'ctrule',''),	
	('_ns',10,'org-type',''),
	('_ns',12,'org-legaltype',''),
	('_ns',14,'person-type',''),
	('_ns',16,'group-type',''),
	('_ns',18,'robot-type',''),
	('_ns',20,'status-type',''),
	('_ns',100,'rule-org-org',''), ('_ns',101,'rule-org-prs',''), ('_ns',102,'rule-org-grp',''),
	('_ns',103,'rule-org-bot',''), ('_ns',104,'rule-org-ag',''),
	('_ns',120,'rule-prs-prs',''), ('_ns',121,'rule-prs-org',''), ('_ns',122,'rule-prs-grp',''),
	('_ns',123,'rule-prs-bot',''), ('_ns',124,'rule-prs-ag',''),
	('_ns',130,'rule-grp-grp',''), ('_ns',131,'rule-grp-org',''), ('_ns',132,'rule-grp-prs',''),
	('_ns',133,'rule-grp-bot',''), ('_ns',134,'rule-grp-ag',''),
	('_ns',140,'rule-bot-bot',''), ('_ns',141,'rule-bot-org',''), ('_ns',142,'rule-bot-prs',''),
	('_ns',143,'rule-bot-grp',''), ('_ns',144,'rule-bot-ag','')
;


-------------------------
-- PREPARE TO IMPORT DATA:

CREATE EXTENSION IF NOT EXISTS file_fdw;  -- for CSV import
DROP SERVER IF EXISTS files CASCADE;
CREATE SERVER files FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE socker.csv_tmp1 (
  namespace text,val int,label text,def_url text, info text
) SERVER files OPTIONS (
  filename '/var/tmp/pgstd_socKer_file1.csv', -- a standard elected one (eg. /usr/local)
    format 'csv',
    header 'true'
);
CREATE FOREIGN TABLE socker.csv_tmp2 (
  info text
) SERVER files OPTIONS (
  filename '/var/tmp/pgstd_socKer_file2.txt', -- a standard elected one
    format 'text'
);

----------------------
-- IMPORTING CSV config file:

INSERT INTO socker.enum_item(namespace,val,label,def_url,info)
  SELECT namespace,val,label,def_url,info::JSONb
  FROM socker.csv_tmp1
;
