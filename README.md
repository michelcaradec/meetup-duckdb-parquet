# DuckDB & Parquet

The data analysis winning team.

<details>
<summary>Table of contents</summary>

- [Abstract](#abstract)
- [Bootstrap](#bootstrap)
- [Demonstration Material](#demonstration-material)

</details>

## Abstract

Project used for the presentation at the [Meetup Python Rennes](https://www.meetup.com/python-rennes/events/316995867/).

## Bootstrap

1. Install uv

    ```bash
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
    ```

2. Install the Python requirements:

    ```bash
    uv sync
    ```

3. Install [DuckDB](https://duckdb.org/):

    ```bash
    curl https://install.duckdb.org | bash
    ```

> [!IMPORTANT]
> The minimum version `2.0.0` must be used, as some new syntax (such as the `$variable` [shorthand](https://duckdb.org/docs/2.0/sql/statements/set_variable#the-name-shorthand)) is used in the SQL scripts.

4. Optional: install the "man in the middle" proxy [mitmproxy](https://www.mitmproxy.org/):

    ```bash
    uv tool install mitmproxy
    uv tool update-shell
    ```

## Demonstration Material

- [DuckDB CLI](./sql/01-duckdb_cli.sql).
- [SQL On Steroids](./notebook/02-reasons_to_like_duckdb.ipynb).
- [Python Client](./notebook/03-python_client.ipynb).
- [DuckDB & Parquet - Metadata](./notebook/04-duckdb_parquet-metadata.ipynb).
- [DuckDB & Parquet - Hive Partitioning](./notebook/05-duckdb_parquet-hive_partitioning.ipynb).
- [DuckDB & Parquet - Hive Partitioning - S3](./sql/06-duckdb_parquet-hive_partitioning-s3/README.md).
- [DuckDB & Parquet - Row Groups](./notebook/07-duckdb_parquet-row_groups.ipynb).
- [DuckDB & Parquet - Space Filling Curve](./sql/08-duckdb_parquet-space_filling_curve.sql).
- [DuckDB & Parquet - Bloom Filter](./notebook/09-duckdb_parquet-bloom_filter.ipynb).
