# Symphony

Symphony turns project work into isolated, autonomous implementation runs, allowing teams to manage
work instead of supervising coding agents.

This repository is a fork that carries two things:

- **An Elixir reference implementation** of Symphony — a working, experimental implementation you
  can set up against your own repository.
- **A developer documentation site** covering Symphony's architecture, design notes, and ADRs,
  deployed at <https://mihai16.github.io/symphony/>.

[![Symphony demo video preview](.github/media/symphony-demo-poster.jpg)](.github/media/symphony-demo.mp4)

_In this [demo video](.github/media/symphony-demo.mp4), Symphony monitors a Linear board for work and spawns agents to handle the tasks. The agents complete the tasks and provide proof of work: CI status, PR review feedback, complexity analysis, and walkthrough videos. When accepted, the agents land the PR safely. Engineers do not need to supervise the agents; they can manage the work at a higher level._

> [!WARNING]
> Symphony is a low-key engineering preview for testing in trusted environments.

## Documentation

- **Developer docs site:** <https://mihai16.github.io/symphony/> — architecture, design notes, ADRs.
- **Local docs preview / authoring:** [docs-site/README.md](docs-site/README.md).
- **Specification:** [SPEC.md](SPEC.md).
- **Architecture overview:** [ARCHITECTURE.md](ARCHITECTURE.md).
- **Elixir reference implementation:** [elixir/README.md](elixir/README.md).

## Running Symphony

### Requirements

Symphony works best in codebases that have adopted
[harness engineering](https://openai.com/index/harness-engineering/). Symphony is the next step --
moving from managing coding agents to managing work that needs to get done.

### Option 1. Make your own

Tell your favorite coding agent to build Symphony in a programming language of your choice, using
this repository's [SPEC.md](SPEC.md) (or the upstream
[openai/symphony spec](https://github.com/openai/symphony/blob/main/SPEC.md)):

> Implement Symphony according to the spec in SPEC.md

### Option 2. Use our experimental reference implementation

Check out [elixir/README.md](elixir/README.md) for instructions on how to set up your environment
and run the Elixir-based Symphony implementation. You can also ask your favorite coding agent to
help with the setup:

> Set up Symphony for my repository based on elixir/README.md

## CI/CD automations

GitHub Actions workflows in [`.github/workflows/`](.github/workflows/) keep this fork green and
keep the docs site deployed:

- **`make-all.yml`** — runs `make all` (build + checks) on every pull request and on pushes to
  `main`.
- **`pr-description-lint.yml`** — validates the PR description format via `mix pr_body.check`
  whenever a PR is opened, edited, reopened, synchronized, or marked ready for review.
- **`docs-check.yml`** — validates Mermaid diagrams and builds the docs site on PRs that touch
  `docs-site/**` (or the workflow itself).
- **`docs.yml`** — builds and deploys the docs site to GitHub Pages on pushes to `main` that touch
  `docs-site/**` (or the workflow itself), and on manual dispatch.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).
