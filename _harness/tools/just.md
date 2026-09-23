# just

[just](https://github.com/casey/just) is a command runner. Recipes live in the root `justfile`; run `just` to list them.

Install: `winget install Casey.Just`

## Our recipes

| Recipe | Does |
|---|---|
| `just dev` | `cargo build -p dbt-sa-cli`, then `dbt deps` + `dbt build` on the harness |
| `just dbt <cmd>` | Runs the debug binary (`target/debug/dbt.exe`) in `_test-project` with `--profiles-dir .` |
| `just clean` | Deletes harness outputs (`target`, `logs`, `dbt_packages`, `external/*.parquet`/`.duckdb`) |

Recipes run in PowerShell (`set windows-shell`).
