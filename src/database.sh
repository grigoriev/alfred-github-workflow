#!/bin/bash

# The repository database: the list of repos across the configured orgs, cached
# as JSON so autocomplete is instant. Rebuilt on demand or when missing.

. src/config.sh
. src/github.sh

# Path to the cached database file.
repos_db() {
  printf '%s/repos.json' "${alfred_workflow_data:-.}"
  return 0
}

# Rebuild the database from every configured org.
rebuild_database() {
  local db org data all
  db="$(repos_db)"
  mkdir -p "$(dirname "$db")"
  all="[]"
  while IFS= read -r org; do
    [[ -n "$org" ]] || continue
    data="$(gh_repo_list "$org")"
    [[ -n "$data" ]] || continue
    all="$(jq -cn --argjson a "$all" --argjson b "$data" '$a + $b')"
  done < <(configured_orgs)
  jq -c 'map({
    owner: .owner.login, name: .name, nameWithOwner: .nameWithOwner,
    description: (.description // ""), isPrivate: .isPrivate,
    pushedAt: .pushedAt, url: .url })' <<< "$all" > "$db"
  return 0
}

# Print the database JSON, rebuilding it when missing.
read_database() {
  local db
  db="$(repos_db)"
  [[ -f "$db" ]] || rebuild_database
  cat "$db" 2>/dev/null || printf '[]'
  return 0
}
