\set ON_ERROR_STOP on

\copy (SELECT c.relname AS table_name, pg_table_size(c.oid) AS table_bytes, pg_indexes_size(c.oid) AS all_index_bytes, pg_total_relation_size(c.oid) AS total_relation_bytes FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'practo' AND c.relkind = 'r' ORDER BY c.relname) TO 'benchmarks/results/large/table_storage.csv' WITH (FORMAT CSV, HEADER TRUE);

\copy (SELECT current_database() AS database_name, pg_database_size(current_database()) AS database_bytes, sum(pg_table_size(c.oid)) AS table_bytes, sum(pg_indexes_size(c.oid)) AS all_index_bytes, sum(pg_total_relation_size(c.oid)) AS total_relation_bytes FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'practo' AND c.relkind = 'r') TO 'benchmarks/results/large/storage_measurements.csv' WITH (FORMAT CSV, HEADER TRUE);
