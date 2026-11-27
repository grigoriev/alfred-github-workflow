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

# A gh mock that prints the token it received, so tests can see what gh_run passed.
make_token_gh() {
  local d="$1"
  mkdir -p "$d"
  printf '#!/bin/bash\nprintf "token=%%s args=%%s" "${GH_TOKEN:-}" "$*"\n' > "$d/gh"
  chmod +x "$d/gh"
}

@test "gh_run: passes the token command output to gh as GH_TOKEN" {
  local d="$BATS_TEST_TMPDIR/tok"
  make_token_gh "$d"
  run env -u GH_TOKEN -u GITHUB_TOKEN "PATH=$d:/usr/bin:/bin" "GH_TOKEN_COMMAND=echo secret-1" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$status" -eq 0 ]
  [ "$output" == "token=secret-1 args=api user" ]
}

@test "gh_run: an existing GH_TOKEN wins over the token command" {
  local d="$BATS_TEST_TMPDIR/tok"
  make_token_gh "$d"
  run env "PATH=$d:/usr/bin:/bin" "GH_TOKEN=from-env" "GH_TOKEN_COMMAND=echo secret-1" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$output" == "token=from-env args=api user" ]
}

@test "gh_run: GITHUB_TOKEN also skips the token command" {
  local d="$BATS_TEST_TMPDIR/tok"
  make_token_gh "$d"
  run env -u GH_TOKEN "PATH=$d:/usr/bin:/bin" "GITHUB_TOKEN=gt" "GH_TOKEN_COMMAND=echo secret-1" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$output" == "token= args=api user" ]
}

@test "gh_run: without a token command gh runs with its own login" {
  local d="$BATS_TEST_TMPDIR/tok"
  make_token_gh "$d"
  run env -u GH_TOKEN -u GITHUB_TOKEN -u GH_TOKEN_COMMAND "PATH=$d:/usr/bin:/bin" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$output" == "token= args=api user" ]
}

@test "gh_run: a failing token command falls back to the gh login" {
  local d="$BATS_TEST_TMPDIR/tok"
  make_token_gh "$d"
  run env -u GH_TOKEN -u GITHUB_TOKEN "PATH=$d:/usr/bin:/bin" "GH_TOKEN_COMMAND=exit 3" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$status" -eq 0 ]
  [ "$output" == "token= args=api user" ]
}

@test "gh_run: returns 127 when gh is missing" {
  run -127 env "PATH=/nonexistent" "GH_FALLBACK_PATHS=/nope/gh" /bin/bash -c '. src/github.sh; gh_run api user'
  [ "$status" -eq 127 ]
}

@test "gh_authed: uses the token command when gh is not signed in" {
  local d="$BATS_TEST_TMPDIR/auth"
  mkdir -p "$d"
  printf '#!/bin/bash\n[ "$GH_TOKEN" = "ok" ]\n' > "$d/gh"
  chmod +x "$d/gh"
  run env -u GH_TOKEN -u GITHUB_TOKEN "PATH=$d:/usr/bin:/bin" "GH_TOKEN_COMMAND=echo ok" /bin/bash -c '. src/github.sh; gh_authed'
  [ "$status" -eq 0 ]
}
