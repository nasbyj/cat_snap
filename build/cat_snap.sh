#!/bin/sh

echo_cat() {
  echo '-- THIS IS A GENERATED FILE. DO NOT EDIT!'
  echo "-- Generated from $1"
  cat $1
}

cat << _EOF_
-- THIS IS A GENERATED FILE. DO NOT EDIT!
-- Generated from $0

/*
 * Using temp objects will result in the extension being dropped after session
 * end. Create a real schema and then explicitly drop it instead.
 */
CREATE SCHEMA __cat_snap;

SET client_min_messages = WARNING;

CREATE SCHEMA cat_snap;
CREATE SCHEMA _cat_snap;

-- TODO: change this; it contaminates the original session
SET search_path = _cat_snap, cat_snap;
_EOF_

echo_cat generated/entity.dmp

echo '-- THIS IS A GENERATED FILE. DO NOT EDIT!'
echo '-- Generated from generated/types.sql'
echo 'SET search_path = cat_snap, _cat_snap;'
cat generated/types.sql

echo_cat generated/catalog.dmp

echo_cat build/functions.sql
echo_cat build/gather.sql
echo_cat build/delta.sql

echo
echo 'DROP SCHEMA __cat_snap CASCADE;'

# vi: expandtab ts=2 sw=2
