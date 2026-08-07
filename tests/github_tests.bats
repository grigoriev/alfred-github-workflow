#!/usr/bin/env bats

# Unit tests for the gh locator and API wrappers, run in a controlled PATH.

@test "gh_bin: prefers gh on PATH" {
  local d="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$d"
  printf '#!/bin/bash\n' > "$d/gh"
  chmod +x "$d/gh"
  run env "PATH=$d" "GH_FALLBACK_PATHS=/nope/gh" /bin/bash -c '. src/github.sh; gh_bin'
  [ "$output" == "$d/gh" ]
}

@test "gh_bin: falls back to a configured path" {
  local d="$BATS_TEST_TMPDIR/fb"
  mkdir -p "$d"
  printf '#!/bin/bash\n' > "$d/gh"
  chmod +x "$d/gh"
  run env "PATH=/nonexistent" "GH_FALLBACK_PATHS=$d/gh" /bin/bash -c '. src/github.sh; gh_bin'
  [ "$output" == "$d/gh" ]
}

@test "gh_bin: empty when nothing is found" {
  run env "PATH=/nonexistent" "GH_FALLBACK_PATHS=/nope/gh" /bin/bash -c '. src/github.sh; gh_bin'
  [ "$output" == "" ]
}

@test "gh_repo_list: empty array when gh is missing" {
  run env "PATH=/nonexistent" "GH_FALLBACK_PATHS=/nope/gh" /bin/bash -c '. src/github.sh; gh_repo_list someorg'
  [ "$output" == "[]" ]
}

@test "gh_api: empty when gh is missing" {
  run env "PATH=/nonexistent" "GH_FALLBACK_PATHS=/nope/gh" /bin/bash -c '. src/github.sh; gh_api repos/x/y/issues'
  [ "$output" == "" ]
}

@test "gh_authed: succeeds when gh reports authentication" {
  local d="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$d"
  printf '#!/bin/bash\nexit 0\n' > "$d/gh"
  chmod +x "$d/gh"
  run env "PATH=$d" /bin/bash -c '. src/github.sh; gh_authed'
  [ "$status" -eq 0 ]
}

@test "gh_authed: fails when gh reports no authentication" {
  local d="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$d"
  printf '#!/bin/bash\nexit 1\n' > "$d/gh"
  chmod +x "$d/gh"
  run env "PATH=$d" /bin/bash -c '. src/github.sh; gh_authed'
  [ "$status" -ne 0 ]
}
