import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  courseSidebar: [
    {
      type: 'category',
      label: 'Setup',
      collapsed: false,
      items: ['setup/prerequisites', 'setup/preflight'],
    },
    {
      type: 'category',
      label: 'Labs',
      collapsed: false,
      items: [
        'labs/lab-00-cluster-setup',
        'labs/lab-01-synthetic-data',
        'labs/lab-02-rag-retriever',
        'labs/lab-03-finetuning',
        'labs/lab-04-model-packaging',
        'labs/lab-05-model-serving',
        'labs/lab-06-web-ui',
        'labs/lab-07-agent-core',
        'labs/lab-08-agent-sandbox',
        'labs/lab-09-observability',
        'labs/lab-10-autoscaling',
        'labs/lab-11-gitops',
        'labs/lab-12-pipelines',
        'labs/lab-13-capstone',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      collapsed: false,
      items: ['reference/troubleshooting', 'reference/cleanup'],
    },
  ],
};

export default sidebars;
