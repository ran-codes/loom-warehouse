# Test Workflow

Draft from issue #11. Iterate as we go.

## 1. Coverage levels

| Level | Command | When | Runs |
|---|---|---|---|
| 1. Crate | `just check <crate>` | While coding (fast) | `cargo fmt --all` + clippy + nextest on one crate |
| 2. Changed + dependents | `just ci` | Before pushing (**default**) | Crates changed vs `main` + their reverse deps |
| 3. Full workspace | `just ci-full` / `CI Trigger` label on the PR | Before merge (slow) | Mirror of `ci.yml`, whole workspace |

Level 2: diff vs `main` → map changed files to crates (`cargo metadata`) → clippy + nextest on those crates plus everything that depends on them (nextest `rdeps()` filterset).

## 2. Best practices

1. Inner loop = smallest scope. Never run the full suite while iterating.
2. Pre-push = changed + reverse deps. Catches what you could break without the full cost.
3. Full suite lives in remote CI, not the laptop. The remote run is the real gate.
4. Share the build cache: one `CARGO_TARGET_DIR` across worktrees (done in #12/#13).

## 3. Blockers

- [ ] Install `cargo-nextest`: `cargo install cargo-nextest --locked`
- [ ] Fix Windows-only clippy error: `dead_code` on `ACCESS_ALLOWED_ACE_TYPE` in `dbt-file-security/src/windows.rs:37`

## 4. Open questions

- Remote CI in scope? Issue follow-up says local only; Fable eval uses the `CI Trigger` label as the merge gate.
