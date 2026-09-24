#!/usr/bin/env bash
# Prints the notes of a GitHub release from a Keep a Changelog file:
#   1. The body of the "## [VERSION]" section, without its heading.
#   2. With REPOSITORY, a "Full changelog" link that compares the previous
#      section of the file with VERSION. The first section has no link.
# Fails when the file has no section for VERSION, or when it is empty.
#
#   changelog-section.sh VERSION [REPOSITORY]
#
# VERSION is X.Y.Z without the leading v. REPOSITORY is owner/name.
#
# Environment:
#   CHANGELOG  the changelog file, default CHANGELOG.md
set -euo pipefail

version=${1:?usage: changelog-section.sh VERSION [REPOSITORY]}
repository=${2:-}
changelog=${CHANGELOG:-CHANGELOG.md}

# Prints the section body with outer blank lines trimmed, then a line
# "previous<TAB><version of the next older section>" when there is one.
extract() {
    local file=$1
    awk -v version="$version" '
        /^## / {
            if (inside) {
                if (match($0, /^## \[[^]]+\]/)) previous = substr($0, 5, RLENGTH - 5)
                inside = 0
                done = 1
                next
            }
            if (!done && index($0, "## [" version "]") == 1) inside = 1
            next
        }
        /^\[[^]]+\]: / { inside = 0 }
        inside { body[++n] = $0 }
        END {
            first = 1
            while (first <= n && body[first] ~ /^[[:space:]]*$/) first++
            last = n
            while (last >= first && body[last] ~ /^[[:space:]]*$/) last--
            for (i = first; i <= last; i++) print body[i]
            if (previous != "") print "previous\t" previous
        }' "$file"
    return 0
}

marker=$'previous\t'
output=$(extract "$changelog")
notes=$(printf '%s\n' "$output" | grep -v "^${marker}" || true)
previous=$(printf '%s\n' "$output" | sed -n "s/^${marker}//p")

if [[ -z $notes ]]; then
    echo "${changelog} has no entries for ${version}" >&2
    exit 1
fi

printf '%s\n' "$notes"
if [[ -n $repository && -n $previous ]]; then
    printf '\n**Full changelog**: https://github.com/%s/compare/v%s...v%s\n' \
        "$repository" "$previous" "$version"
fi
