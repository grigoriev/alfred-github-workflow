# Changelog

All notable changes to this workflow are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- OpenSSF Scorecard workflow and README badge.
- actionlint and zizmor audit the workflows in the lint job.
- Workflows get a read-only token by default, wider permissions only per job.
- Checkouts drop the git credentials, except in the version bump that pushes.
- Shell steps read workflow expressions from environment variables.
- Renovate pins GitHub Actions by commit digest.

### Added

- Disclaimer and License sections in the README.

### Fixed

- CI runs once per commit on a Renovate branch; a second push run blocked the automerge.

Earlier releases are listed on the
[GitHub releases page](https://github.com/grigoriev/alfred-github-workflow/releases).
