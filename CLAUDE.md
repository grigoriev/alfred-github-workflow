# CLAUDE.md

Alfred workflow that picks a GitHub repository fast and opens the right GitHub page in the browser.
It uses the authenticated `gh` CLI. No PHP, no own OAuth app, no GitHub Enterprise.
Keywords: `gh` to browse, `ghs` to search repos across all orgs. Artifact: `GitHub.alfredworkflow`.

## Layout

- `src/gh.sh` - the entry point. It takes `mode` and `query`. Modes: `list` (`gh` Script Filter), `search` (`ghs` Script Filter), `run` (Run Script).
- `src/github.sh` - `gh` API access for repos, issues, pulls, branches and commits.
- `src/config.sh` - the orgs file and the per-org visible-repositories files under `$alfred_workflow_data`.
- `src/database.sh` - the local repository database, refreshed in the background after six hours.
- `src/cache.sh` - short-lived cache of live responses under `$alfred_workflow_cache`.
- `src/globals.sh` - the `gh >` menu (`globals_menu`): orgs, hidden, login, delete cache and database, updates. The reference for the `>` menu pattern.
- `src/filter-repos.jq`, `normalize-repos.jq`, `normalize-starred.jq`, `format-*.jq` - extracted jq programs.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths. `icons/` holds the PNGs, built from Octicons.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects and the workflow `version`.
- `tests/*.bats`, one per source file, plus `coverage_tests.bats` and `perf_tests.bats`.
- `tests/mocks/bin/` - fake `gh`, `open`, `osascript` and `pbcopy`.

## Commands

```sh
make lint       # ShellCheck gh, config, github, database, cache, globals in Docker
make test       # fetch the updater, then run bats tests (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch the updater, smoke-test it, zip GitHub.alfredworkflow
make icons      # regenerate PNG icons from Octicons (macOS, needs librsvg)
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash.
- Authentication belongs to `gh`. The workflow never stores or reads a token itself.
- Alfred runs with a minimal `PATH`. Resolve `gh` through `gh_bin` in `src/github.sh`.
- The repository list must show instantly from the database. A stale database refreshes in the background, never in the foreground.
- New repos in an org enter the visible file commented, so they stay hidden until reviewed.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- Spawn `jq` once per Script Filter run, not once per repository.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- Settings and updates live behind the `gh >` menu. `globals_menu` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially owner, repo, branch names and file paths.
- `jq`, `gh` or a subshell spawned inside a per-repository loop.
- A bare `gh` call that bypasses `gh_bin`.
- A synchronous `gh` call on the main list path that blocks the Script Filter.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- A cache or database format change without an invalidation path for existing users.
- A test that calls the real `gh` or the network instead of the mock.
- A violation of the Sonar shell rules listed above.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- A change to the `>` menu pattern here that the sibling workflows do not get.
- Update or autoupdate logic added here, or a committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior or configuration change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.
