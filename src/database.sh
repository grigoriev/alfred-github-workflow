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

# Rebuild the database from every configured org, writing atomically. An empty
# result (for example a transient gh failure) is not written, so it never
# poisons the cache; the previous database, if any, is kept.
rebuild_database() {
  local db org data all normalized
  db="$(repos_db)"
  mkdir -p "$(dirname "$db")"
  all="[]"
  while IFS= read -r org; do
    [[ -n "$org" ]] || continue
    # "Starred" is a virtual collection, not a real org to query
    [[ "$(printf '%s' "$org" | tr '[:upper:]' '[:lower:]')" == "starred" ]] && continue
    data="$(gh_repo_list "$org")"
    [[ -n "$data" ]] || continue
    all="$(jq -cn --argjson a "$all" --argjson b "$data" '$a + $b')"
  done < <(configured_orgs)
  normalized="$(jq -c -f src/normalize-repos.jq <<< "$all")"
  if [[ -n "$normalized" && "$normalized" != "[]" ]]; then
    printf '%s' "$normalized" > "$db.tmp" && mv "$db.tmp" "$db"
  fi
  return 0
}

# Succeed when a database file exists and is younger than the TTL.
db_fresh() {
  local db="$1" now mtime
  [[ -f "$db" ]] || return 1
  now="$(date +%s)"
  mtime="$(file_mtime "$db")"
  [[ "$mtime" =~ ^[0-9]+$ ]] || return 1
  [[ $(( now - mtime )) -lt "$DATABASE_TTL" ]]
}

# Print a database file, building it via the named function when missing. Return
# 1 when the served data is stale, so the caller refreshes it in the background.
db_read() {
  local db="$1" builder="$2"
  [[ -f "$db" ]] || "$builder"
  cat "$db" 2>/dev/null || printf '[]'
  db_fresh "$db" && return 0
  return 1
}

# Succeed when the database exists and is younger than the TTL.
database_fresh() {
  db_fresh "$(repos_db)"
}

# Print the database JSON, building it synchronously when missing. Return 1 when
# the served data is stale, so the caller refreshes it in the background.
read_database() {
  db_read "$(repos_db)" rebuild_database
}

# Path to the cached starred-repositories database.
starred_db() {
  printf '%s/starred.json' "${alfred_workflow_data:-.}"
  return 0
}

# Rebuild the starred database from the GitHub API, writing atomically. An empty
# result is not written, so it never poisons the cache.
rebuild_starred() {
  local db data normalized
  db="$(starred_db)"
  mkdir -p "$(dirname "$db")"
  data="$(gh_starred)"
  [[ -n "$data" ]] || return 0
  normalized="$(jq -c -f src/normalize-starred.jq <<< "$data" 2>/dev/null)"
  if [[ -n "$normalized" && "$normalized" != "[]" ]]; then
    printf '%s' "$normalized" > "$db.tmp" && mv "$db.tmp" "$db"
  fi
  return 0
}

# Print the starred database JSON, building it synchronously when missing.
# Return 1 when the served data is stale.
read_starred() {
  db_read "$(starred_db)" rebuild_starred
}
