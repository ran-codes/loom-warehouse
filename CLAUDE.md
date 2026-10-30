@AGENTS.md
Build with `just build` (timed; one JSON record per build in `docs/build-times/`), never raw `cargo build`.

## Just Recipes

Run from the repo root. `just` with no args lists them.

| Recipe | Use it when |
|---|---|
| `just preview` | Live-preview the Loom Warehouse docs site (`docs-site/`, Astro Starlight) at `localhost:4321/loom-warehouse/`. Installs deps via pnpm first. **"start preview", "start docs", "docs dev", "preview the docs" all mean this.** |
| `just build` | Compile the debug `dbt` binary (timed; logs one JSON record to `docs/build-times/`) |
| `just dev` | `just build`, then `dbt deps` + `dbt build` on `_test-project/` |
| `just dbt <args>` | Run the already-built debug binary on the test project, no compile (e.g. `just dbt run`) |
| `just py-env` | (Re)create the venv Python models run in (`_test-project/project/.venv`, polars + pyarrow) |
| `just clean` | Delete test project outputs (target, logs, dbt_packages, external data files) |

`just preview` is a long-running dev server — start it in the background.
