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
        'labs/lab-01-synthetic-data-and-rag',
        'labs/lab-02-finetuning',
        'labs/lab-03-model-packaging',
        'labs/lab-04-serving-and-ui',
        'labs/lab-05-observability',
        'labs/lab-06-disk-model-loading',
        'labs/lab-07-vllm-router',
        'labs/lab-08-kserve-inferenceservice',
        'labs/lab-09-serving-decision',
        'labs/lab-10-autoscaling',
        'labs/lab-11-gitops-argocd',
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
