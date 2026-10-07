# Workflows

| Workflow | Runs on | What it does |
| --- | --- | --- |
| [`bootstrap.yml`](bootstrap.yml) | Push to `main`, every pull request | On a Windows runner: runs PSScriptAnalyzer, the Pester tests and a full plan-mode run |
| [`markdownlint.yml`](markdownlint.yml) | Push to `main`, every pull request | Lints every markdown file against [`.markdownlint.json`](../../.markdownlint.json) |

Dependency updates are configured separately in [`../dependabot.yml`](../dependabot.yml), covering the GitHub Actions used across the workflows above.
