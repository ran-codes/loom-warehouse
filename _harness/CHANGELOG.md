# Changelog

## 2026-09-24 — #14 Route DuckDB Python models to a loom-polyglot stub

- Added the `loom-polyglot` crate. Its `submit_python_job` is a stub that returns a "not implemented yet" error.
- DuckDB Python jobs now go to `loom-polyglot` instead of dbt's "Python models are not supported for duckdb adapter" error. Replay mode is unchanged.
- Added the `py_orders.py` Python model to `_test-project` as the red test.
