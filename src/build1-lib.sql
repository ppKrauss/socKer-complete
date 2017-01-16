--
-- BUILD1. See https://github.com/ppKrauss/socKer-complete
--

--
-- Module of commom basic functions.
-- The lib  schema can be dropped (DROP SCHEMA lib CASCADE) without direct side effect.
-- Adds JSON-RPC interface and some JSONb-utils.
-- See also http://www.jsonrpc.org/specification
--
-- Copyright by ppkrauss@gmail.com 2016, MIT license.
-- adapted from https://github.com/ppKrauss/sql-term/blob/master/src/sql_mode1/step1_libDefs.sql
--

DROP SCHEMA IF EXISTS lib CASCADE;
CREATE SCHEMA lib; -- independent lib


-- -- -- -- -- -- -- --
-- -- -- JSON-UTILS: --

CREATE FUNCTION lib.unpack(
	--
	-- Remove a sub-object and merge its contents.
	-- Ex. SELECT lib.unpack('{"x":12,"sub":{"y":34}}'::jsonb,'sub');
	--
	JSONB,	-- full object
	text	-- pack name
) RETURNS JSONB AS $f$
	SELECT ($1-$2)::JSONB || ($1->>$2)::JSONB;
$f$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.jsonb_grep(JSONb,text[]) RETURNS JSONb AS $func$
	--
	-- Greps the top-level keys of $1 that is in the $2 list of keys.
	--
	SELECT jsonb_object_agg(j.key, j.value)
	FROM jsonb_each($1) AS j
	WHERE j.key = ANY($2);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION jsonb_arr2text_arr(_js jsonb) RETURNS text[] AS $func$
	-- see http://dba.stackexchange.com/a/54289/90651
	SELECT ARRAY(SELECT jsonb_array_elements_text(_js))
$func$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- --
-- -- -- TEXT functions:

CREATE FUNCTION lib.normalizeterm(
	--
	-- Converts string into standard sequence of lower-case words.
	--
	text,               -- 1. input string (many words separed by spaces or punctuation)
	text DEFAULT ' ',   -- 2. separator
	int DEFAULT 255		  -- 3. max lenght of the result (system limit)
) RETURNS text AS $f$
  SELECT  substring(
	LOWER(TRIM( regexp_replace(  -- for review: regex(regex()) for ` , , ` remove
		trim(regexp_replace($1,E'[\\n\\r \\+/,;:\\(\\)\\{\\}\\[\\]="\\s ]*[\\+/,;:\\(\\)\\{\\}\\[\\]="]+[\\+/,;:\\(\\)\\{\\}\\[\\]="\\s ]*|[\\s ]+[–\\-][\\s ]+',' , ', 'g'),' ,'),   -- s*ps*|s-s
		E'[\\s ;\\|"]+[\\.\'][\\s ;\\|"]+|[\\s ;\\|"]+',    -- s.s|s
		$2,
		'g'
	), $2 )),
  1,$3
  );
$f$ LANGUAGE SQL IMMUTABLE;
-- for URNs regexp_replace(x, '\s+', '.', 'g')


-- -- -- -- -- -- -- --
-- -- --   JSON-RPC: --

-- PRIVATE FUNCTIONS --

CREATE FUNCTION lib.jparams(
	--
	-- Converts JSONB or JSON-RPC request (with reserved word "params") into JSOB+DEFAULTS.
	--
	-- Ex.SELECT lib.jparams('{"x":12}'::jsonb, '{"x":5,"y":34}'::jsonb)
	--
	JSONB,			-- the input request (direct or at "params" property)
	JSONB DEFAULT NULL	-- (optional) default values.
) RETURNS JSONB AS $f$
	SELECT CASE WHEN $2 IS NULL THEN jo ELSE $2 || jo END
	FROM (SELECT CASE WHEN $1->'params' IS NULL THEN $1 ELSE $1->'params' END AS jo) t;
$f$ LANGUAGE SQL IMMUTABLE;



CREATE FUNCTION lib.jrpc_error(
	--
	-- Converts input into a JSON RPC error-object.
	--
	-- Ex. SELECT lib.jrpc_error('ops error',123,'i2');
	--
	text,         		-- 1. error message
	int DEFAULT -1,  	-- 2. error code
	text DEFAULT NULL	-- 3. (optional) calling id (when NULL it is assumed to be a notification)
) RETURNS JSONB AS $f$
	SELECT jsonb_build_object(
		'error',jsonb_build_object('code',$2, 'message', $1),
		'id',$3,
		'jsonrpc','2.0'
	);
$f$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.jrpc_ret(
	--
	-- Converts input into a JSON RPC result scalar or single object.
	--
	-- Ex. SELECT lib.jrpc_ret(123,'i1');      SELECT lib.jrpc_ret('123'::text,'i1');
	--     SELECT lib.jrpc_ret(123,'i1','X');  SELECT lib.jrpc_ret(array['123']);
	--     SELECT lib.jrpc_ret(array[1,2,3],'i1','X');
	-- Other standars, see Elasticsearch output at http://wayta.scielo.org/
	--
	anyelement,		-- 1. the result value
	text DEFAULT NULL, 	-- 2. (optional) calling id (when NULL it is assumed to be a notification)
	text DEFAULT NULL 	-- 3. (optional) the result sub-object name
) RETURNS JSONB AS $f$
	SELECT jsonb_build_object(
		'result', CASE WHEN $3 IS NULL THEN to_jsonb($1) ELSE jsonb_build_object($3,$1) END,
		'id',$2,
		'jsonrpc','2.0'
		);
$f$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.jrpc_ret(
	--
	-- jrpc_ret() overload to convert to a dictionary (object with many names).
	--
	-- Ex. SELECT lib.jrpc_ret(array['a'],array['123']);
	--     SELECT lib.jrpc_ret(array['a','b','c'],array[1,2,3],'i1');
	--
	text[],		  	-- 1. the result keys
	anyarray, 	  	-- 2. the result values
	text DEFAULT NULL 	-- 3. (optional) calling id (when NULL it is assumed to be a notification)
) RETURNS JSONB AS $f$
	SELECT jsonb_build_object(
		'result', (SELECT jsonb_object_agg(k,v) FROM (SELECT unnest($1), unnest($2)) as t(k,v)),
		'id',$3,
		'jsonrpc',' 2.0'
		);
$f$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.jrpc_ret(
	--
	-- Adds standard lib structure to JSON-RPC result.
	-- See https://github.com/ppKrauss/sql-term/issues/5
	--
	JSON,      		-- 1. full result (all items) before to pack
	int,       		-- 2. items COUNT of the full result
	text DEFAULT NULL, 	    -- 3. id of callback
	text DEFAULT NULL, 	    -- 4. sc_func or null for use 5
	JSONB DEFAULT NULL      -- 5. json with sc_func and other data, instead of 4.
) RETURNS JSONB AS $f$
	SELECT jsonb_build_object(
		'result', CASE
			WHEN $5 IS NOT NULL THEN jsonb_build_object('items',$1, 'count',$2) || $5
			WHEN $4 IS NULL THEN jsonb_build_object('items',$1, 'count',$2)
			ELSE jsonb_build_object('items',$1, 'count',$2, 'sc_func',$4)
			END,
		'id',$3,
		'jsonrpc',' 2.0'
	);
$f$ LANGUAGE SQL IMMUTABLE;



--- --- --- --- --- ---
-- Namespace functions

CREATE FUNCTION lib.nsmask(
	--
	-- Build mask for bitset-namespaces (ns).
	-- Eg. SELECT  lib.nsmask(array[2,3,4])::bit(32);
	-- Range 1..32.
	--
	int[]  -- List of namespaces (nscount of each ns)
) RETURNS int AS $f$
	SELECT sum( (1::bit(32) << (x-1) )::int )::int
	FROM unnest($1) t(x)
	WHERE x>0 AND x<=32;
$f$ LANGUAGE SQL IMMUTABLE;
