SET log_min_messages = WARNING;
SET client_min_messages = WARNING;
CREATE EXTENSION IF NOT EXISTS cat_tools;

BEGIN;
\i generated/entity.dmp
\i common/type_functions.sql

SELECT format(
        $$CREATE TYPE %s AS (%s);$$
        , type_name__raw(entity)
        , array_to_string(
            corrected
            , ', '
        )
    )
    FROM entity_v
;
SELECT format(
        $$CREATE TYPE %s AS (%s);$$
        , type_name__delta(entity)
        , array_to_string(
            delta || intervals
            , ', '
        )
    )
    FROM entity_v
    WHERE entity_type = 'Stats File'
;

SELECT format(
$$CREATE TYPE %s AS (
    snapshot_version     int
    , %s
    , %s
);$$
    , type_name__snapshot(entity_type)
    , CASE WHEN entity_type = 'Stats File' THEN 'snapshot_timestamp     timestamptz'
        ELSE 'transaction_start     timestamptz
    , clock_timestamp        timestamptz'
    END
    , array_to_string(
        array( SELECT entity || ' ' || type_name__raw(entity) || '[]' FROM entity WHERE entity_type = t.entity_type ORDER BY entity )
        , E'\n    , '
    )
)
    FROM (SELECT DISTINCT entity_type FROM entity) t
;

SELECT 
$$CREATE TYPE snapshot_all AS (
    snapshot_version     int
    , database_name         text
    , cluster_identifier    text
    , catalog               snapshot_catalog
    , stats_file            snapshot_stats_file
    , other_status          snapshot_other_status
);$$
;
