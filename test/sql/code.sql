\set ECHO none

\i test/setup.sql

CREATE TEMP VIEW snapshot_types AS
  SELECT *
      , ('snapshot_' || snapshot_type)::name AS composite_type
    FROM unnest('{all,catalog,other_status,stats_file}'::text[]) u(snapshot_type)
;
CREATE TEMP VIEW version__snapshot_types AS SELECT *
  FROM versions, snapshot_types
;

CREATE TEMP TABLE code(
  snapshot_type text NOT NULL PRIMARY KEY
  , composite_type text
  , call text
  , code text
);

SELECT plan((
  0

  -- types
  +(SELECT count(*) FROM snapshot_types)

  -- General call to snapshot_code
  +(SELECT count(*) FROM versions)

  -- snapshot_code detailed testing
  +2 * (SELECT count(*)::int FROM snapshot_types)
)::int);

-- cat_snap
\set schema cat_snap


SELECT has_composite( :'schema', composite_type
      -- TODO: get rid of this once https://github.com/theory/pgtap/issues/234 is fixed
      , format('Composite type %s.%s should exist', :'schema', composite_type)
    )
  FROM snapshot_types
;

-- Verify generic snapshot_code call works for all versions.
SELECT lives_ok(
  format( $$SELECT cat_snap.snapshot_code(%L, cluster_identifier := 'cluster id')$$, version )
  , format( $$SELECT cat_snap.snapshot_code(%L, cluster_identifier := 'cluster id')$$, version )
) FROM versions
;

-- Sadly, can only do this for our current major :(
SELECT lives_ok(
    format( 'INSERT INTO code SELECT %L, %L, %L, %s', snapshot_type, composite_type, call, call )
    , format( 'insert code for a %s snapshot into code table', snapshot_type )
  )
  FROM (
    SELECT *
          , format(
            $$%s.snapshot_code(%s, snapshot_type := %L, raw := true)$$
            , :'schema', :major_version, snapshot_type
          ) AS call
        FROM snapshot_types
  ) a
;

SELECT lives_ok(
      format( 'SELECT (%s)::text::%s.%s', code, :'schema', composite_type )
      , format(
        'cast a %s snapshot to %s.%s'
        , snapshot_type, :'schema', composite_type
      )
    )
  FROM code
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
