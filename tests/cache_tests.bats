#!/usr/bin/env bats

. src/cache.sh

setup() {
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
}

@test "cache_set and cache_get: round-trip a value" {
  printf 'hello' | cache_set "k.json"
  run cache_get "k.json"
  [ "$output" == "hello" ]
}

@test "cache_fresh: true within the ttl, false when missing" {
  printf 'x' | cache_set "k.json"
  run cache_fresh "k.json" 60
  [ "$status" -eq 0 ]
  run cache_fresh "missing.json" 60
  [ "$status" -ne 0 ]
}

@test "cache_fresh: false when older than the ttl" {
  printf 'x' | cache_set "k.json"
  run cache_fresh "k.json" 0
  [ "$status" -ne 0 ]
}
