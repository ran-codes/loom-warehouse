---
title: Worktrees and builds
description: Every worktree has its own target/; a git hook builds it in the background. Why nothing is shared, with the numbers.
---

Loom Warehouse development runs one git worktree per branch (Orca creates them). This page is what a new worktree costs, who pays it, and why the build cache is not shared. The measurements come from [PR #39](https://github.com/ran-codes/loom-warehouse/pull/39); the raw records are in `docs/build-times/`.

## The short version

- Every worktree builds into its own `target/`. Nothing is shared between worktrees, so a worktree can only ever run the `dbt.exe` it built itself.
- A new worktree pays one cold build: ~5 min for the debug binary, ~2–3 min more for the `dbt-sa-cli` test binaries, ~11 GB of disk.
- Nobody waits for it. `.githooks/post-checkout` starts `just prewarm` in the background the moment `git worktree add` returns (4s), at below-normal priority. By the time you need the binary it is usually there.
- One-time setup per clone: `git config core.hooksPath .githooks`. Git never enables hooks shipped inside a repo on its own.

## The hook

| | |
|---|---|
| Fires on | `git worktree add`, `git clone` (previous HEAD is the null ref). Not on ordinary checkouts or rebases. |
| Runs | `just prewarm` = `just build -NoLog` + `cargo nextest run --no-run -p dbt-sa-cli` |
| Priority | below normal, so several fresh worktrees never starve the one you are typing in |
| Log | `target/prewarm.log` in the new worktree |
| Skip | `LOOM_NO_PREWARM=1 git worktree add …` — docs-only branches, bisects, throwaway checkouts |
| Records | none; `-NoLog` keeps `docs/build-times/` for deliberate measurements |

Builds in two worktrees at once do not block each other — each has its own cargo lock. They do share the CPU.

## Timings (Windows, one machine)

| Scenario | Time | Crates compiled |
|---|---|---|
| New worktree, by hand | 241–300s | 741 |
| New worktree, by the hook (hidden window, below-normal priority) | 432s | 741 |
| Test binaries on top of a built worktree | +110–148s | ~53 workspace crates |
| Same worktree again, nothing changed | ~1s | 0 |
| Edit one crate | that crate and everything downstream of it | — |

## Why nothing is shared

Every way of sharing the build between worktrees was measured and rejected in PR #39:

| Approach | Fresh worktree | Problem |
|---|---|---|
| Shared `target/` or shared cargo build-dir | 111s | Cargo names Windows binaries without a per-checkout hash, so every worktree links the same `deps/dbt.exe`. Worktree B's build silently replaces worktree A's binary while A's fingerprints still say "fresh". Unfixable without a cross-worktree lock and forced relinks. |
| sccache | 298s, 0 of 681 hits | Its cache key includes the worktree path, so a new worktree never matches anything ([mozilla/sccache#2652](https://github.com/mozilla/sccache/issues/2652); the fix is an open PR). It also cannot cache workspace crates. Removed locally; CI keeps its own, where the path is fixed. |
| kache | 152s | Safe (own `target/` per worktree), but on NTFS it copies instead of hardlinking: +10 GB per worktree plus an 11 GB store, a daemon on every machine, and build scripts uncached on Windows by default. Not worth 1.5 min. |

Cargo itself has no safe cross-worktree cache today ([rust-lang/cargo#16804](https://github.com/rust-lang/cargo/issues/16804)); a shared cache is a 2026 cargo project goal with no date. Revisit when that lands or when kache links on NTFS.

## Why a fresh worktree is never 0s

Cargo identifies a workspace crate by its absolute source path. The same crate in a new worktree is, to cargo, a new crate with an empty incremental cache, so the ~80 workspace crates `dbt-sa-cli` depends on always recompile once per worktree. Registry dependencies are keyed by name and version — those are what a shared cache could have saved, and what the table above is about.

## New in v0.2

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer v0.2 posuere erat a ante venenatis dapibus, posuere velit aliquet. Donec ullamcorper nulla non metus auctor fringilla.
