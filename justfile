set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Each worktree builds into its own target/, so worktrees never wait on one cargo lock.
# sccache shares compiled crates across them. An existing CARGO_TARGET_DIR env var still wins.
export CARGO_TARGET_DIR := env("CARGO_TARGET_DIR", justfile_directory() / "target")
export RUSTC_WRAPPER := "sccache"

dbt_bin := CARGO_TARGET_DIR / "debug/dbt.exe"

# Interpreter for Python models. Relative to _test-project/project (the `dbt` recipe's working dir),
# so it points at the venv `just py-env` creates. Windows layout for now; the uv step of
# epic #15 replaces this with an interpreter dbt provisions itself.
export LOOM_PYTHON := env("LOOM_PYTHON", ".venv/Scripts/python.exe")

# list commands
default:
    @just --list

# compile the debug binary; logs the build time to docs/build-times.csv
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

# run the debug binary on the test project without compiling: just dbt run
[working-directory: '_test-project/project']
dbt *args:
    {{dbt_bin}} {{args}} --profiles-dir .

# (re)create the venv Python models run in: _test-project/project/.venv with polars + pyarrow
[working-directory: '_test-project/project']
py-env:
    uv venv --clear --python 3.12 .venv
    uv pip install --python .venv polars pyarrow

# delete the test project outputs
[working-directory: '_test-project/project']
clean:
    Remove-Item -Recurse -Force target, logs, dbt_packages, external/*.parquet, external/*.duckdb, external/*.duckdb.wal, external/.tmp -ErrorAction Ignore; exit 0
