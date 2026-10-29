# 🥪 The Jaffle Shop 🦘

_powered by the dbt Fusion engine_

Welcome! This is a sandbox project for exploring the basic functionality of Fusion. It's based on a fictional restaurant called the Jaffle Shop that serves [jaffles](https://en.wikipedia.org/wiki/Pie_iron).

To get started:
1. Set up your database connection in `~/.dbt/profiles.yml`. If you got here by running `dbt init`, you should already be good to go.
2. Run `dbt build`. That's it!

> [!NOTE]
> If you're brand-new to dbt, we recommend starting with the [dbt Learn](https://learn.getdbt.com/) platform. It's a free, interactive way to learn dbt, and it's a great way to get started if you're new to the tool.

## Python models (POC)

`models/py_orders.py` is a Python model on DuckDB. It builds a table from `stg_orders`;
`models/marts/py_orders_count.sql` reads that table and
`tests/assert_py_orders_matches_stg_orders.sql` checks the row counts match.

### Setup

```
just py-env   # once: _test-project/.venv with polars + pyarrow (needs uv)
just dev      # build the binary, then dbt build
```

`just dbt` runs Python models with `LOOM_PYTHON` (default `.venv/Scripts/python.exe`, relative to
this folder). Set it to any interpreter that has `polars` and `pyarrow`; unset, the crate falls
back to `python` on PATH.

### What runs

1. The dbt-duckdb macros export every `ref()` of the model to Parquet with `COPY`, before the
   Python child starts.
2. The `loom-warehouse` crate writes the rendered runner script to disk and runs it with
   `LOOM_PYTHON`. The script loads refs with `polars.scan_parquet`, calls `model(dbt, None)`,
   and writes the result to Parquet through Arrow.
3. The `table` materialization creates the table from that Parquet with `read_parquet`, then
   renames it into place.

Every file of a run is `target/loom-warehouse.<model>.<file>` — for `py_orders`:
`stg_orders.parquet`, `model.py`, `result.parquet`. The layout is flat because DuckDB's `COPY`
cannot create directories and `target/` is the one folder dbt guarantees. `just clean` removes it.

A Python error shows up in the dbt error for the model, with the last lines of the traceback.

Still to come in epic #15: `uv` provisioning the interpreter inside dbt, incremental models, R.

### Dev gotcha: stale `target/` after a worktree is deleted

In debug builds `rust-embed` reads its assets (typecheck builtins, macros) from the source folder
baked in at compile time. If a cached crate was compiled from a worktree that no longer exists,
`dbt` panics in `typemeta.rs` (`called Option::unwrap() on a None value`) on any model. Fix:
`cargo clean -p minijinja-typecheck-builtins` then rebuild.
