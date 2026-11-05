import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Loom Warehouse',
  tagline: 'Documentation for Loom Warehouse.',
  favicon: 'img/favicon.svg',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Project Pages URL: https://ran-codes.github.io/loom-warehouse/
  url: 'https://ran-codes.github.io',
  baseUrl: '/loom-warehouse/',
  // GitHub Pages adds trailing slashes unless this is set explicitly.
  trailingSlash: false,
  organizationName: 'ran-codes',
  projectName: 'loom-warehouse',

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          // Serve docs at the site root, like the Starlight site did.
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          // docs/ is the unreleased working copy. At each release, freeze it
          // with `pnpm docusaurus docs:version <x.y.z>`.
          versions: {
            current: {
              label: 'v0.1.0',
            },
          },
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  // Writes llms.txt and llms-full.txt into the build output (llmstxt.org).
  plugins: ['docusaurus-plugin-llms'],

  themeConfig: {
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Loom Warehouse',
      logo: {
        alt: 'Loom Warehouse logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/ran-codes/loom-warehouse',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
