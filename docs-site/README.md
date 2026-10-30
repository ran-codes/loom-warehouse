# Loom Warehouse docs site

Source for the Loom Warehouse documentation site, built with [Astro Starlight](https://starlight.astro.build) and deployed to GitHub Pages at https://ran-codes.github.io/loom-warehouse/.

## Develop

Requires Node (see `engines` in `package.json`). From this folder:

```sh
npm install
npm run dev      # http://localhost:4321/loom-warehouse/
npm run build    # outputs to ./dist
npm run preview  # serve the built site
```

## Content

Pages are Markdown/MDX files in `src/content/docs/`. The sidebar autogenerates from the `getting-started/`, `guides/`, and `reference/` folders; configure it in `astro.config.mjs`.

## Deploy

`.github/workflows/docs-site.yml` builds and deploys on every push to `main` that touches `docs-site/**`. The workflow sparse-checks-out only this folder.
