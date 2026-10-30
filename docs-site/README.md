# Loom Warehouse docs site

Source for the Loom Warehouse documentation site, built with [Astro Starlight](https://starlight.astro.build) and deployed to GitHub Pages at https://ran-codes.github.io/loom-warehouse/.

## Develop

Requires Node (see `engines` in `package.json`) and [pnpm](https://pnpm.io) (`npm install -g pnpm`). Use pnpm, not npm, so the lockfile stays the only one. pnpm keeps one global package store and hard-links it into each worktree, so installing in a new worktree takes seconds. From this folder:

```sh
pnpm install
pnpm dev         # http://localhost:4321/loom-warehouse/
pnpm build       # outputs to ./dist
pnpm preview     # serve the built site
```

## Content

Pages are Markdown/MDX files in `src/content/docs/`. The sidebar autogenerates from the `getting-started/`, `guides/`, and `reference/` folders; configure it in `astro.config.mjs`.

## Deploy

`.github/workflows/docs-site.yml` builds and deploys on every push to `main` that touches `docs-site/**`. The workflow sparse-checks-out only this folder.
