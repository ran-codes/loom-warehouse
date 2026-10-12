# just

[just](https://github.com/casey/just) is a command runner. Recipes live in the root `justfile`; run `just` to list them.

Install: `winget install Casey.Just`

## Our recipes

| Recipe | Does |
|---|---|
| `just dev` | `cargo build -p dbt-sa-cli`, then `dbt deps` + `dbt build` on the harness |
| `just dbt <cmd>` | Runs the debug binary (`<primary clone>/target/debug/dbt.exe`) in `_test-project` with `--profiles-dir .` |
| `just clean` | Deletes harness outputs (`target`, `logs`, `dbt_packages`, `external/*.parquet`/`.duckdb`) |

Recipes run in PowerShell (`set windows-shell`).

## Shared target dir

- All worktrees build into the primary clone's `target/`. The justfile exports `CARGO_TARGET_DIR` for this; set `CARGO_TARGET_DIR` yourself to override it.
- A new worktree recompiles the repo's own crates once, because checkout gives every file a new mtime. Third-party crates are reused.
- Plain `cargo` outside `just` still uses the worktree-local `target/`.
- Known limits: the last build owns the single `dbt.exe`, and edits made before another worktree's build can be judged fresh and skip a rebuild. See [the known-limits comment](https://github.com/ran-codes/loom-warehouse/issues/12#issuecomment-5800113495).
