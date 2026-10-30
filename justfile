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
#
# DX: the build hides two Cargo warnings that come from upstream's root Cargo.toml,
# which we leave unedited to keep upstream merges clean: an unused `arrow-flight` patch
# (plus its help lines) and a dev profile for upstream's private `sdf-frontend` crate.
# Every other warning still prints, and a failed build still stops the recipe. See #28.
dev:
    @$hide = $false; cargo build -p dbt-sa-cli --color always 2>&1 | ForEach-Object { \
        $line = "$_"; $plain = $line -replace '\x1b\[[0-9;]*m', ''; \
        if ($plain -match '^warning: patch `arrow-flight ') { $hide = $true; return }; \
        if ($plain -match '^warning: profile package spec `sdf-frontend`') { return }; \
        if ($hide -and $plain -match '^(help: |      \S)') { return }; \
        $hide = $false; $line \
    }; exit $LASTEXITCODE
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

# live-preview the docs site at localhost:4321/loom-warehouse/ (installs deps first; fast from pnpm's global store)
[working-directory: 'docs-site']
preview:
    pnpm install
    pnpm dev

# delete the test project outputs
[working-directory: '_test-project/project']
clean:
    Remove-Item -Recurse -Force target, logs, dbt_packages, external/*.parquet, external/*.duckdb, external/*.duckdb.wal, external/.tmp -ErrorAction Ignore; exit 0
