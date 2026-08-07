#!/bin/bash

# Thin wrappers over the gh CLI. gh handles auth, pagination, and JSON, so the
# workflow stays a small UI over it.

# Locate the gh binary. Prefer PATH (so tests can mock it), then fall back to
# the common Homebrew paths, since Alfred runs with a minimal PATH.
gh_bin() {
  local candidate
  candidate="$(command -v gh 2>/dev/null)"
  if [[ -n "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi
  for candidate in /opt/homebrew/bin/gh /usr/local/bin/gh; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 0
}

# Succeed when gh is installed and authenticated.
gh_authed() {
  local gh
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || return 1
  "$gh" auth status >/dev/null 2>&1
  return $?
}

# Call the GitHub REST API through gh. Prints the raw response, empty on failure.
gh_api() {
  local gh
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || return 0
  "$gh" api "$@" 2>/dev/null
  return 0
}

# Print an org's repositories as a JSON array. Empty array on any failure.
gh_repo_list() {
  local org="$1" gh
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || { printf '[]'; return 0; }
  "$gh" repo list "$org" --limit 1000 --no-archived \
    --json nameWithOwner,name,description,isPrivate,pushedAt,url,owner 2>/dev/null \
    || printf '[]'
  return 0
}
