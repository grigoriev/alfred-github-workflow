#!/bin/bash

# A tiny TTL cache under "$alfred_workflow_cache", used for live API responses.

# Print the file path for a cache key.
cache_path() {
  printf '%s/%s' "${alfred_workflow_cache:-.}" "$1"
  return 0
}

# Print a file's modification time as a unix timestamp (BSD stat, then GNU).
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
  return 0
}

# Succeed when the cache entry exists and is younger than $2 seconds.
cache_fresh() {
  local file now mtime
  file="$(cache_path "$1")"
  [[ -f "$file" ]] || return 1
  now="$(date +%s)"
  mtime="$(file_mtime "$file")"
  [[ -n "$mtime" ]] || return 1
  [[ $(( now - mtime )) -lt "$2" ]]
}

# Print a cache entry.
cache_get() {
  cat "$(cache_path "$1")" 2>/dev/null
  return 0
}

# Store stdin in a cache entry.
cache_set() {
  local file
  file="$(cache_path "$1")"
  mkdir -p "$(dirname "$file")"
  cat > "$file"
  return 0
}
