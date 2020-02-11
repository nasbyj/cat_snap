-- NOTE: depends on entity.dmp for entity_type

CREATE FUNCTION type_name__raw(
  entity_name name
) RETURNS text LANGUAGE sql AS $body$
  SELECT replace( entity_name, 'pg_', 'raw_' )
$body$;

CREATE FUNCTION type_name__delta(
  entity_name name
) RETURNS text LANGUAGE sql AS $body$
  SELECT replace( entity_name, 'pg_', 'delta_' )
$body$;

CREATE FUNCTION type_name__snapshot(
  entity_catagory text
) RETURNS text LANGUAGE sql AS $body$
-- TODO: throw an error if type isn't valid
  SELECT 'snapshot_' || replace( lower(entity_catagory), ' ', '_' )
$body$;
CREATE FUNCTION type_name__snapshot(
  entity_catagory entity_type
) RETURNS text LANGUAGE sql AS $body$
  SELECT type_name__snapshot(entity_catagory::text)
$body$;

-- vi: expandtab ts=2 sw=2
