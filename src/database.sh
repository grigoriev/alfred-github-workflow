#!/bin/bash

# The repository database: the list of repos across the configured orgs, cached
# as JSON so autocomplete is instant. Built when missing, and refreshed in the
# background once it is older than the TTL.

. src/config.sh
. src/github.sh
. src/cache.sh

# How long the database stays fresh, in seconds (6 hours). Overridable in tests.
DATABASE_TTL="${DATABASE_TTL:-21600}"

# Path to the cached database file.
repos_db() {
  printf '%s/repos.json' "${alfred_workflow_data:-.}"
  return 0
}

# Rebuild the database from every configured org, writing atomically.
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
  jq -c -f src/normalize-repos.jq <<< "$all" > "$db.tmp" && mv "$db.tmp" "$db"
  return 0
}

# Succeed when the database exists and is younger than the TTL.
database_fresh() {
  local db now mtime
  db="$(repos_db)"
  [[ -f "$db" ]] || return 1
  now="$(date +%s)"
  mtime="$(file_mtime "$db")"
  [[ "$mtime" =~ ^[0-9]+$ ]] || return 1
  [[ $(( now - mtime )) -lt "$DATABASE_TTL" ]]
}

# Print the database JSON, building it synchronously when missing. Return 1 when
# the served data is stale, so the caller refreshes it in the background.
read_database() {
  local db
  db="$(repos_db)"
  [[ -f "$db" ]] || rebuild_database
  cat "$db" 2>/dev/null || printf '[]'
  database_fresh && return 0
  return 1
}
