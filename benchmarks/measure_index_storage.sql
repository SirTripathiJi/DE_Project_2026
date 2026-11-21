-- Read-only per-index size evidence for the 19 workload indexes from sql/05_indexes.sql.
-- Run against the indexed seed validation database after index creation.
SELECT current_database() AS database_name,
       current_setting('server_version') AS postgres_version,
       clock_timestamp() AS measured_at,
       table_relation.relname AS table_name,
       index_relation.relname AS index_name,
       pg_relation_size(index_entry.indexrelid) AS index_bytes,
       pg_table_size(table_relation.oid) AS table_bytes,
       round(100.0 * pg_relation_size(index_entry.indexrelid)
             / NULLIF(pg_table_size(table_relation.oid), 0), 3) AS index_pct_of_table
FROM pg_index AS index_entry
JOIN pg_class AS table_relation ON table_relation.oid = index_entry.indrelid
JOIN pg_class AS index_relation ON index_relation.oid = index_entry.indexrelid
JOIN pg_namespace AS table_schema ON table_schema.oid = table_relation.relnamespace
WHERE table_schema.nspname = 'practo'
  AND index_relation.relname LIKE 'idx\_%' ESCAPE '\'
ORDER BY table_relation.relname, index_relation.relname;
