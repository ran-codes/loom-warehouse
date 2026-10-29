# Plan — ran-codes/loom-warehouse#17: POC Phase 1 — data handoff, materialize DuckDB Python models via Parquet

**PR title:** Materialize DuckDB Python models through a Parquet handoff

> Part of epic #15. Builds on the stub from #14 / PR #16.
> Research notes: https://github.com/ran-codes/loom-warehouse/pull/22#issuecomment-6499232079

## Problem

`py_orders` reaches `loom_warehouse::submit_python_job` (`crates/dbt-adapter/src/adapter/adapter_impl.rs:1147`)
and dies there with the stub's "not implemented" error. Nothing exports `stg_orders`, nothing runs
Python, nothing writes a table. Upstream's `py_write_table`
(`crates/dbt-loader/src/dbt_macro_assets/dbt-duckdb/macros/adapters.sql:134`) assumes an
in-process DuckDB connection (`con.register`), which a Rust host cannot give a Python child.

Facts that shape the design (verified in code, see research notes):

- `statement('main', language='python')` renders its body (`create_table_as`) **first**, then
  calls `submit_python_job(model, compiled_code)` (`dbt-adapters/macros/etc/statement.sql:7-16`).
  Any `run_query` inside `create_table_as` therefore executes **before** the Python child starts.
- `table.sql` runs `rename_relation(intermediate_relation, target_relation)` **after** the
  statement (`dbt-duckdb/macros/materializations/table.sql:39-50`). A `run_query` placed between
  the two runs **after** the child exits.
- `py_script_postfix(model)` is already appended to the user's code
  (`dbt-tasks-sa/src/renderable/renderable/default.rs:232`). It defines `ref()`, which calls
  `dbt_load_df_function(refs[key])` with the **resolved relation string** produced by
  `resolve_model_name(ref(...))` (`dbt-adapters/macros/python_model/python.sql:12-45`). Our
  runner only has to supply that one function to `dbtObj(...)`.
- `model.refs` carries `{name, package, version}` only. Resolution lives in Jinja.

Consequence: **the macros do all the SQL; Rust only spawns the interpreter.** The stub signature
`submit_python_job(model: &Value, compiled_code: &str) -> AdapterResult<()>` does not change, and
the upstream Rust diff stays at the one match arm.

## Approach

All paths below are relative to the dbt process CWD, which `just dbt` pins to `_test-project/`.
Work dir per model: `target/loom-warehouse/<model.name>/`.

1. **Red tests.** Add a SQL model downstream of `py_orders` and a singular test comparing row
   counts with `stg_orders`. `just dbt build` fails on `py_orders` (stub error) and skips both.
2. **Macros** (`crates/dbt-loader/src/dbt_macro_assets/dbt-duckdb/macros/`):
   - `adapters.sql`, new helper `loom_workdir(model)` → `"target/loom-warehouse/" ~ model.name`.
   - `adapters.sql`, new helper `loom_export_refs(model, workdir)`: loop `model.refs` exactly as
     `build_ref_function` does (same `ref(*args, v=...)`, same `resolve_model_name`), and for each
     run `run_query("copy (select * from <resolved>) to '<workdir>/<n>.parquet' (format parquet)")`.
     Return `{resolved_relation_string: parquet_path}` so the keys match what `ref()` passes in.
   - `adapters.sql`, python branch of `duckdb__create_table_as` (~line 128): call
     `loom_export_refs` before `py_write_table`, pass the returned map and the workdir through.
   - `adapters.sql`, rewrite `py_write_table(temporary, relation, compiled_code, workdir, ref_paths)`:
     ```python
     {{ compiled_code }}

     import pathlib
     import polars as pl
     import pyarrow as pa
     import pyarrow.parquet as pq

     _LOOM_WORKDIR = pathlib.Path(r"{{ workdir }}")
     _LOOM_REFS = {{ ref_paths | tojson }}

     def _loom_load_df(relation_name):
         return pl.scan_parquet(_LOOM_REFS[relation_name])

     def main():
         dbt = dbtObj(_loom_load_df)
         df = model(dbt, None)
         if isinstance(df, pl.LazyFrame):
             df = df.collect()
         table = pa.RecordBatchReader.from_stream(df).read_all()  # any __arrow_c_stream__
         pq.write_table(table, _LOOM_WORKDIR / "result.parquet")

     if __name__ == "__main__":
         main()
     ```
   - `materializations/table.sql`, after the `main` statement (line ~41): if `language == 'python'`,
     `run_query("create table <intermediate_relation> as select * from read_parquet('<workdir>/result.parquet')")`.
     The existing rename then promotes it to `py_orders`.
3. **Rust** (`crates/loom-warehouse/src/lib.rs`, std only, no new deps):
   - `workdir = target/loom-warehouse/<model.name>`; `create_dir_all`; write `compiled_code` to
     `workdir/model.py`.
   - Interpreter: `LOOM_PYTHON` env var, else `python`.
   - `std::process::Command::new(interp).arg("model.py").current_dir(workdir).output()`.
   - Non-zero exit or spawn failure → `AdapterError::new(AdapterErrorKind::Internal, ...)` whose
     message includes the interpreter path and the last ~20 lines of stderr.
   - `Ok(())` on success. No cleanup: CTAS happens after we return, and `target/` is already
     covered by `just clean` / `dbt clean`.
4. **Adapter arm** (`adapter_impl.rs:1146-1149`): replace the `unreachable!` with
   `Ok(AdapterResponse::new().with_message("OK"))` (`crates/dbt-adapter/src/response.rs:47-51`).
5. **Dev environment.** `python` is not on PATH on the dev box; `uv` is. A local env exists at
   `_test-project/.venv` (Python 3.12.14, polars 2.1.0, pyarrow 26.0.0; gitignored). Add a
   `just py-env` recipe that recreates it, and make `just dbt` export
   `LOOM_PYTHON` defaulting to `.venv/Scripts/python.exe` when unset.
6. **Green.** `just dev` builds `py_orders`, the downstream model, and the row-count test.

## Open decisions

- **`run_query` vs `statement` for the CTAS in `table.sql`.** Default `run_query`: it is the
  standard helper for side-effect SQL inside materializations. Switch only if it fights the
  transaction wrapper (`run_hooks(..., inside_transaction=True)` brackets the main statement).
- **`pa.RecordBatchReader.from_stream`** needs pyarrow ≥ 15. The venv has 26. If a user return type
  lacks `__arrow_c_stream__` the runner raises a plain `TypeError`; that is the contract in #15.
- **Does `COPY ... TO` overwrite an existing Parquet file?** DuckDB does by default for a single
  file. Verify on the second `just dbt build`; add `(overwrite_or_ignore)` only if it fails.
- **`temp_directory` / `external` paths.** The harness defaults every model to
  `materialized: external, format: parquet`. `py_orders` opts into `table` in its config; the
  downstream SQL model inherits `external`. Both are fine; nothing to decide unless CTAS objects.

## Agreed Moves

- [x] Move 1: Add the downstream SQL model and the row-count singular test; confirm `just dbt build` is red at `py_orders` with the stub message
- [x] Move 2: Rewrite `py_write_table` and add the two `loom_*` helpers; export refs before the child, CTAS after
- [x] Move 3: Replace the stub body with write-file / spawn / check-exit, keep the signature
- [x] Move 4: Return an `OK` `AdapterResponse` from the DuckDB arm
- [x] Move 5: `just py-env` recipe and `LOOM_PYTHON` default in the `dbt` recipe
- [x] Move 6: `just dev` green; `--select py_orders` runs it alone; the second run (overwrite) also passes
- [x] Move 7: Update `scr-dag.mermaid` (COPY and CTAS move from the Rust arm to the macros), `_test-project/README.md`, `_harness/CHANGELOG.md`

## Implementation steps

1. (Move 1) Create `_test-project/models/marts/py_orders_count.sql`:
   `select count(*) as n from {{ ref('py_orders') }}`.
2. (Move 1) Create `_test-project/tests/assert_py_orders_matches_stg_orders.sql`: returns rows
   when `count(*)` of `py_orders` differs from `count(*)` of `stg_orders`.
3. (Move 1) `just dbt build`. `py_orders` errors with the loom-warehouse stub message; the new
   model and test are skipped. Record the short excerpt.
4. (Move 2) In `adapters.sql`, add `loom_workdir` and `loom_export_refs` next to `py_write_table`.
   Mirror `build_ref_function`'s loop verbatim (package, version, `.render()` guard,
   `resolve_model_name`).
5. (Move 2) In `duckdb__create_table_as`, python branch: set `workdir`, call `loom_export_refs`,
   pass both into `py_write_table`. Keep the existing Iceberg `write_strategy` guard.
6. (Move 2) Replace the body of `py_write_table` with the runner script above.
7. (Move 2) In `table.sql`, after `{%- endcall %}` of the `main` statement, add the
   `language == 'python'` CTAS `run_query`, using `loom_workdir(model)` for the path.
8. (Move 3) Implement `submit_python_job` in `crates/loom-warehouse/src/lib.rs` as described.
   Read `model.name` via `model.get_attr("name")` (same pattern as
   `crates/dbt-adapter/src/python/databricks/mod.rs:22-41`).
9. (Move 3) Add one unit test: `LOOM_PYTHON` pointing at a non-existent path returns `Err` whose
   message contains that path. `cargo test -p loom-warehouse` passes.
10. (Move 4) Edit the `Impl(DuckDB, _)` arm; `cargo check -p dbt-adapter` is clean.
11. (Move 5) `justfile`: add `py-env` (`uv venv --python 3.12 .venv` then
    `uv pip install --python .venv polars pyarrow`, working-directory `_test-project`), and
    `export LOOM_PYTHON := env("LOOM_PYTHON", ".venv/Scripts/python.exe")` scoped to the `dbt`
    recipe's working directory. Note the Windows path in a comment; Phase 2 removes it.
12. (Move 6) `cargo build -p dbt-sa-cli && just dbt build`. All nodes pass, including the new
    test. Inspect `target/loom-warehouse/py_orders/` for `stg_orders.parquet`, `model.py`,
    `result.parquet`.
13. (Move 6) `just dbt build --select py_orders` runs only `py_orders`. `just dbt build` a second
    time passes (overwrite path).
14. (Move 6) Break the model on purpose (`return 42`) once, confirm the error surfaces the Python
    traceback, revert.
15. (Move 6) `git diff main --stat -- crates/` touches only `adapter_impl.rs`, `loom-warehouse/`,
    `dbt-duckdb/macros/adapters.sql`, `dbt-duckdb/macros/materializations/table.sql`.
16. (Move 7) Update `scr-dag.mermaid` steps 9 and 14 to sit under the macros, not the Rust arm.
17. (Move 7) Extend the "Python models (POC)" section of `_test-project/README.md`: what runs,
    the `LOOM_PYTHON` / `just py-env` setup, where the work dir is. Add a dated entry to
    `_harness/CHANGELOG.md`.

**Docs rule for this POC** (unchanged from #14): keep docs and changelog in our own folders. No
`changie new`, nothing under `.changes/`, no edits to `.agents/`.

## Success spec

| Criterion | Check | Phase |
|---|---|---|
| Red before green | Step 3 shows the stub message for `py_orders`; downstream model and test skipped | agent |
| Rust unit test | `cargo test -p loom-warehouse` | agent |
| Adapter compiles | `cargo check -p dbt-adapter` | agent |
| `py_orders` materializes as a DuckDB table | `just dbt build` passes; `target/loom-warehouse/py_orders/result.parquet` exists | agent |
| Downstream SQL model reads it | `py_orders_count` passes and the singular test passes | agent |
| Selection works | `just dbt build --select py_orders` runs one node | agent |
| Re-run works | Second `just dbt build` passes (Parquet overwrite, table replace) | agent |
| Python errors surface | Step 14 shows the traceback in the dbt error | agent |
| Upstream diff stays minimal | Step 15 file list | human-pre-merge |
| Docs stay in our own folders | `git diff main --stat` has nothing under `.changes/` or `.agents/` | agent |
| DAG and docs read correctly | Read `scr-dag.mermaid`, README section, changelog entry | human-pre-merge |
| Maintainer sees it run | `just py-env && just dev` locally | human-pre-merge |

## Out of scope

`uv` provisioning inside dbt (Phase 2), incremental materialization, R, MotherDuck, Replay-mode
DuckDB, temp-dir cleanup, error-surfacing polish beyond stderr passthrough, environment caching,
and non-Windows defaults for `LOOM_PYTHON`.
