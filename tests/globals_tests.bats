#!/usr/bin/env bats

# gh, osascript, open and pbcopy are mocked.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
}

@test "gh.sh: > lists the global commands" {
  run bash -c '. src/gh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Sign in") != null and index("Delete cache") != null and index("Delete database") != null' >/dev/null
}

@test "gh.sh: > filters the global commands" {
  run bash -c '. src/gh.sh list "> delete"'
  echo "$output" | jq -e '[.items[].title] == ["Delete cache", "Delete database"]' >/dev/null
}

@test "gh.sh: the login item runs gh auth login" {
  run bash -c '. src/gh.sh list "> login"'
  echo "$output" | jq -e '.items[0].arg == "auth login"' >/dev/null
}

@test "gh.sh: run auth opens a terminal via osascript" {
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  run bash -c '. src/gh.sh run "auth login"'
  grep -q "gh auth login" "$OSASCRIPT_LOG"
}

@test "gh.sh: run delete cache clears the cache dir" {
  printf 'x' > "$alfred_workflow_cache/some.json"
  run bash -c '. src/gh.sh run "delete cache"'
  [ ! -f "$alfred_workflow_cache/some.json" ]
}

@test "gh.sh: run delete database removes the database" {
  printf '[]' > "$alfred_workflow_data/repos.json"
  run bash -c '. src/gh.sh run "delete database"'
  [ ! -f "$alfred_workflow_data/repos.json" ]
}

@test "gh.sh: autoupdate toggles and the menu reflects it" {
  run bash -c '. src/gh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Activate autoupdate") != null' >/dev/null
  run bash -c '. src/gh.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
  run bash -c '. src/gh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Deactivate autoupdate") != null' >/dev/null
  run bash -c '. src/gh.sh run "autoupdate off"'
  [ ! -f "$alfred_workflow_data/autoupdate" ]
}
