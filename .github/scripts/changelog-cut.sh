#!/usr/bin/env bash
# Cuts a release in a Keep a Changelog file, in place:
#   1. Moves the entries of "## [Unreleased]" into a new "## [VERSION] - DATE"
#      section, directly below an empty "## [Unreleased]".
#   2. Writes a maintenance line when Unreleased holds no entry.
#   3. Updates the compare links at the bottom, if the file has an
#      "[Unreleased]: .../compare/<tag>...HEAD" link.
#
#   changelog-cut.sh VERSION [DATE]
#
# VERSION is X.Y.Z without the leading v. DATE defaults to today in UTC.
#
# Environment:
#   CHANGELOG  the changelog file, default CHANGELOG.md
set -euo pipefail

version=${1:?usage: changelog-cut.sh VERSION [DATE]}
release_date=${2:-$(date -u +%Y-%m-%d)}
changelog=${CHANGELOG:-CHANGELOG.md}

if ! grep -q '^## \[Unreleased\]' "$changelog"; then
    echo "${changelog} has no '## [Unreleased]' section" >&2
    exit 1
fi
if grep -qF "## [${version}]" "$changelog"; then
    echo "${changelog} already has a section for ${version}" >&2
    exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

awk -v version="$version" -v release_date="$release_date" '
    # A link reference of the Unreleased or a version section. Other link
    # references may stand inside an entry.
    function is_link(line) {
        return line ~ /^\[(Unreleased|[0-9][^]]*)\]: /
    }
    # Prints the collected Unreleased entries as the new release section.
    function cut(   first, last, i, has_entry) {
        first = 1
        while (first <= n && body[first] ~ /^[[:space:]]*$/) first++
        last = n
        while (last >= first && body[last] ~ /^[[:space:]]*$/) last--
        has_entry = 0
        for (i = first; i <= last; i++) {
            if (body[i] !~ /^[[:space:]]*$/ && body[i] !~ /^### /) has_entry = 1
        }
        print ""
        print "## [" version "] - " release_date
        print ""
        if (has_entry) {
            for (i = first; i <= last; i++) print body[i]
        } else {
            print "- Maintenance release: dependency and CI updates."
        }
        print ""
        inside = 0
        done = 1
    }
    # Rewrites "[Unreleased]: <base>/compare/<prev>...HEAD" and adds the link
    # of the new version below it.
    function relink(line,   url, at, rest, dots, base, prev) {
        url = substr(line, length("[Unreleased]: ") + 1)
        at = index(url, "/compare/")
        if (at == 0) { print line; return }
        base = substr(url, 1, at - 1)
        rest = substr(url, at + length("/compare/"))
        dots = index(rest, "...")
        if (dots == 0 || substr(rest, dots + 3) != "HEAD") { print line; return }
        prev = substr(rest, 1, dots - 1)
        print "[Unreleased]: " base "/compare/v" version "...HEAD"
        print "[" version "]: " base "/compare/" prev "...v" version
    }
    # Lines inside a fenced code block are neither headings nor links.
    {
        heading = !fence && /^## /
        link = !fence && is_link($0)
        if ($0 ~ /^[[:space:]]*(```|~~~)/) fence = !fence
    }
    !done && !inside && heading && /^## \[Unreleased\]/ { print; inside = 1; next }
    inside && (heading || link) { cut() }
    inside { body[++n] = $0; next }
    link && index($0, "[Unreleased]: ") == 1 { relink($0); next }
    { print }
    END { if (inside) cut() }
' "$changelog" > "$tmp"

# A section at the end of the file leaves one blank line too many.
awk '
    /^[[:space:]]*$/ { blank++; next }
    { while (blank > 0) { print ""; blank-- } print }
' "$tmp" > "$changelog"
