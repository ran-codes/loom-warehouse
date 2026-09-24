# Plan — ran-codes/loom-polyglot#14: POC: red test, stub loom-polyglot crate, route DuckDB Python jobs to it

**PR title:** Route DuckDB Python models to a loom-polyglot stub crate

> Triage scorecard: impact 7 · difficulty 3 · blast radius 2 · risk 2 · testability 8
> Verdict at review: PICK UP — foundational first step of epic #15, small, locally verifiable. Issue: https://github.com/ran-codes/loom-polyglot/issues/14

## Problem

A dbt Python model on the DuckDB adapter fails at run time. `DbtAdapter::submit_python_job`
(`crates/dbt-adapter/src/adapter/adapter_impl.rs:1087`) has explicit arms for Snowflake,
BigQuery and Databricks. DuckDB falls into the shared catch-all `Impl(... | DuckDB | ...)` arm
(~line 1151), which returns `AdapterError::new(AdapterErrorKind::Internal, "Python models are
not supported for duckdb adapter")`. The harness (`_test-project`) has no Python model, so the gap is
never reproduced, and no `crates/loom-polyglot` exists to hold the replacement.

Corrections to the issue's framing:
- The error kind is `AdapterErrorKind::Internal`. The issue calls it "dbt9002", but that code was not
  confirmed against `crates/dbt-error/src/codes.rs` (`Unexpected = 9002`). Assert on the
  **message text**, not the code.
- The upstream diff is not "1 workspace line + 1 match arm". It is also: a
  `[workspace.dependencies]` entry, a dependency line in `crates/dbt-adapter/Cargo.toml`,
  removing `DuckDB` from the `Impl(...)` catch-all pattern, and `Cargo.lock` churn. Still small.
- The stub cannot take the adapter's full signature (`&QueryCtx`, `&mut dyn Connection`,
  `&State`) or return `AdapterResponse` (`crates/dbt-adapter/src/response.rs`). Those types live in
  `dbt-adapter` or its internals, and `dbt-adapter` will depend on `loom-polyglot`, so that would be
  a dependency cycle.
- The harness sets `+materialized: external` and `+static_analysis: strict` for every model
  (`_test-project/dbt_project.yml`). The epic promises a *table*, so `py_orders` sets
  `materialized="table"` explicitly. That uses `dbt-duckdb/macros/materializations/table.sql`,
  which declares `supported_languages=['sql', 'python']`. Static analysis on Python models is
  ignored with a warning (`crates/dbt-parser/src/validation.rs:29`), which is not a failure.

## Approach

1. **Red test.** Add `_test-project/models/py_orders.py`:
   ```python
   def model(dbt, session):
       dbt.config(materialized="table")
       return dbt.ref("stg_orders")
   ```
   (`stg_orders` exists under `models/staging`.) Run `just dev`. It should end with the
   `py_orders` node failing on "Python models are not supported for duckdb adapter". If it fails
   earlier (parse, materialization dispatch), stop: that's a finding that changes the plan (reopen
   review).
2. **Stub crate.** Create `crates/loom-polyglot/` with `Cargo.toml` (workspace-inherited
   `version`/`edition`/`license`/etc., matching e.g. `crates/dbt-error/Cargo.toml`) and `src/lib.rs`.
   Dependencies: `dbt-common` (for `AdapterError`, `AdapterErrorKind`, `AdapterResult`) and
   `minijinja` (for `Value`), both `{ workspace = true }`. Public API:
   ```rust
   pub fn submit_python_job(model: &minijinja::Value, compiled_code: &str) -> AdapterResult<()>
   ```
   Returns `Err(AdapterError::new(AdapterErrorKind::NotSupported /* or Internal */,
   "loom-polyglot: Python models on DuckDB are not implemented yet"))`. Keep the message
   distinctive: it's the success signal. Add it to `members` in root `Cargo.toml`, and add
   `loom-polyglot = { path = "crates/loom-polyglot" }` under `[workspace.dependencies]`
   (alphabetical, near line 234+).
3. **Wire the seam.** In `crates/dbt-adapter/Cargo.toml` add `loom-polyglot = { workspace = true }`.
   In `submit_python_job`, add before the catch-all:
   ```rust
   Impl(DuckDB, _) => {
       loom_polyglot::submit_python_job(model, compiled_code)?;
       unreachable!("loom-polyglot stub always errors") // replaced when data handoff lands
   }
   ```
   (Or build an `AdapterResponse` if a cheap constructor exists; don't invent one.) Remove `DuckDB`
   **only from the `Impl(...)` catch-all**. Keep it in the `Replay(...)` catch-all: replay mode is
   out of scope. Confirm `model`'s type in that fn is `minijinja::Value` (it's `&Value` via
   `crate::value::*`/minijinja). Adapt the stub's parameter type if it's a re-export.
4. **Green-ish check.** `cargo build -p dbt-sa-cli`, then `just dbt build`. `py_orders` now fails
   with the loom-polyglot message. All SQL models still pass.

## Open decisions

- `AdapterErrorKind::NotSupported` vs `Internal` for the stub error. Default: `NotSupported`
  (more honest). Either satisfies the success spec.
- If CI enforces the `dbt-fusion-workspace-hack` (cargo-hakari) crate on every member, the new crate
  may need that dependency line too. Check `crates/dbt-adapter/Cargo.toml:47` precedent. Add it
  only if a hakari check fails.

## Agreed Moves

- [ ] Move 1: Add `py_orders.py` to the test project and confirm `just dev` fails with dbt's "not supported" message
- [ ] Move 2: Add the `loom-polyglot` crate as a workspace member, with a stub that returns a clear "not implemented" error
- [ ] Move 3: Send DuckDB Python jobs to the stub and remove DuckDB from the catch-all branch
- [ ] Move 4: Re-run `just dev` and confirm the error is now the stub's

## Implementation steps

1. (Move 1) Create `_test-project/models/py_orders.py` as above.
2. (Move 1) Run `just dev`. Record the `py_orders` error line (short excerpt only, per AGENTS.md). Confirm it contains "Python models are not supported for duckdb adapter".
3. (Move 2) Create `crates/loom-polyglot/Cargo.toml` and `src/lib.rs` with the stub fn and one unit test asserting it returns `Err` whose message contains "loom-polyglot".
4. (Move 2) Register the crate in root `Cargo.toml` `members` and `[workspace.dependencies]`.
5. (Move 2) `cargo test -p loom-polyglot` passes.
6. (Move 3) Add the dependency to `crates/dbt-adapter/Cargo.toml`, add the `Impl(DuckDB, _)` arm, and drop `DuckDB` from the `Impl(...)` catch-all only.
7. (Move 3) `cargo check -p dbt-adapter` is clean (no unreachable-pattern warning, no cycle).
8. (Move 4) `cargo build -p dbt-sa-cli && just dbt build`. `py_orders` fails with the loom-polyglot message, and every SQL model and test still succeeds.
9. (Move 4) `git diff main -- crates/dbt-adapter Cargo.toml` shows only the dependency lines and the match-arm change.

## Success spec

| Criterion | Check | Phase |
|---|---|---|
| Red test reproduces the original gap before wiring | `just dev` output (step 2) contains "Python models are not supported for duckdb adapter" for `py_orders` | agent |
| Stub crate builds and errors as designed | `cargo test -p loom-polyglot` | agent |
| Adapter compiles with the new arm, no cycle or warnings | `cargo check -p dbt-adapter` | agent |
| DuckDB Python jobs route to the stub | `just dbt build` shows the loom-polyglot message for `py_orders`, not "not supported for duckdb adapter" | agent |
| No regression on SQL models | `just dbt build` shows all non-`py_orders` nodes succeed | agent |
| Upstream diff stays minimal | `git diff main --stat -- crates/dbt-adapter Cargo.toml` touches only Cargo manifests + `adapter_impl.rs`, a few lines | human-pre-merge |
| Maintainer sees the new error themselves | Run `just dev` locally and read the `py_orders` failure | human-pre-merge |

## Out of scope

Data handoff (Parquet export/CTAS), `uv` environment provisioning, the `py_write_table` macro
swap, Replay-mode DuckDB routing, and the model contract (`dbt.ref()` → polars `LazyFrame`,
`__arrow_c_stream__` returns, `session=None`). Those are decided in the issue but implemented in
later epic #15 steps.
