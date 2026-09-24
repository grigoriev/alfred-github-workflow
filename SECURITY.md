# Security policy

## Reporting a vulnerability

Report a vulnerability privately through GitHub:
https://github.com/grigoriev/alfred-github-workflow/security/advisories/new
(the **Security** tab, **Report a vulnerability**). Do not open a public issue for it.

We answer within a week. The fix goes into the next release, and its release notes name it.

## Supported versions

Only the latest release gets fixes.

## Scope

The workflow scripts in `src/`, `info.plist`, the `Makefile` and the GitHub Actions workflows
belong to this repository. The shared updater that the build bundles belongs to
[alfred-workflow-updater](https://github.com/grigoriev/alfred-workflow-updater).

Vulnerabilities in upstream software (Alfred, the `gh` CLI, `jq`) belong to the upstream project. Tell us as well
if this project is affected, so we can release a fix when the upstream fix is out.
