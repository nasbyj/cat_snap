\set ECHO none

\i test/setup.sql

CREATE TEMP VIEW snapshot_types AS
  SELECT *
      , _cat_snap.type_name__snapshot(snapshot_type) AS snapshot_composite
    FROM unnest('{all,catalog,other_status,stats_file}'::text[]) u(snapshot_type)
;
CREATE TEMP VIEW version__snapshot_types AS SELECT *
  FROM versions, snapshot_types
;
CREATE TEMP VIEW entity_types AS
  SELECT entity, _cat_snap.type_name__raw( entity ) AS raw_composite
    FROM _cat_snap.entity
    WHERE entity NOT IN (SELECT snapshot_type FROM snapshot_types)
;

CREATE TEMP TABLE code(
  snapshot_type text NOT NULL PRIMARY KEY
  , snapshot_composite text
  , call text
  , code text
);

SELECT plan((
  0

  -- types
  +(SELECT count(*) FROM snapshot_types)
  +(SELECT count(*) FROM entity_types)

  -- Cast cat_snap.gather_code() to appropriate type.
  +(SELECT count(*) FROM entity_types)

  -- General call to snapshot_code()
  +(SELECT count(*) FROM versions)

  -- snapshot_code detailed testing
  +2 * (SELECT count(*)::int FROM snapshot_types)
)::int);

-- cat_snap
\set schema cat_snap

SELECT has_composite( :'schema', raw_composite
      -- TODO: get rid of this once https://github.com/theory/pgtap/issues/234 is fixed
      , format('Composite type %s.%s should exist', :'schema', raw_composite)
    )
  FROM entity_types
;

SELECT has_composite( :'schema', snapshot_composite
      -- TODO: get rid of this once https://github.com/theory/pgtap/issues/234 is fixed
      , format('Composite type %s.%s should exist', :'schema', snapshot_composite)
    )
  FROM snapshot_types
;

/*
 * Cast cat_snap.gather_code() to appropriate type. Note that this is only
 * partly version-specific; the code will be version specific but the type
 * itself won't be.
 */
SELECT lives_ok(
    format(
        $$SELECT array(%s)::text[]::%s.%s[]$$
        , cat_snap.gather_code(:'major_version', entity)
        , :'schema'
        , raw_composite
      )
    , format(
      $$Verify cat_snap.gather_code(<major>, %L) can cast to text[]::%s.%s[]$$
        , entity
        , :'schema'
        , raw_composite
      )
    )
  FROM entity_types
;


-- Verify generic snapshot_code call works for all versions.
SELECT lives_ok(
  format( $$SELECT cat_snap.snapshot_code(%L, cluster_identifier := 'cluster id')$$, version )
  , format( $$SELECT cat_snap.snapshot_code(%L, cluster_identifier := 'cluster id')$$, version )
) FROM versions
;

-- Sadly, can only do this for our current major :(
SELECT lives_ok(
    format( 'INSERT INTO code SELECT %L, %L, %L, %s', snapshot_type, snapshot_composite, call, call )
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
      format( 'SELECT (%s)::text::%s.%s', code, :'schema', snapshot_composite )
      , format(
        'cast a %s snapshot to text::%s.%s'
        , snapshot_type, :'schema', snapshot_composite
      )
    )
  FROM code
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
