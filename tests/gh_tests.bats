#!/usr/bin/env bats

# Integration tests for src/gh.sh. gh, open and pbcopy are mocked.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_data"
  printf 'testorg\n' > "$alfred_workflow_data/orgs"
}

@test "gh.sh: lists configured orgs for an empty query" {
  run bash -c '. src/gh.sh list ""'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.items[].title] == ["testorg"]' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "testorg/"' >/dev/null
}

@test "gh.sh: filters orgs by prefix" {
  run bash -c '. src/gh.sh list "test"'
  echo "$output" | jq -e '[.items[].title] == ["testorg"]' >/dev/null
  run bash -c '. src/gh.sh list "zzz"'
  echo "$output" | jq -e '.items == []' >/dev/null
}

@test "gh.sh: lists repos for owner/" {
  run bash -c '. src/gh.sh list "testorg/"'
  echo "$output" | jq -e '[.items[].title] | sort == ["testorg/alpha", "testorg/beta"]' >/dev/null
}

@test "gh.sh: filters repos by owner/name" {
  run bash -c '. src/gh.sh list "testorg/al"'
  echo "$output" | jq -e '[.items[].title] == ["testorg/alpha"]' >/dev/null
}

@test "gh.sh: a repo item opens the repo url" {
  run bash -c '. src/gh.sh list "testorg/al"'
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha"' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "testorg/alpha "' >/dev/null
}

@test "gh.sh: unknown owner shows a no-repositories hint" {
  run bash -c '. src/gh.sh list "nope/"'
  echo "$output" | jq -e '.items[0].title == "No repositories found"' >/dev/null
}

@test "gh.sh: run open dispatches to open" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/gh.sh run "open https://github.com/testorg/alpha"'
  grep -q "https://github.com/testorg/alpha" "$OPEN_LOG"
}

@test "gh.sh: run copy dispatches to pbcopy" {
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
  run bash -c '. src/gh.sh run "copy git@github.com:testorg/alpha.git"'
  grep -q "git@github.com:testorg/alpha.git" "$PBCOPY_LOG"
}

@test "gh.sh: a selected repo shows the section menu" {
  run bash -c '. src/gh.sh list "testorg/alpha "'
  echo "$output" | jq -e '[.items[].title] | index("Issues") != null and index("Pull requests") != null and index("Copy clone URL") != null' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="Issues") | .arg == "open https://github.com/testorg/alpha/issues"' >/dev/null
}

@test "gh.sh: the empty repo menu offers number, branch and commit hints" {
  run bash -c '. src/gh.sh list "testorg/alpha "'
  echo "$output" | jq -e '[.items[].autocomplete] | index("testorg/alpha #") != null and index("testorg/alpha @") != null and index("testorg/alpha *") != null' >/dev/null
}

@test "gh.sh: a section prefix filters the menu" {
  run bash -c '. src/gh.sh list "testorg/alpha iss"'
  echo "$output" | jq -e '[.items[].title] == ["Issues"]' >/dev/null
}

@test "gh.sh: clone copies the clone url" {
  run bash -c '. src/gh.sh list "testorg/alpha clone"'
  echo "$output" | jq -e '.items[0].arg == "copy git@github.com:testorg/alpha.git"' >/dev/null
}

@test "gh.sh: #number opens the issue url" {
  run bash -c '. src/gh.sh list "testorg/alpha #42"'
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/issues/42"' >/dev/null
}

@test "gh.sh: @branch opens the tree url" {
  run bash -c '. src/gh.sh list "testorg/alpha @main"'
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/tree/main"' >/dev/null
}

@test "gh.sh: *commit opens the commit url" {
  run bash -c '. src/gh.sh list "testorg/alpha *abc123"'
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/commit/abc123"' >/dev/null
}
