-- 
-- BUILD2. See https://github.com/ppKrauss/socKer-complete
--

CREATE TABLE socker.ruletype ( 
	-- 
	-- A standard agent-agent rule type.
	--
	id serial NOT NULL PRIMARY KEY,
	def_url text CHECK(char_length(def_url)<250), -- cool URLs, like SchemaOrg or Wikidata, are short
	valid_pairs int[] NOT NULL,  -- agtype-agtype pair, by oneDigit-concatenation. (ex. 11,12,21,22)
	iscommutative boolean NOT NULL DEFAULT true,
	accept_contactpoint boolean NOT NULL DEFAULT false, -- for check before to add a RelatContactPoint.
	info JSONb NOT NULL CHECK (info->>'constraints' IS NOT NULL),
	UNIQUE(def_url)
);
  
CREATE TABLE socker.agents_relation ( 
	-- 
	-- A agent1-agent2 standard relationship.
	--
	agid1 bigint NOT NULL REFERENCES socker.agent(agid),
	agid2 bigint NOT NULL REFERENCES socker.agent(agid),
	ruletype bigint NOT NULL REFERENCES socker.ruletype(id),
	info JSONb, -- standard annotations, on demand
	UNIQUE(agid1,agid2,ruletype)
);

CREATE FUNCTION socker.isvalid_ruletype(
  p_agid1 bigint, p_agid2 bigint, p_ruletype bigint
) RETURNS boolean AS $func$
	-- 
	-- Check if it is a valid relationship.
	--
	SELECT	$1!=$2
		AND
		CASE WHEN iscommutative THEN $1<$2 ELSE true END
		AND
		(agtype2 + agtype1*10) = ANY valid_pairs
	FROM (
	SELECT iscommutative,  valid_pairs, 
	  (SELECT agtype FROM socker.agent WHERE agid=$1) as agtype1,  
	  (SELECT agtype FROM socker.agent WHERE agid=$2) as agtype2,  
	FROM socker.ruletype WHERE id=$3
	) t;
$func$ LANGUAGE SQL IMMUTABLE;

ALTER TABLE socker.agents_relation 
  ADD CONSTRAINT validrule CHECK(socker.isvalid_ruletype(agid1,agid2,reltype))
;
