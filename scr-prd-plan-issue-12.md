# Plan — ran-codes/loom-polyglot#12: Share one Cargo target dir across worktrees via justfile

**PR title:** Build all worktrees into the primary clone's shared target dir

> Triage scorecard: impact 6 · difficulty 2 · blast radius 2 · risk 5 · testability 7
> (Scored on the shared-folder-only scope. The first-round risk of 7 and difficulty of 4 included the stale-build guard, which was deferred.)
> Verdict at review: PICK UP — saves ~16 min and ~50 GB per new worktree with a few lines of justfile; stale-build hazards are accepted and deferred.
> Issue: https://github.com/ran-codes/loom-polyglot/issues/12
> Deferred-risk record: https://github.com/ran-codes/loom-polyglot/issues/12#issuecomment-5800113495

## Problem

`target/` is gitignored, so each git worktree has its own Cargo target dir. A new worktree does a cold debug build (~16 min) and grows its own ~50 GB `target/`. The primary clone at `C:/Users/ranli/Documents/GitHub/loom-polyglot` already holds a 51 GB built `target/`.

Corrections to the issue's framing (verified in triage):

- **A fresh worktree does not get a fully incremental build.** Checkout gives every source file a new mtime, so all workspace crates, the repo's own ~84 crates, recompile once. Registry and third-party crates are reused. The issue's "Done when: incremental, not full rebuild" is reworded in the Success spec so that a correct fix doesn't read as a failure.
- **Branch switching doesn't rebuild "only the crates that differ".** Cargo's freshness check is mtime-only. With a shared dir, a worktree whose edits predate another worktree's build can be judged fresh and run the other worktree's code (reproduced on cargo 1.96.1). There is also one shared `debug/dbt.exe`, so the last build wins. **Both are accepted and out of scope**; the mitigations are recorded in the issue comment linked above.
- The justfile is not the only in-repo reference to `target/debug`: `_harness/tools/just.md` names it too.

## Approach

1. In `justfile`, after the `set windows-shell` line, add an exported `CARGO_TARGET_DIR`. It is derived from git and can be overridden from the environment:

   ```just
   # Build every worktree into the primary clone's target/ (parent of git's common dir).
   # An existing CARGO_TARGET_DIR env var still wins.
   export CARGO_TARGET_DIR := env("CARGO_TARGET_DIR", parent_directory(`git rev-parse --path-format=absolute --git-common-dir`) / "target")
   ```

   `export` makes every recipe line see it, so `cargo build -p dbt-sa-cli` in `dev` builds into the shared dir.

2. Replace `dbt_bin := justfile_directory() / "target/debug/dbt.exe"` with `dbt_bin := CARGO_TARGET_DIR / "debug/dbt.exe"`.

3. Leave the `clean` recipe alone. Its `target` is `_test-project/target`, which holds dbt's harness outputs, not Cargo's.

4. Update `_harness/tools/just.md`:
   - The `just dbt` row: the binary is `<primary clone>/target/debug/dbt.exe`, not the worktree-local path.
   - Add a short "Shared target dir" note covering four things. All worktrees build into the primary clone's `target/`; override with `CARGO_TARGET_DIR`. A new worktree recompiles the repo's own crates once, while third-party crates are reused. Plain `cargo` outside `just` still uses the worktree-local `target/`. Known limits (last build owns `dbt.exe`; edit-then-switch can skip rebuilds) link to the issue comment.

5. Optionally add one line to `_harness/dev-workflow.md` pointing at that note. Leave it out if it adds nothing.

Verified in triage: the expression evaluates to `C:/Users/ranli/Documents/GitHub/loom-polyglot/target` from both the primary clone and this linked worktree (`just --evaluate` with just 1.58.0).

## Open decisions

none

## Agreed Moves

- [ ] Move 1 — Point `just` builds and the `just dbt` program path at the primary clone's shared build folder
- [ ] Move 2 — Update the harness docs: shared folder, rebuild-once cost, a link to the known-limits comment
- [ ] Move 3 — Verify: a fresh worktree reuses third-party libraries, much faster than 16 min, and `just dbt` runs from the shared folder

## Implementation steps

1. (Move 1) Add the exported `CARGO_TARGET_DIR` assignment and its comment to `justfile`, after `set windows-shell`.
2. (Move 1) Change `dbt_bin` to `CARGO_TARGET_DIR / "debug/dbt.exe"`.
3. (Move 1) Run `just --evaluate` in this worktree. Expect `CARGO_TARGET_DIR` = `C:/Users/ranli/Documents/GitHub/loom-polyglot/target` and `dbt_bin` = `.../target/debug/dbt.exe`.
4. (Move 1) Run `$env:CARGO_TARGET_DIR='C:/tmp/x'; just --evaluate CARGO_TARGET_DIR`. Expect `C:/tmp/x`, which confirms the override.
5. (Move 2) Edit `_harness/tools/just.md` as described in Approach step 4.
6. (Move 2) Optionally add the pointer line to `_harness/dev-workflow.md`.
7. (Move 3) In a fresh worktree off this branch, run `just dev`. Every `Compiling` line should be a workspace crate, meaning it shows a local path in parentheses, and no registry crate should compile. Wall time should be well under 16 min. The worktree-local `target/` should not grow. Note: this is a full workspace-crate build, so leave it to the human per AGENTS.md's no-full-builds rule.
8. (Move 3) In that worktree, run `just dbt --version`. It should run the binary from the primary clone's `target/debug/`.

## Success spec

| Criterion | Check | Phase |
|---|---|---|
| Shared dir resolves to the primary clone from a linked worktree | `just --evaluate CARGO_TARGET_DIR` → `C:/Users/ranli/Documents/GitHub/loom-polyglot/target` | agent |
| `dbt_bin` points into the shared dir | `just --evaluate dbt_bin` → `.../loom-polyglot/target/debug/dbt.exe` | agent |
| An existing env var overrides the derived path | `$env:CARGO_TARGET_DIR='C:/tmp/x'; just --evaluate CARGO_TARGET_DIR` → `C:/tmp/x` | agent |
| Harness docs describe the shared dir, the rebuild-once cost, and link the limits comment | Read `_harness/tools/just.md`; it links `issuecomment-5800113495` | agent |
| A fresh worktree reuses third-party crates and builds much faster than 16 min | New worktree → `just dev`; only workspace crates show `Compiling`; time it | human-pre-merge |
| A fresh worktree's `target/` stays small | After `just dev`, the worktree has no `target/debug` (or it is negligible) | human-pre-merge |
| `just dbt` runs the shared binary and the harness passes | `just dbt --version` then `just dev` in the new worktree; `dbt build` succeeds | human-pre-merge |
| After merge, the primary clone still builds and runs normally | `just dev` from the primary clone on `main` | human-post-merge |

## Out of scope

- The stale-build guard (last-builder marker plus touching sources on a switch), per-worktree binary copies, `-Zchecksum-freshness`, and build-SHA detection. All deferred; see the issue comment.
- The Windows `dbt.exe` file lock across worktrees.
- Changing plain `cargo` behavior outside `just` (no `.cargo/config.toml` `target-dir`).
- CI and other machines. The path is derived per machine, and CI doesn't use the justfile.
- Cleaning up existing worktree-local `target/` dirs.
