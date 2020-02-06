CREATE FUNCTION cat_snap.gather_code(
    version numeric
    , entity text
) RETURNS text LANGUAGE plpgsql STABLE AS $body$
DECLARE
  e _cat_snap.entity;
  c _cat_snap.catalog;

  a _cat_snap.attribute;
BEGIN
  e := _cat_snap.entity__get(entity);
  c := _cat_snap.catalog__get(version, entity, missing_ok := TRUE);

  RETURN format(
    $$SELECT row(%s) FROM pg_catalog.%s$$
    , array_to_string(
      array(
        SELECT CASE WHEN array[attribute_name] <@ array(SELECT attribute_name FROM unnest(c.attributes))
              THEN attribute_name
              ELSE 'NULL'
              END
          FROM unnest(e.attributes || e.extra_attributes)
      )
      , ', '
    )
    , entity
  );
END
$body$;

CREATE FUNCTION cat_snap.snapshot_code(
  version numeric
  , cluster_identifier text DEFAULT NULL
  , snapshot_type text DEFAULT 'all'
  , indent text DEFAULT ''
  , raw boolean DEFAULT false
) RETURNS text LANGUAGE plpgsql STABLE AS $body$
DECLARE
  c_snapshot_type CONSTANT text := replace( lower(snapshot_type), ' ', '_' );
  c_entity_type CONSTANT text := initcap( replace( c_snapshot_type, '_', ' ' ) );

  v_out text;
  v_out_template text;

  /*
   * Templates
   */
  c_template_all CONSTANT text := $$row(
  1::int -- snapshot_version
  , current_database() -- database_name
  , %L::text -- cluster_identifier
  , (%s) -- catalog
  , (%s) -- stats_file
  , (%s) -- other_status
)$$
;

  c_template_partial CONSTANT text := $$row(
%1$s  1::int -- snapshot_version
%1$s  , %2$s
%1$s  , array(%3$s)
%1$s)
%1$s$$
;

  c_template_all_final CONSTANT text := $$SELECT %s;$$;
  c_template_partial_final CONSTANT text := $$%1$sSELECT %s$$;
BEGIN
  IF c_snapshot_type NOT IN ( 'all', 'catalog', 'stats_file', 'other_status' ) THEN
    -- TODO: add hint
    RAISE EXCEPTION 'Unknown snapshot type "%"', snapshot_type;
  END IF;

  IF c_snapshot_type = 'all' THEN
    /*
     * snapshot_type all
     */

    IF coalesce(indent,'') != '' THEN
      RAISE EXCEPTION 'indent may not be specified for an "all" snapshot';
    END IF;
    indent := '    ';

    v_out := format(
      c_template_all
      , cluster_identifier
      , indent || 'SELECT ' || cat_snap.snapshot_code(version, NULL, 'catalog', indent, raw := true )
      , indent || 'SELECT ' || cat_snap.snapshot_code(version, NULL, 'stats_file', indent, raw := true )
      , indent || 'SELECT ' || cat_snap.snapshot_code(version, NULL, 'other_status', indent, raw := true )
    );

    IF NOT raw THEN
      v_out := format(c_template_all_final, v_out);
    END IF;
  ELSE
    /*
     * snapshot_type != all
     */
    v_out_template := c_template_partial_final;

    IF cluster_identifier IS NOT NULL THEN
      RAISE EXCEPTION 'cluster_identifier may only be specified for snapshot type "all"';
    END IF;

    v_out := format(
      c_template_partial
      , indent
      , CASE WHEN c_snapshot_type = 'stats_file' THEN 'pg_stat_get_snapshot_timestamp()'
          ELSE $$now() -- transaction_start
$$ || indent || $$  , clock_timestamp()$$
        END
      , array_to_string(
          array(
            SELECT cat_snap.gather_code(version, entity)
              FROM _cat_snap.entity
              WHERE entity_type = c_entity_type::_cat_snap.entity_type
              ORDER BY entity
          )
          , E')\n' || indent || '  , array('
        )
      )
    ;

    IF NOT raw THEN
      v_out := format(c_template_partial_final, indent, v_out);
    END IF;
  END IF;

  RETURN v_out;
END
$body$;

-- vi: expandtab ts=2 sw=2
