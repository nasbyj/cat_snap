\set ECHO none

\i test/pgxntool/psql.sql
\i test/pgxntool/tap_setup.sql

BEGIN;
\i sql/cat_snap.sql

SET LOCAL search_path = tap, cat_snap;

SELECT plan(2);

SELECT hasnt_schema('pg_temp');
SELECT hasnt_schema('__cat_snap');

SELECT finish();

\echo # TRANSACTION INTENTIONALLY LEFT OPEN!

-- vi: expandtab sw=2 ts=2
