---
name: setup-docs-site
description: Stand up a complete documentation website in any repository — a Docusaurus 3 site with client-side Mermaid diagrams, a CI Mermaid-validation step, a per-PR build check, and GitHub Pages auto-deploy. Use when the user asks to "set up a docs site", "add a documentation website", "port the docs-site setup to another repo", "scaffold Docusaurus", or wants Symphony's docs-site infrastructure reproduced elsewhere (even in an empty repo).
---

# Set Up a Documentation Website

This skill reproduces the documentation system that lives in Symphony's `docs-site/` folder in
**any** target repository — including a completely empty one. The end result is:

- A [Docusaurus 3](https://docusaurus.io/) static site, authored in **MDX + Markdown**.
- **Mermaid** diagrams that render on the deployed site *and* in GitHub's raw file view.
- A **Mermaid validation** step that parses every diagram in CI, so a broken diagram fails the
  PR instead of silently shipping (Docusaurus renders Mermaid client-side, so the build alone
  won't catch syntax errors).
- **Auto-deploy to GitHub Pages** via GitHub Actions on every push to `main`.
- A **PR check** that builds the site and validates diagrams on every pull request.

The deployed URL follows the GitHub Pages pattern `https://<OWNER>.github.io/<REPO>/`.

## When to invoke

- The user asks to set up / add / scaffold a documentation website or Docusaurus site.
- The user wants Symphony's `docs-site/` infrastructure ported into another repository.
- A new or empty repo needs the same docs + Mermaid + GitHub Pages pipeline.

Not for *writing* developer docs inside this repo's existing site — that's `manage-docs`. This
skill is about **creating the site infrastructure** in a target repo.

## How to use it

The complete, self-contained recipe — every file reproduced in full (package.json,
docusaurus.config.js, sidebars.js, check-mermaid.mjs, both workflows, intro page, etc.) plus
step-by-step instructions, version pins, authoring conventions, and a porting checklist — lives
in:

- **`references/docs-site-porting-guide.md`**

Steps:

1. **Read `references/docs-site-porting-guide.md` in full** before creating anything.
2. **Resolve the placeholders** from Section 1 of the guide. Infer `<OWNER>` and `<REPO>` from the
   target repo's `git remote`, and the project name/tagline from its README. If `<TITLE>`,
   `<TAGLINE>`, or `<FAVICON_LETTER>` are unclear, ask the user before proceeding.
3. **Create every file** in the guide's Sections 3 and 4 exactly as specified, substituting the
   placeholders consistently. Do not hand-write `package-lock.json`.
4. **Verify locally:** `cd docs-site && npm install && npm run check:mermaid && npm run build`.
   Fix any errors until all three succeed, then commit `package-lock.json`.
5. **Commit on a feature branch** with a clear message. Do **not** open a PR or push to a
   protected branch unless the user explicitly asks.
6. **Tell the user the one manual step** they must do in the GitHub UI: Settings → Pages → Source →
   "GitHub Actions" (guide Section 6), and report the final deployed URL.
7. For any documentation pages you author, follow the **authoring conventions** in the guide's
   Section 7 so the docs stay consistent.

The reference guide is the source of truth for all file contents and exact version pins — defer to
it rather than reconstructing the files from memory.
