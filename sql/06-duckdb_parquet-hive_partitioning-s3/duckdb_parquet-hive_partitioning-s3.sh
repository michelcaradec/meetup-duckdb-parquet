#!/bin/bash

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run the DuckDB script with the environment variables 
env $(cat ${SCRIPT_PATH}/.env | grep --invert-match "^#" | xargs) duckdb -f ${SCRIPT_PATH}/duckdb_parquet-hive_partitioning-s3.sql
