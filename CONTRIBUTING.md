# Contributing

Issues and pull requests are welcome.

## Build and test

```sh
make lint       # ShellCheck the scripts
make test       # run the bats tests (macOS)
make coverage   # run the tests under kcov, as the CI sonar job does
make build      # fetch the shared updater and build GitHub.alfredworkflow
```

`make lint` and `make coverage` run ShellCheck and kcov in their images, pinned by digest, so they
need Docker. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead.

CI runs ShellCheck, actionlint and zizmor, the bats tests on macOS, the build, and a SonarCloud
analysis with kcov coverage for every pull request.

## Pull requests

1. Branch from the default branch as `type/description`, for example `fix/empty-title`.
2. Keep one change per pull request. New behavior comes with tests; a bug fix adds a test that
   fails without it.
3. Write commit messages as [Conventional Commits](https://www.conventionalcommits.org/) without a
   scope: `feat: ...`, `fix: ...`, `docs: ...`, `refactor: ...`, `test: ...`, `build: ...`,
   `ci: ...`, `chore: ...`.
4. Sign your commits. The default branch accepts verified signatures only.
5. Add an entry under `## [Unreleased]` in `CHANGELOG.md`, written for users: the release notes
   quote it. Update the README when behavior or configuration changes.

Pull requests are squash-merged once all required checks are green.

## Style

- The scripts run under the stock macOS `/bin/bash` 3.2: no `mapfile`, no associative arrays, no
  `${var,,}`.
- American spelling. One idea per sentence, active voice. No em dashes.

## Releases

A maintainer runs the Bump Version workflow. It moves the Unreleased entries into a versioned
section, tags the release, and the Release workflow publishes it with signed build provenance.
