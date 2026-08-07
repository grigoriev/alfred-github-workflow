#!/bin/bash

# A tiny TTL cache under "$alfred_workflow_cache", used for live API responses.

# Print the file path for a cache key.
cache_path() {
  local key="$1"
  printf '%s/%s' "${alfred_workflow_cache:-.}" "$key"
  return 0
}

# Print a file's modification time as a unix timestamp. Try GNU stat first (its
# -c is a clean failure on BSD), then BSD stat, so the ambiguous BSD -f never
# runs on GNU where it can print filesystem info instead of failing.
file_mtime() {
  local file="$1"
  stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null
  return 0
}

# Succeed when the cache entry exists and is younger than the ttl seconds.
cache_fresh() {
  local key="$1" ttl="$2" file now mtime
  file="$(cache_path "$key")"
  [[ -f "$file" ]] || return 1
  now="$(date +%s)"
  mtime="$(file_mtime "$file")"
  [[ -n "$mtime" ]] || return 1
  [[ $(( now - mtime )) -lt "$ttl" ]]
}

# Print a cache entry.
cache_get() {
  local key="$1"
  cat "$(cache_path "$key")" 2>/dev/null
  return 0
}

# Store stdin in a cache entry.
cache_set() {
  local key="$1" file
  file="$(cache_path "$key")"
  mkdir -p "$(dirname "$file")"
  cat > "$file"
  return 0
}
