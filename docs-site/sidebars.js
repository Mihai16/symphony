// @ts-check
// Sidebar navigation. Add new pages here so they show up in the left nav.

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mainSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Architecture',
      collapsed: false,
      items: [
        {
          type: 'category',
          label: 'Pipeline Extension',
          collapsed: false,
          link: { type: 'doc', id: 'architecture/pipeline-extension' },
          items: [
            'architecture/pipeline-extension/phase-1-schema-and-spec-resolver',
            'architecture/pipeline-extension/phase-2-runner-strategy-extraction',
            'architecture/pipeline-extension/phase-3-claude-pipeline-runner',
            'architecture/pipeline-extension/phase-4-dynamic-reload-and-validation',
          ],
        },
      ],
    },
  ],
};

module.exports = sidebars;
