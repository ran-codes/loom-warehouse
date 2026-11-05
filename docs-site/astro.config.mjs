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
			logo: { src: './src/assets/logo.svg' },
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/ran-codes/loom-warehouse' }],
			sidebar: [
				{
					label: 'Getting Started',
					items: [{ autogenerate: { directory: 'getting-started' } }],
				},
				{
					label: 'User Guides',
					items: [{ autogenerate: { directory: 'user-guides' } }],
				},
				{
					label: 'Reference',
					items: [{ autogenerate: { directory: 'reference' } }],
				},
				{
					label: 'Developer Guides',
					items: [{ autogenerate: { directory: 'dev-guides' } }],
				},
			],
		}),
	],
});
