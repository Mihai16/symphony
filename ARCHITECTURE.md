# Architecture

Symphony's architecture documentation lives in the [developer docs site](docs-site/).

The canonical pages are:

- **Pipeline extension** — [`docs-site/docs/architecture/pipeline-extension.mdx`](docs-site/docs/architecture/pipeline-extension.mdx)
  ([deployed](https://mihai16.github.io/symphony/architecture/pipeline-extension))

GitHub renders the `.mdx` source above (including embedded Mermaid diagrams) when you click into
the file. The deployed site adds sidebar navigation, search, and proper component rendering — use
that if you're reading more than one page.

If you're filing a new architectural decision, add a page under `docs-site/docs/architecture/` and
wire it into `docs-site/sidebars.js`. The `.claude/skills/manage-docs/` skill walks through the
procedure.
