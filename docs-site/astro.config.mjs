// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	// Project Pages URL: https://ran-codes.github.io/loom-warehouse/
	site: 'https://ran-codes.github.io',
	base: '/loom-warehouse',
	integrations: [
		starlight({
			title: 'Loom Warehouse',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/ran-codes/loom-warehouse' }],
			sidebar: [
				{
					label: 'Getting Started',
					items: [{ autogenerate: { directory: 'getting-started' } }],
				},
				{
					label: 'Guides',
					items: [{ autogenerate: { directory: 'guides' } }],
				},
				{
					label: 'Reference',
					items: [{ autogenerate: { directory: 'reference' } }],
				},
			],
		}),
	],
});
