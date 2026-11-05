import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const sections = [
  {
    title: 'Getting Started',
    description: 'What Loom Warehouse is and why it exists.',
    to: '/getting-started/introduction',
  },
  {
    title: 'User Guides',
    description: 'How to do specific tasks with Python and R models.',
    to: '/user-guides/overview',
  },
  {
    title: 'Reference',
    description: 'Config keys, CLI flags, and model APIs.',
    to: '/reference/overview',
  },
  {
    title: 'Developer Guides',
    description: 'For maintainers: building, testing, and worktrees.',
    to: '/dev-guides/overview',
  },
];

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/getting-started/introduction">
            Get started
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout title={siteConfig.title} description={siteConfig.tagline}>
      <HomepageHeader />
      <main className="container margin-vert--lg">
        <div className="row">
          {sections.map((s) => (
            <div key={s.title} className="col col--6 margin-bottom--lg">
              <Link to={s.to} className={clsx('card padding--lg', styles.card)}>
                <Heading as="h3">{s.title}</Heading>
                <p className="margin-bottom--none">{s.description}</p>
              </Link>
            </div>
          ))}
        </div>
      </main>
    </Layout>
  );
}
