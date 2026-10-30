# Testing strategy — issue #33

## 1. Initial eval

How the two reference repos split dev loop / local gate / CI, against what loom-warehouse has today.

| Tier | salurbal.org | loom-cms | loom-warehouse today |
|---|---|---|---|
| Dev loop | `pnpm check` + `pnpm test` | `pnpm check` + `pnpm test` (`pnpm test:watch`) | `just dev` — build only, no tests |
| Local gate | `pnpm build` = check → test → build-lean | `pnpm check` + `pnpm test` + `pnpm build` (no chain) | none |
| CI | `pnpm build-lean` (SWA deploy) | `pnpm check --skip=audit` + `pnpm test` + `pnpm build` | `cargo fmt --check` + `cargo clippy` + `cargo nextest run` |

Notes:

- Both reference repos keep CI light and put the real gate in a local script the developer runs before pushing.
- loom-cms CI is opt-in per PR via the `CI Trigger` label; loom-warehouse's `ci.yml` already uses the same label gate.
- loom-warehouse has 576 files with `#[test]`, but `just dev` is `cargo build -p dbt-sa-cli` + `dbt build` — it compiles and never runs tests. Upstream's only local setup is CONTRIBUTING's "run `cargo nextest run` by hand".
- CI runs on Linux only; a Windows-green local run does not guarantee a green CI run (recent cfg-gating commits are the evidence).
