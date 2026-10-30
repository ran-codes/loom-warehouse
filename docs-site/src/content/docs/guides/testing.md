---
title: Testing strategy
description: Three tiers — dev loop, local gate, CI — and the just recipes that run them.
---

Preliminary docs from [PR #35](https://github.com/ran-codes/loom-warehouse/pull/35) (issue #33). Windows timings, one machine.

## The three tiers

| Tier | Command | Scope | When |
|---|---|---|---|
| Dev loop | `just check` + `just test` | crates changed vs main | while coding |
| Local gate | `just gate` | all 85 crates | before pushing |
| CI | `.github/workflows/ci.yml` | all crates, Linux | opt-in per PR via the `CI Trigger` label |

All three run the same cargo commands: `fmt --check`, `clippy -D warnings`, `nextest run`. CI is Linux-only, so a green local run on Windows is not a guarantee of a green CI run.

## How the reference repos do it

| Tier | salurbal.org | loom-cms | loom-warehouse |
|---|---|---|---|
| Dev loop | `pnpm check` + `pnpm test` | `pnpm check` + `pnpm test` | `just check` + `just test` |
| Local gate | `pnpm build` = check → test → build-lean | `pnpm check` + `pnpm test` + `pnpm build` | `just gate` |
| CI | `pnpm build-lean` (SWA deploy) | `pnpm check` + `pnpm test` + `pnpm build`, label-gated | `fmt` + `clippy` + `nextest`, label-gated |

Both reference repos keep CI light and put the real gate in a local script run before pushing. loom-warehouse follows the same shape.

## Loom scripts → Rust equivalents

| Loom script | Rust equivalent | `just` recipe |
|---|---|---|
| `check:eslint` + `check:types` | `cargo clippy -- -D warnings` | `just check` |
| `check:prettier` | `cargo fmt --all --check` | `just check` |
| `test` (vitest) | `cargo nextest run` | `just test` |
| `build` (local gate) | all three, whole workspace | `just gate` |

`cargo check` (the `tsc` analog) needs no recipe of its own: clippy runs it as its first step.

## The recipes

| Recipe | Composed of | Scope |
|---|---|---|
| `just check [crate]` | `cargo fmt --all --check` + `cargo clippy --all-targets -- -D warnings` | crates changed vs main; or the named crate |
| `just test [crate]` | `cargo nextest run` | crates changed vs main; or the named crate |
| `just gate [crate]` | `just check` + `just test` | all crates; or the named crate |

"Crates changed vs main" is computed by `scripts/changed-crates.ps1`: every crate under `crates/` touched by commits on the branch or by uncommitted edits. If nothing changed it falls back to `dbt-sa-cli`, the binary crate.

`just gate` skips one test binary, `dbt-adapter`'s `snowflake_context_deadline_exceeded`: it downloads the Snowflake ADBC driver from `public.cdn.getdbt.com`, which does not resolve on the dev machine, and Snowflake is outside this fork's DuckDB-only scope.

## What each command compiles

Check and test only compile — they never produce the app. Every command recompiles only the crates whose code changed; everything else comes from cache.

| Command | What it compiles | Output |
|---|---|---|
| `just build` | full code → machine code | `dbt.exe` |
| `just check` | code up to type-check, no machine code | nothing, just errors |
| `just test` | code + the `#[test]` fns | a test binary, then runs it |

## Timings

Windows, per-worktree `target/` + sccache.

| Recipe | Cold | Warm (nothing changed) |
|---|---|---|
| `just check` (one crate) | 188s | 7s |
| `just test` (one crate) | 295s | 3s |
| `just gate` (all crates) | not measured | 175s |

Gate floor is ~175s: the 6,780 tests always rerun (~98s), test compile check ~44s, fmt + clippy ~10s.

## What the test suite is

6,601 `#[test]` fns across 65 of 85 crates, all run by `cargo nextest run`.

| Kind | Where | Files | Tests |
|---|---|---|---|
| Unit (inline) | `src/*.rs`, `#[cfg(test)] mod tests` | 476 | 5,699 |
| Integration | `crates/*/tests/*.rs` (15 crates) | 50 | 370 |
| Other dirs | benches / fixtures / non-src paths | — | ~530 |
| `#[ignore]` | need live warehouse creds | — | 48 |

Heaviest: `dbt-adapter` 1,489 · `dbt-schemas` 677 · `dbt-parser` 400.

## Windows setup

`just gate` went green on Windows only after three environment fixes.

| # | Blocker | Fix |
|---|---|---|
| 1 | 5 clippy lints in Windows-only or Unix-gated code that Linux CI never compiles | Fixed in source |
| 2 | Snowflake ADBC driver download fails (`No such host`) | One test binary skipped in `gate` |
| 3 | 10 `dbt-deps` tests need symlinks (`os error 1314`) | Windows Developer Mode on — see `CONTRIBUTING.md` |

`RUST_MIN_STACK=8388608` is exported by the justfile, same as CI: the parser/jinja tests abort without it.
