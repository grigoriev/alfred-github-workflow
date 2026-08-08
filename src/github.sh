#!/bin/bash

# Thin wrappers over the gh CLI. gh handles auth, pagination, and JSON, so the
# workflow stays a small UI over it.

# Fallback locations, since Alfred runs with a minimal PATH. Overridable in tests.
GH_FALLBACK_PATHS="${GH_FALLBACK_PATHS:-/opt/homebrew/bin/gh /usr/local/bin/gh}"

# Locate the gh binary. Prefer PATH (so tests can mock it), then the fallbacks.
gh_bin() {
  local candidate
  candidate="$(command -v gh 2>/dev/null)"
  if [[ -n "$candidate" ]]; then
    printf '%s' "$candidate"
    return 0
  fi
  for candidate in $GH_FALLBACK_PATHS; do
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

# Print the authenticated user's starred repositories as GitHub API JSON.
gh_starred() {
  local gh
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || { printf '[]'; return 0; }
  "$gh" api user/starred --paginate 2>/dev/null || printf '[]'
  return 0
}

# Print the authenticated user's login, cached in the data dir after the first
# lookup so the "My" pages resolve without a network call every time.
gh_login() {
  local file gh login
  file="${alfred_workflow_data:-.}/login"
  if [[ -s "$file" ]]; then
    cat "$file"
    return 0
  fi
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || return 0
  login="$("$gh" api user --jq .login 2>/dev/null)"
  [[ -n "$login" ]] || return 0
  mkdir -p "${alfred_workflow_data:-.}"
  printf '%s' "$login" > "$file"
  printf '%s' "$login"
  return 0
}

# Print an account's cached type ("User" or "Organization"), or nothing when it
# has not been looked up yet. Reads the cache only, so it never blocks.
cached_account_type() {
  local file
  file="${alfred_workflow_data:-.}/types/$1"
  [[ -s "$file" ]] && cat "$file"
  return 0
}

# Look up an account's type and cache it. Called during the database rebuild.
cache_account_type() {
  local name="$1" gh type dir
  gh="$(gh_bin)"
  [[ -n "$gh" ]] || return 0
  type="$("$gh" api "users/$name" --jq .type 2>/dev/null)"
  [[ -n "$type" ]] || return 0
  dir="${alfred_workflow_data:-.}/types"
  mkdir -p "$dir"
  printf '%s' "$type" > "$dir/$name.tmp" && mv "$dir/$name.tmp" "$dir/$name"
  return 0
}
