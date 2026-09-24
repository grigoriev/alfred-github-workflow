# Changelog

All notable changes to this workflow are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases before 2.0.1 are listed on the
[GitHub releases page](https://github.com/grigoriev/alfred-github-workflow/releases).

## [Unreleased]

### Changed

- The version bump moves the Unreleased entries of this changelog into a section for
  the new version. The GitHub release takes its notes from that section.

### Security

- The release verifies the provenance of the bundled updater, and the version bump pushes only `main`.

## [2.0.1] - 2026-09-24

### Security

- OpenSSF Scorecard workflow and README badge.
- actionlint and zizmor audit the workflows in the lint job.
- Workflows get a read-only token by default, wider permissions only per job.
- Checkouts drop the git credentials, except in the version bump that pushes.
- Shell steps read workflow expressions from environment variables.
- Renovate pins GitHub Actions by commit digest.
- The kcov coverage image is pinned by digest, and Renovate keeps it current.
- Releases carry a signed build provenance bundle (`*.intoto.jsonl`).
- Renovate takes its common rules from the shared preset `github>grigoriev/renovate-config`, which also turns on OSV vulnerability alerts.

### Added

- Disclaimer and License sections in the README.

### Fixed

- CI runs once per commit on a Renovate branch; a second push run blocked the automerge.
- A rerun of the release workflow uploads the files to the existing release.
