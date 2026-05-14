# Symphony Developer Docs

Docusaurus site for Symphony's developer-facing documentation: architecture, design notes, ADRs.

The deployed site is at <https://mihai16.github.io/symphony/>.

## Local preview

```bash
cd docs-site
npm install
npm run start
```

That serves on <http://localhost:3000/symphony/> with hot reload.

## Adding a page

1. Create `docs/<area>/<slug>.mdx` (or `.md`).
2. Add the slug to `sidebars.js` under the right category.
3. Use fenced ```mermaid blocks for diagrams — they render both on the deployed site and on
   GitHub when you view the source file.
4. Preview locally before pushing.

See `.claude/skills/manage-docs/SKILL.md` for the full procedure.

## What goes here vs. elsewhere

| Audience               | Home                                    |
|------------------------|-----------------------------------------|
| Spec readers           | `SPEC.md` at repo root (source of truth)|
| Developer / architect  | this site (`docs-site/docs/`)           |
| Operator how-tos       | GitHub wiki                             |
| In-flight proposals    | `proposals/` at repo root               |

See `.claude/memory/workflow.md` for the full split.

## Build

```bash
npm run build
```

Produces a static site under `build/`. CI does this on every push to `main` and deploys to
GitHub Pages via `.github/workflows/docs.yml`.

## Validate Mermaid diagrams

Mermaid blocks are rendered client-side, so syntax errors don't surface during `npm run build`.
A separate check pipes every fenced ` ```mermaid ` block under `docs/` through `mermaid.parse()`:

```bash
npm run check:mermaid
```

CI runs the same script on every pull request that touches `docs-site/**` (see
`.github/workflows/docs-check.yml`).

To debug a single diagram by rendering it, drop the block into a `diagram.mmd` file and run
`@mermaid-js/mermaid-cli`:

```bash
npx -p @mermaid-js/mermaid-cli mmdc -i diagram.mmd -o /tmp/out.svg
```
