#!/bin/sh

# attribute type is needed by types.sql, which loads entity.dmp
cat common/types.sql

cat << _EOF_
CREATE TYPE entity_type AS ENUM(
	'Catalog'
	, 'Stats File'
	, 'Other Status'
);

CREATE TABLE entity(
	entity				text		NOT NULL PRIMARY KEY
	, entity_type		entity_type	NOT NULL
	, attributes		attribute[]	NOT NULL
	, extra_attributes	attribute[]
	, delta_keys		text[]		
	, delta_counters	text[]		
	, delta_fields	text[]		
);

COMMENT ON COLUMN entity.delta_keys IS 'Fields used to verify that two stat types that are being deltaed from each other refer to the same entity.';
COMMENT ON COLUMN entity.delta_fields IS 'Fields that are counters. These can not be deltaed normally; they require special logic.';
COMMENT ON COLUMN entity.delta_fields IS 'Fields to delta when performing deltaion.';
_EOF_

psql -qt -v ON_ERROR_STOP=1 -f meta/entity.sql || exit 1

cat << _EOF_
UPDATE entity SET delta_keys = delta_keys || array['queryid'] WHERE entity = 'pg_stat_statements' AND NOT delta_keys @> array['queryid'];

CREATE VIEW entity_type_mapping_v AS
	SELECT * FROM (
		VALUES
			/*
			 * Unfortunately there's some odd behavior with FQNs for some types
			 * (like smallint), so don't use pg_catalog here. :(
			 */
			('regproc'::text, 'regprocedure'::text)
			, ('pg_node_tree', '_cat_snap.pg_node_tree__text')
	) a(base_type, corrected_type)
		
;

CREATE VIEW entity_v AS
    SELECT *
        , array(
            SELECT attribute_name || ' ' || attribute_type
                FROM unnest(e.attributes || e.extra_attributes) a
            ) AS base
		, array(
			SELECT a.attribute_name || ' ' || coalesce(m.corrected_type, a.attribute_type)
                FROM unnest(e.attributes || e.extra_attributes) a
				LEFT JOIN entity_type_mapping_v m ON a.attribute_type = m.base_type
			) AS corrected
        , array(
            SELECT attribute_name
                    || CASE WHEN array[attribute_name] <@ (e.delta_counters || e.delta_fields) THEN '_d' ELSE '' END
                    || ' '
                    || attribute_type
                FROM unnest(e.attributes || e.extra_attributes) a
            ) AS delta
        , array(
            SELECT attribute_name || '_d interval'
                FROM unnest(e.attributes || e.extra_attributes) a
                WHERE attribute_type::text ~ '^timestamp with'
            ) AS intervals
    FROM entity e
    ORDER BY entity
;
_EOF_

# vi: noexpandtab ts=4 sw=4
