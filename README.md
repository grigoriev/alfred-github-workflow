# <img src="https://raw.githubusercontent.com/grigoriev/alfred-github-workflow/main/icon.png" alt="github" width="32"> Alfred GitHub Workflow

![CI](https://github.com/grigoriev/alfred-github-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-github-workflow)](https://github.com/grigoriev/alfred-github-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-github-workflow&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-github-workflow)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-github-workflow&metric=coverage)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-github-workflow)

Type as little as possible, pick a repository fast, and open the right GitHub
page in the browser. The browser routes each URL to the correct profile, so the
workflow only needs to open it.

## Inspiration and why this exists

This workflow is inspired by
[gharlan/alfred-github-workflow](https://github.com/gharlan/alfred-github-workflow),
which is excellent. This one is deliberately simpler and has a different goal:
open the right GitHub page in the browser, where each URL is routed to its own
profile. That shaped a few choices:

- **No PHP.** macOS removed the bundled PHP runtime, so the original needs a
  separate PHP install. This workflow is bash and reuses the `gh` CLI, which is
  already installed and authenticated.
- **No GitHub Enterprise and no own OAuth app.** `gh` handles authentication.
- **A fixed set of organizations, not all of GitHub.** Fast autocomplete over the
  orgs you configure, then the browser routes URLs to profiles.
- **Toolchain fit.** The sibling workflows are bash with a shared updater,
  SonarCloud, and a common CI and release flow. A PHP workflow would not fit it.

## Requirements

- [Alfred](https://www.alfredapp.com/) with the Powerpack.
- The [`gh` CLI](https://cli.github.com/), authenticated (`gh auth login`).
- `jq` (preinstalled on macOS 12+, or `brew install jq`).

## Install

1. Open the [latest release](https://github.com/grigoriev/alfred-github-workflow/releases/latest).
2. Under **Assets**, download `GitHub.alfredworkflow`.
3. Double click the file to add it to Alfred.

## Usage

```
gh                     browse the configured organizations
gh int                 filter organizations
gh intechcore/         list the organization's repositories
gh owner/repo          open the repo menu (⏎): open, issues, pulls, ...
gh owner/repo #123     open an issue or pull request
gh owner/repo @branch  open a branch
gh owner/repo *commit  open a commit
gh owner/repo issues | pulls | actions | admin | clone |
               discussions | milestones | releases
gh >                   global commands (login, logout, update, ...)
```

Hold <kbd>⌘</kbd> on a repository and press <kbd>⏎</kbd> to hide it from the
list, or <kbd>⌥</kbd> to pin it to the top (marked with a star). Manage hidden
repositories with `gh > hidden`, where <kbd>⏎</kbd> unhides.

## Configuration

The default organizations are `grigoriev`, `intechcore`, and
`SchweizerischeBundesbahnen`. Override them by writing one org per line to
`<workflow data>/orgs`. Hidden repositories are stored in `<workflow data>/hidden`.

## Caching

The list of repositories is cached as a local database so autocomplete is
instant. It refreshes in the background once it is older than six hours: the
list still shows immediately and updates in place. Live data (issues, branches,
commits) is cached briefly the same way. Clear either from the `gh >` menu:
`delete database` rebuilds the repository list, `delete cache` drops the
transient responses.

## Development

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # build the workflow bundle
make icons    # regenerate PNG icons from Octicons (macOS, needs librsvg)
```

Icons come from [Octicons](https://github.com/primer/octicons) (MIT).
