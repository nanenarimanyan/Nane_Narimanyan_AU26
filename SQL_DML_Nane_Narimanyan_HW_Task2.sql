-- TASK 2


-- 1


DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) AS x;


SELECT COUNT(*) AS total_rows
FROM public.table_to_delete;

-- 2 

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *,
           total_bytes - index_bytes
           - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class AS c
        LEFT JOIN pg_namespace AS n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) AS a
) AS a
WHERE table_name LIKE '%table_to_delete%'
  AND table_schema = 'public';

-- Observed initial size: 575 MB.

-- 3 


DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;


SELECT COUNT(*) AS remaining_rows
FROM public.table_to_delete;

--b

SELECT
    pg_size_pretty(
        pg_total_relation_size('public.table_to_delete')
    ) AS size_after_delete,
    pg_total_relation_size('public.table_to_delete')
        AS size_in_bytes;

-- Observed: 575 MB.
-- DELETE did not immediately reduce physical table size.

-- c


VACUUM FULL VERBOSE public.table_to_delete;

--d

SELECT
    COUNT(*) AS remaining_rows,
    pg_size_pretty(
        pg_total_relation_size('public.table_to_delete')
    ) AS size_after_vacuum,
    pg_total_relation_size('public.table_to_delete')
        AS size_in_bytes
FROM public.table_to_delete;

-- Observed:
-- Remaining rows: 6666667
-- Table size: 383 MB.

-- Conclusion:
-- DELETE removes rows logically but does not immediately reduce the table's physical disk allocation.
-- VACUUM FULL rewrites the table, removing dead row versions and reclaiming unused disk space.

-- e
DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) AS x;


SELECT
    COUNT(*) AS rows_before_truncate,
    pg_size_pretty(
        pg_total_relation_size('public.table_to_delete')
    ) AS size_before_truncate,
    pg_total_relation_size('public.table_to_delete')
        AS size_in_bytes
FROM public.table_to_delete;

-- Expected:
-- Rows: 10000000
-- Size: approximately 575 MB.



-- 4

-- Record execution time from pgAdmin's Messages tab.

TRUNCATE TABLE public.table_to_delete;

-- 4b

SELECT COUNT(*) AS remaining_rows
FROM public.table_to_delete;

-- 4c

SELECT
    pg_size_pretty(
        pg_total_relation_size('public.table_to_delete')
    ) AS size_after_truncate,
    pg_total_relation_size('public.table_to_delete')
        AS size_in_bytes;


-- Table size decreases substantially.
-- Exact size depends on PostgreSQL storage overhead.

-- Conclusion:
-- TRUNCATE removes all rows without scanning and deleting each row individually.
-- It is generally much faster than DELETE for clearing an entire table and releases its data storage immediately.


-- 1. DELETE:
--    Removes matching rows individually.
--    Can use a WHERE clause.
--    Creates dead row versions under PostgreSQL MVCC.
--    Does not immediately reclaim physical disk space.
--    Can be rolled back before COMMIT.
--    Fires row-level DELETE triggers where defined.

-- 2. VACUUM FULL:
--    Rewrites the table to remove dead row versions.
--    Reclaims unused disk space.
--    Requires an ACCESS EXCLUSIVE lock.
--    Cannot run inside an explicit transaction block.

-- 3. TRUNCATE:
--    Removes all rows without a WHERE clause.
--    Is generally faster than DELETE for removing all rows.
--    Releases table data storage without VACUUM FULL.
--    Can be rolled back before COMMIT in PostgreSQL.
--    Takes an ACCESS EXCLUSIVE lock.
--    Does not fire row-level DELETE triggers.

-- 4. TRANSACTION BEHAVIOR:
--    DELETE and TRUNCATE are transactional in PostgreSQL.
--    Both support ROLLBACK before COMMIT.
--    With Auto commit enabled, each completed statement is committed automatically.

-- 5. PERFORMANCE:
--    DELETE is suitable for selective row removal.
--    TRUNCATE is suitable for quickly clearing entire tables.
--    VACUUM FULL is useful for reclaiming substantial unused storage but can block concurrent operations.
