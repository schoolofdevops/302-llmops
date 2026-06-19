import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'LLMOps with Kubernetes',
  tagline: 'Production LLM serving on Kubernetes',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://schoolofdevops.github.io',
  baseUrl: '/302-llmops/',

  organizationName: 'schoolofdevops',
  projectName: '302-llmops',

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          {
            from: '/docs/labs/lab-07-agent-core',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
          {
            from: '/docs/labs/lab-08-agent-sandbox',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
          {
            from: '/docs/labs/lab-09-observability',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
          {
            from: '/docs/labs/lab-11-gitops',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
          {
            from: '/docs/labs/lab-12-pipelines',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
          {
            from: '/docs/labs/lab-13-capstone',
            to: 'https://github.com/schoolofdevops/303-agentops',
          },
        ],
      },
    ],
  ],

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
        alt: 'LLMOps Logo',
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
