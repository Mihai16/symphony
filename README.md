# Symphony

Symphony turns project work into isolated, autonomous implementation runs, allowing teams to manage
work instead of supervising coding agents.

This repository is a fork of [`openai/symphony`](https://github.com/openai/symphony) and hosts two
things:

- the **Elixir reference implementation** of the Symphony service — see [`elixir/`](elixir/), and
- the **developer documentation site** for its architecture and design decisions — see
  [`docs-site/`](docs-site/), deployed at <https://mihai16.github.io/symphony/>.

[![Symphony demo video preview](.github/media/symphony-demo-poster.jpg)](.github/media/symphony-demo.mp4)

_In this [demo video](.github/media/symphony-demo.mp4), Symphony monitors a Linear board for work and spawns agents to handle the tasks. The agents complete the tasks and provide proof of work: CI status, PR review feedback, complexity analysis, and walkthrough videos. When accepted, the agents land the PR safely. Engineers do not need to supervise Codex; they can manage the work at a higher level._

> [!WARNING]
> Symphony is a low-key engineering preview for testing in trusted environments.

## Documentation

- **[Developer docs site](https://mihai16.github.io/symphony/)** — architecture, design notes, and
  ADRs. Authoring and local-preview instructions live in [`docs-site/README.md`](docs-site/README.md).
- **[`SPEC.md`](SPEC.md)** — the language-agnostic Symphony service specification (source of truth).
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** — entry point into the architecture pages on the docs site.
- **[`elixir/README.md`](elixir/README.md)** — setup and operation of the Elixir reference
  implementation.

## Running Symphony

### Requirements

Symphony works best in codebases that have adopted
[harness engineering](https://openai.com/index/harness-engineering/). Symphony is the next step --
moving from managing coding agents to managing work that needs to get done.

### Option 1. Make your own

Tell your favorite coding agent to build Symphony in a programming language of your choice:

> Implement Symphony according to the following spec:
> https://github.com/Mihai16/symphony/blob/main/SPEC.md

### Option 2. Use our experimental reference implementation

Check out [elixir/README.md](elixir/README.md) for instructions on how to set up your environment
and run the Elixir-based Symphony implementation. You can also ask your favorite coding agent to
help with the setup:

> Set up Symphony for my repository based on
> https://github.com/Mihai16/symphony/blob/main/elixir/README.md

## CI/CD automations

GitHub Actions workflows in [`.github/workflows/`](.github/workflows/) gate every pull request and
keep `main` and the docs site healthy:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`make-all.yml`](.github/workflows/make-all.yml) | every PR and pushes to `main` | runs `make all` in `elixir/` — build plus the format, lint, test/coverage, and Dialyzer checks |
| [`pr-description-lint.yml`](.github/workflows/pr-description-lint.yml) | PR opened, edited, reopened, synchronized, or marked ready | validates the PR description format via `mix pr_body.check` |
| [`docs-check.yml`](.github/workflows/docs-check.yml) | PRs touching `docs-site/**` | validates Mermaid diagrams and builds the docs site |
| [`docs.yml`](.github/workflows/docs.yml) | pushes to `main` touching `docs-site/**` | builds the docs site and deploys it to GitHub Pages |

## License

This project is licensed under the [Apache License 2.0](LICENSE).
