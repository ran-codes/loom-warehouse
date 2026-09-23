set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

dbt_bin := justfile_directory() / "target/debug/dbt.exe"

# list commands
default:
    @just --list

# compile the debug binary, then run `dbt build` on the harness
dev:
    cargo build -p dbt-sa-cli
    just dbt deps
    just dbt build

# run the debug binary on the harness without compiling: just dbt run
[working-directory: '_test-project']
dbt *args:
    {{dbt_bin}} {{args}} --profiles-dir .

# delete the harness outputs
[working-directory: '_test-project']
clean:
    Remove-Item -Recurse -Force target, logs, dbt_packages, external/*.parquet, external/*.duckdb, external/*.duckdb.wal, external/.tmp -ErrorAction Ignore; exit 0
