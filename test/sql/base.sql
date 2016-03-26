\set ECHO none

\i test/pgxntool/setup.sql

SELECT plan(2);

SELECT is(
  (SELECT count(*)::int FROM cat_snap.entity)
  , 100
  , 'Number of entities'
);

SELECT types_are(
  'cat_snap'
  , array(SELECT replace( entity, 'pg_', 'raw_' )::name FROM cat_snap.entity)
  , 'Verify types'
);

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2