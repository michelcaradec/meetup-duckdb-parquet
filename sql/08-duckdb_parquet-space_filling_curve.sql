-- Commands to be pasted in the DuckDB CLI

-- Inspect the organization of row groups
CREATE OR REPLACE MACRO row_groups_inspect(parquet_file) AS TABLE
SELECT
    row_group_id AS row_group,
    printf('[%s-%s]', x_from, x_to) AS x,
    printf('[%s-%s]', y_from, y_to) AS y,
FROM (
    PIVOT (
        SELECT
            row_group_id,
            path_in_schema,
            stats_min_value,
            stats_max_value,
        FROM parquet_metadata(parquet_file)
        WHERE path_in_schema IN ('x', 'y')
    )
    ON path_in_schema IN ('x', 'y')
    USING
        first(stats_min_value) AS "from",
        first(stats_max_value) AS "to",
    ORDER BY row_group_id
);

-- Create a sample dataset with 2-dimensions (x, y) coordinates (values in [a-z])
CREATE OR REPLACE TABLE sample AS
SELECT
    chr((97 + random()* 10_000 % (122 - 97))::INTEGER) AS x,
    chr((97 + random()* 10_000 % (122 - 97))::INTEGER) AS y,
    (random() * 100)::INTEGER AS value,
FROM range(1_000_000) tbl(i);

SUMMARIZE sample;

-- Set excessively small row group size to split rows over multiple groups
-- Expected number of row groups: 100 (1_000_000 / 10_000)
SET VARIABLE row_group_size = 10_000;

--------------
-- No ordering
--------------

-- Create a Parquet file, with no ordering
COPY (
    FROM sample
)
TO './data/unordered.parquet' (
    FORMAT parquet,
    OVERWRITE true,
    ROW_GROUP_SIZE $row_group_size
);

-- Inspect the row groups
-- * The values of the fields `x` and `y` are uniformly dispatched over all row groups
FROM row_groups_inspect('./data/unordered.parquet');

------------------------
-- Hierarchical ordering
------------------------

-- Create a Parquet file, with hierarchical ordering (x, y)
COPY (
    FROM sample
    ORDER BY x ASC, y ASC
)
TO './data/hierarchical.parquet' (
    FORMAT parquet,
    OVERWRITE true,
    ROW_GROUP_SIZE $row_group_size
);

-- Inspect the row groups
-- * The values of the field `x` are dispatched on few consecutive row groups.
-- * The values of the field `y` are dispatched on multiple non-consecutive row groups
FROM row_groups_inspect('./data/hierarchical.parquet');

-------------------
-- Hilbert ordering
-------------------

-- Install the extension "Lindel"
-- https://query.farm/products/extensions/lindel/
SET allow_extension_repositories = 'allowed';

CREATE EXTENSION REPOSITORY IF NOT EXISTS query_farm WITH PREFIX 'https://duckdb-extensions.query.farm';

-- FROM duckdb_extension_repositories()
-- WHERE repository_name = 'query_farm';

INSTALL lindel FROM query_farm;

LOAD lindel;

-- Create a Parquet file, with Hilbert ordering
-- "Hilbert follows a space-filling curve with no long jumps between consecutive positions on its integer grid. It is a useful starting point for locality-oriented sorting."
COPY (
    FROM sample
    -- https://duckdb.org/docs/2.0/sql/data_types/numeric
    ORDER BY hilbert_encode([
        ascii(x) - 97,
        ascii(y) - 97
    ]::UTINYINT[2]) ASC
)
TO './data/hilbert.parquet' (
    FORMAT parquet,
    OVERWRITE true,
    ROW_GROUP_SIZE $row_group_size
);

-- Inspect the row groups
-- * The values of the fields `x` and `y` are dispatched in row groups according to their proximity.
FROM row_groups_inspect('./data/hilbert.parquet');

----------------------------
-- Morton (Z-order) ordering
----------------------------

-- Create a Parquet file, with Morton ordering
-- "Morton / Z-order interleaves the coordinate bits. Its simpler mapping has jumps at quadrant boundaries."
COPY (
    FROM sample
    -- https://duckdb.org/docs/2.0/sql/data_types/numeric
    ORDER BY morton_encode([
        ascii(x) - 97,
        ascii(y) - 97
    ]::UTINYINT[2]) ASC
)
TO './data/morton.parquet' (
    FORMAT parquet,
    OVERWRITE true,
    ROW_GROUP_SIZE $row_group_size
);

FROM row_groups_inspect('./data/morton.parquet');

---------
-- Search
---------

-- Get the data located in a given rectangle:
--
-- f
-- e    +---+
-- d    +---+
-- c
--  k l m n o p

-- Search in Parquet with no order
-- * All the row groups will be scanned.
EXPLAIN ANALYZE
SELECT avg(value) AS value
FROM read_parquet('./data/unordered.parquet')
WHERE
    x BETWEEN 'm' AND 'o'
    AND y BETWEEN 'd' AND 'e';

-- ╭─ Summary ───────────╮
-- │ Total Time: 0.0059s │
-- │ Data Read:   2.2 MB │
-- ╰─────────────────────╯
-- ╭────────────────────────────────────────╮
-- │ Projection                 1 row · 0µs │
-- │ Ungrouped Aggregate        1 row · 0µs │
-- │ Projection            9,675 rows · 0µs │
-- ╰────────────────────┒┎──────────────────╯
-- ╭─ Table Scan ───────┚┖──────────────────╮
-- │ Function: READ_PARQUET                 │
-- │ Projections: value                     │
-- │ Filters: (x >= 'm') AND (x <= 'o'),    │
-- │          (y >= 'd') AND (y <= 'e')     │
-- │ Total Files Read: 1                    │
-- │ Filename(s): ./data/unordered.parquet  │
-- │ Row Groups Scanned: 98 / 98            │ <===
-- │ 9,675 rows                      30.0ms │
-- ╰────────────────────────────────────────╯

-- Search in Parquet with hierarchical ordering
-- * Fewer row groups are scanned.
EXPLAIN ANALYZE
SELECT avg(value) AS value
FROM read_parquet('./data/hierarchical.parquet')
WHERE
    x BETWEEN 'm' AND 'o'
    AND y BETWEEN 'd' AND 'e';

-- ╭─ Summary ───────────╮
-- │ Total Time: 0.0082s │
-- │ Data Read:  71.8 kB │
-- ╰─────────────────────╯
-- ╭─────────────────────────────────────╮
-- │ Projection              1 row · 0µs │
-- │ Ungrouped Aggregate     1 row · 0µs │
-- │ Projection         9,675 rows · 0µs │
-- ╰──────────────────┒┎─────────────────╯
-- ╭─ Table Scan ─────┚┖─────────────────╮
-- │ Function: READ_PARQUET              │
-- │ Projections: value                  │
-- │ Filters: (x >= 'm') AND (x <= 'o'), │
-- │          (y >= 'd') AND (y <= 'e')  │
-- │ Total Files Read: 1                 │
-- │ Filename(s):                        │
-- │ ./data/hierarchical.parquet         │
-- │ Row Groups Scanned: 7 / 98          │ <===
-- │ 9,675 rows                   10.0ms │
-- ╰─────────────────────────────────────╯

-- Search in Parquet with Hilbert ordering
-- * Even less row groups are scanned.
EXPLAIN ANALYZE
SELECT avg(value) AS value
FROM read_parquet('./data/hilbert.parquet')
WHERE
    x BETWEEN 'm' AND 'o'
    AND y BETWEEN 'd' AND 'e';

-- ╭─ Summary ───────────╮
-- │ Total Time: 0.0040s │
-- │ Data Read:  61.6 kB │
-- ╰─────────────────────╯
-- ╭──────────────────────────────────────╮
-- │ Projection               1 row · 0µs │
-- │ Ungrouped Aggregate      1 row · 0µs │
-- │ Projection          9,675 rows · 0µs │
-- ╰───────────────────┒┎─────────────────╯
-- ╭─ Table Scan ──────┚┖─────────────────╮
-- │ Function: READ_PARQUET               │
-- │ Projections: value                   │
-- │ Filters: (x >= 'm') AND (x <= 'o'),  │
-- │          (y >= 'd') AND (y <= 'e')   │
-- │ Total Files Read: 1                  │
-- │ Filename(s): ./data/hilbert.parquet  │
-- │ Row Groups Scanned: 2 / 98           │ <===
-- │ 9,675 rows                    10.0ms │
-- ╰──────────────────────────────────────╯

-- Search in Parquet with Morton ordering
-- * Better than hierarchical, but worst than Hilbert (note this is strongly related to the nature and the distribution of the data).
EXPLAIN ANALYZE
SELECT avg(value) AS value
FROM read_parquet('./data/morton.parquet')
WHERE
    x BETWEEN 'm' AND 'o'
    AND y BETWEEN 'd' AND 'e';

-- ╭─ Summary ───────────╮
-- │ Total Time: 0.0145s │
-- │ Data Read:  81.2 kB │
-- ╰─────────────────────╯
-- ╭─────────────────────────────────────╮
-- │ Projection              1 row · 0µs │
-- │ Ungrouped Aggregate     1 row · 0µs │
-- │ Projection         9,675 rows · 0µs │
-- ╰──────────────────┒┎─────────────────╯
-- ╭─ Table Scan ─────┚┖─────────────────╮
-- │ Function: READ_PARQUET              │
-- │ Projections: value                  │
-- │ Filters: (x >= 'm') AND (x <= 'o'), │
-- │          (y >= 'd') AND (y <= 'e')  │
-- │ Total Files Read: 1                 │
-- │ Filename(s): ./data/morton.parquet  │
-- │ Row Groups Scanned: 6 / 98          │ <===
-- │ 9,675 rows                   60.0ms │
-- ╰─────────────────────────────────────╯
