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
      items: ['architecture/pipeline-extension'],
    },
  ],
};

module.exports = sidebars;
