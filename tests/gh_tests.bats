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
