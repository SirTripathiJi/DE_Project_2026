\set ON_ERROR_STOP on

DO $verify_indexes$
DECLARE
    index_count INTEGER;
    invalid_count INTEGER;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE NOT i.indisvalid OR NOT i.indisready)
      INTO index_count, invalid_count
    FROM pg_index i
    JOIN pg_class idx ON idx.oid = i.indexrelid
    JOIN pg_namespace ns ON ns.oid = idx.relnamespace
    WHERE ns.nspname = 'practo' AND left(idx.relname, 4) = 'idx_';
    IF index_count <> 19 THEN
        RAISE EXCEPTION 'expected 19 tuning indexes, found %', index_count;
    END IF;
    IF invalid_count <> 0 THEN
        RAISE EXCEPTION '% tuning indexes are not valid/ready', invalid_count;
    END IF;
    RAISE NOTICE 'all % tuning indexes are valid and ready', index_count;
END
$verify_indexes$;

\copy (SELECT tbl.relname AS table_name, idx.relname AS index_name, i.indisvalid AS valid, i.indisready AS ready, pg_relation_size(idx.oid) AS index_bytes, pg_table_size(tbl.oid) AS table_bytes, round(100.0 * pg_relation_size(idx.oid) / NULLIF(pg_table_size(tbl.oid), 0), 3) AS index_pct_of_table FROM pg_index i JOIN pg_class idx ON idx.oid = i.indexrelid JOIN pg_class tbl ON tbl.oid = i.indrelid JOIN pg_namespace ns ON ns.oid = idx.relnamespace WHERE ns.nspname = 'practo' AND left(idx.relname, 4) = 'idx_' ORDER BY tbl.relname, idx.relname) TO 'benchmarks/results/large/index_sizes.csv' WITH (FORMAT CSV, HEADER TRUE);
