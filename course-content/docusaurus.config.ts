import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'LLMOps & AgentOps with Kubernetes',
  tagline: 'From RAG to production agents on Kubernetes',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://llmops.schoolofdevops.com',
  baseUrl: '/',

  organizationName: 'schoolofdevops',
  projectName: '302-llmops',

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
          sidebarPath: './sidebars.ts',
          routeBasePath: '/docs',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'LLMOps',
      logo: {
        alt: 'LLMOps & AgentOps Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'courseSidebar',
          label: 'Labs',
          position: 'left',
        },
        {
          href: 'https://github.com/schoolofdevops/302-llmops',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Course',
          items: [
            {
              label: 'Labs',
              to: '/docs',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/schoolofdevops/302-llmops',
            },
            {
              label: 'School of Devops',
              href: 'https://schoolofdevops.com',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} School of Devops. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
