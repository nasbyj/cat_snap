\i test/pgxntool/setup.sql

CREATE TEMP VIEW versions AS
  SELECT * FROM unnest('{9.2,9.3,9.4,9.5,9.6}'::numeric[]) u(version)
;

SELECT CASE WHEN major_minor < 1000
            THEN major_minor::numeric / 100
            ELSE major_minor / 100
        END AS major_version
    FROM (SELECT current_setting('server_version_num')::int/100 AS major_minor) a
\gset
