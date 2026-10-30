# Dev Work flow

## 1. General

1. Make changes to the Rust code base
2. `just dev`: rebuild the debug binary and run `dbt build` on the test project
3. `just dbt <cmd>`: rerun without rebuilding, e.g. `just dbt run`
4. `just clean`: reset the test project outputs
