set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# All worktrees build into one target/ beside them, so dependencies compile once and a fresh
# worktree starts warm (~40s, not ~5 min). The cost: builds in two worktrees at once queue on
# cargo's lock. sccache was tried instead and dropped — it hashes the worktree path, so a new
# worktree never hit the cache, and even a same-path rebuild only saved ~1 min of 5
# (docs/build-times/2026-11-05*). An existing CARGO_TARGET_DIR env var still wins.
export CARGO_TARGET_DIR := env("CARGO_TARGET_DIR", parent_directory(justfile_directory()) / ".cargo-target")

dbt_bin := CARGO_TARGET_DIR / "debug/dbt.exe"

# Interpreter for Python models. Relative to _test-project/project (the `dbt` recipe's working dir),
# so it points at the venv `just py-env` creates. Windows layout for now; the uv step of
# epic #15 replaces this with an interpreter dbt provisions itself.
export LOOM_PYTHON := env("LOOM_PYTHON", ".venv/Scripts/python.exe")

# Load-bearing for `just test` / `just gate`, same as CI: the parser/jinja recursion overflows
# the default thread stack and tests abort without it. 8 MiB.
export RUST_MIN_STACK := env("RUST_MIN_STACK", "8388608")

# list commands
default:
    @just --list

# compile the debug binary; logs one JSON record per build to docs/build-times/
#
# DX: the build hides two Cargo warnings that come from upstream's root Cargo.toml,
# which we leave unedited to keep upstream merges clean: an unused `arrow-flight` patch
# (plus its help lines) and a dev profile for upstream's private `sdf-frontend` crate.
# Every other warning still prints, and a failed build still stops the recipe. See #28.
build:
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1

# compile the debug binary, then run `dbt build` on the test project
dev:
    just build
    just dbt deps
    just dbt build

# Crates to lint/test when no crate is named: every crate that differs from main (commits on this
# branch + uncommitted edits), as `-p a -p b`. scripts/changed-crates.ps1 falls back to dbt-sa-cli.
scope := "$(powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/changed-crates.ps1)"

# fmt + clippy; compiles up to type-check, builds nothing. Default: crates changed vs main. just check dbt-common
check crate="":
    cargo fmt --all --check
    cargo clippy {{ if crate == "" { scope } else { "-p " + crate } }} --all-targets -- -D warnings

# run tests with nextest. Default: crates changed vs main. just test dbt-common
test crate="":
    cargo nextest run {{ if crate == "" { scope } else { "-p " + crate } }}

# the local gate before pushing: check + test across the whole workspace, same as CI (Linux).
# Name a crate to run the same three steps on it alone: just gate dbt-adapter
#
# One test binary is skipped: dbt-adapter's `snowflake_context_deadline_exceeded` downloads the
# Snowflake ADBC driver from public.cdn.getdbt.com and fails with "No such host" on this
# machine even outside the agent sandbox. Snowflake is outside this fork's DuckDB-only scope,
# so the gate drops that one binary. Every other test in dbt-adapter still runs. The DuckDB
# driver tests also download on first run, but that driver is already cached per user.
gate crate="":
    cargo fmt --all --check
    cargo clippy {{ if crate == "" { "--workspace" } else { "-p " + crate } }} --all-targets -- -D warnings
    cargo nextest run {{ if crate == "" { "--workspace" } else { "-p " + crate } }} -E 'not binary(snowflake_context_deadline_exceeded)'

# run the debug binary on the test project without compiling: just dbt run
[working-directory: '_test-project/project']
dbt *args:
    {{dbt_bin}} {{args}} --profiles-dir .

# (re)create the venv Python models run in: _test-project/project/.venv with polars + pyarrow
[working-directory: '_test-project/project']
py-env:
    uv venv --clear --python 3.12 .venv
    uv pip install --python .venv polars pyarrow

# live-preview the docs site at localhost:4321/loom-warehouse/ (installs deps first; fast from pnpm's global store)
[working-directory: 'docs-site']
preview:
    pnpm install
    pnpm dev

# delete the test project outputs
[working-directory: '_test-project/project']
clean:
    Remove-Item -Recurse -Force target, logs, dbt_packages, external/*.parquet, external/*.duckdb, external/*.duckdb.wal, external/.tmp -ErrorAction Ignore; exit 0
