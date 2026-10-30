set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Build every worktree into the primary clone's target/ (parent of git's common dir).
# An existing CARGO_TARGET_DIR env var still wins.
export CARGO_TARGET_DIR := env("CARGO_TARGET_DIR", parent_directory(`git rev-parse --path-format=absolute --git-common-dir`) / "target")

dbt_bin := CARGO_TARGET_DIR / "debug/dbt.exe"

# Interpreter for Python models. Relative to _test-project/project (the `dbt` recipe's working dir),
# so it points at the venv `just py-env` creates. Windows layout for now; the uv step of
# epic #15 replaces this with an interpreter dbt provisions itself.
export LOOM_PYTHON := env("LOOM_PYTHON", ".venv/Scripts/python.exe")

# list commands
default:
    @just --list

# compile the debug binary, then run `dbt build` on the test project
dev:
    cargo build -p dbt-sa-cli
    just dbt deps
    just dbt build

# run the debug binary on the test project without compiling: just dbt run
[working-directory: '_test-project/project']
dbt *args:
    {{dbt_bin}} {{args}} --profiles-dir .

# (re)create the venv Python models run in: _test-project/project/.venv with polars + pyarrow
[working-directory: '_test-project/project']
py-env:
    uv venv --python 3.12 .venv
    uv pip install --python .venv polars pyarrow

# delete the test project outputs
[working-directory: '_test-project/project']
clean:
    Remove-Item -Recurse -Force target, logs, dbt_packages, external/*.parquet, external/*.duckdb, external/*.duckdb.wal, external/.tmp -ErrorAction Ignore; exit 0
