# just

[just](https://github.com/casey/just) is a command runner. Recipes live in the root `justfile`; run `just` to list them.

Install: `winget install Casey.Just`

## Our recipes

| Recipe | Does |
|---|---|
| `just dev` | `cargo build -p dbt-sa-cli`, then `dbt deps` + `dbt build` on the test project |
| `just dbt <cmd>` | Runs this worktree's debug binary (`target/debug/dbt.exe`) in `_test-project/project` with `--profiles-dir .` |
| `just prewarm` | `just build -NoLog` + the `dbt-sa-cli` test binaries; what the post-checkout hook runs in the background for a new worktree |
| `just clean` | Deletes test project outputs (`target`, `logs`, `dbt_packages`, `external/*.parquet`/`.duckdb`) |

Recipes run in PowerShell (`set windows-shell`).

## Worktrees and the build cache

- Every worktree builds into its own `target/` (the justfile exports `CARGO_TARGET_DIR`; set it yourself to override). Nothing is shared between worktrees, so a worktree can only ever run the `dbt.exe` it built.
- A new worktree therefore pays one cold build, ~4–5 min on a fast Windows machine. `.githooks/post-checkout` starts `just prewarm` in the background the moment `git worktree add` finishes, so it is usually done before you need it; progress is in `target/prewarm.log`.
- The hook is committed but git never enables repo hooks by itself. Once per clone: `git config core.hooksPath .githooks`.
- The prewarm runs at below-normal priority, so parallel prewarms never starve foreground work. Skip it for one worktree (docs-only, review, bisect) by setting `LOOM_NO_PREWARM=1` when you run `git worktree add`.
- Sharing was tried and rejected in [PR #39](https://github.com/ran-codes/loom-warehouse/pull/39): a shared target or build dir lets worktrees overwrite each other's `dbt.exe` (cargo names Windows binaries without a per-checkout hash), sccache never hit across worktrees, and kache copies instead of linking on NTFS. Timings are logged in `docs/build-times/`.
