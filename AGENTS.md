# Project Instructions (AI Agents)

These instructions are for coding agents (Codex CLI, Claude Code, etc).

Paths in this file and in `.agents/` are relative to the directory containing this file.

## Hard Rules

### Scope

- This repo is a frozen fork of dbt OSS, which supports many adapters. Loom Warehouse supports only DuckDB.
- Adapter changes go only to the DuckDB adapter (e.g. the `DuckDB` arms in `dbt-adapter`, `dbt_macro_assets/dbt-duckdb/`). Leave every other adapter as forked.

### Code Style

- Follow existing code style and patterns in the given crate/module.
- Keep changes minimal and focused to the task at hand.
- Prefer simple, readable code over clever or complex solutions.

### Changelog

- Never manually create or write changelog YAML files. Always use `changie new` to generate entries.
- Run `changie new` from the repository root with flags: `changie new --kind "<kind>" --body "<description>" --custom "project=<project>" --custom "issue=<number>" --custom "author=<handle>" --interactive=false`
- For optional empty fields (`issue`, `author`), prompt the user if running locally or pass a space (e.g., `--custom "issue= "`) then edit the generated file to replace `' '` with `""`.

### Running dev commands

- Never run blanket `cargo` commands without `-p <crate>` unless explicitly asked.
- Avoid context pollution: don’t paste long logs; prefer LLM-friendly JSONL output and short excerpts.
- Avoid full builds and full test runs during iteration; keep commands scoped and fast.

## Where To Look Next (Task-Specific)

- Respect author preferences (optional/local): `AGENTS.local.md`
- When working on Adapters: `.agents/adapters.md`. Adapters consist of the following crates:
  - `dbt-adapter`
  - `dbt-adapter-core`
  - `dbt-adapter-sql`
  - `dbt-auth`
  - `dbt-sql-keywords`
  - `dbt-adbc`
- When working on telemetry/tracing: `.agents/telemetry-tracing.md`
- When working on dbt-docs-server (static site + DuckDB-WASM in the browser): `.agents/dbt-docs-server.md`
- Always check for nested `AGENTS.md` files in subdirectories you modify
- If context is not enough, try reading repo overview / architecture as last resort: `README.md`

## Just Recipes

Run from the repo root. `just` with no args lists them.

| Recipe | Use it when |
|---|---|
| `just preview` | Live-preview the Loom Warehouse docs site (`docs-site/`, Astro Starlight) at `localhost:4321/loom-warehouse/`. Installs deps via pnpm first. **"start preview", "start docs", "docs dev", "preview the docs" all mean this.** |
| `just build` | Compile the debug `dbt` binary (timed; logs one JSON record to `docs/build-times/`) |
| `just dev` | `just build`, then `dbt deps` + `dbt build` on `_test-project/` |
| `just check [crate]` | `cargo fmt --check` + `cargo clippy -D warnings`. Default: every crate changed vs main; name one to narrow. Compiles to type-check only; ~7s when nothing changed |
| `just test [crate]` | `cargo nextest run`. Default: every crate changed vs main; name one to narrow. ~3s when nothing changed |
| `just gate [crate]` | The local gate before pushing: fmt + clippy + nextest across the whole workspace — what CI runs. ~3 min. Name a crate to run the same steps on it alone |
| `just dbt <args>` | Run the already-built debug binary on the test project, no compile (e.g. `just dbt run`) |
| `just py-env` | (Re)create the venv Python models run in (`_test-project/project/.venv`, polars + pyarrow) |
| `just clean` | Delete test project outputs (target, logs, dbt_packages, external data files) |

`just preview` is a long-running dev server — start it in the background.

## Test Suite

Dev loop: `just check [crate]` + `just test [crate]`. Gate before pushing: `just gate` (whole workspace, mirrors CI). CI runs the same three cargo commands on Linux, opt-in per PR via the `CI Trigger` label.

| Command | Scope |
|---|---|
| `just check` | fmt + clippy, crates changed vs main |
| `just test` | nextest, crates changed vs main |
| `just gate` | all three, all crates |
