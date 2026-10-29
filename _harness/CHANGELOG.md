# Changelog

## 2026-10-29 — #17 Materialize DuckDB Python models through a Parquet handoff

- `py_orders` now builds. The dbt-duckdb macros export each `ref()` to Parquet before the Python child runs, and `table.sql` creates the table from the child's `result.parquet` afterwards (`loom_prefix`, `loom_export_refs`, rewritten `py_write_table`).
- `loom-warehouse::submit_python_job` writes the runner script to `target/loom-warehouse.<model>.model.py` and runs it with `LOOM_PYTHON` (else `python`). A non-zero exit surfaces the last 20 lines of stderr in the dbt error. Signature unchanged; the DuckDB arm now returns an `OK` response.
- Run files are flat under `target/` as `loom-warehouse.<model>.<file>` because DuckDB's `COPY` cannot create directories.
- Harness: `just py-env` creates `_test-project/.venv` (polars, pyarrow) with `uv`; `just dbt` exports `LOOM_PYTHON` defaulting to that venv. Added `py_orders_count.sql` and the `assert_py_orders_matches_stg_orders` singular test.

## 2026-09-24 — #14 Route DuckDB Python models to a loom-warehouse stub

- Added the `loom-warehouse` crate. Its `submit_python_job` is a stub that returns a "not implemented yet" error.
- DuckDB Python jobs now go to `loom-warehouse` instead of dbt's "Python models are not supported for duckdb adapter" error. Replay mode is unchanged.
- Added the `py_orders.py` Python model to `_test-project` as the red test.
