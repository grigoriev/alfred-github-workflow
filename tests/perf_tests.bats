#!/usr/bin/env bats

# The database is pre-built with many repos so the filter path does no gh calls.

setup() {
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_data"
  jq -n '[range(500) | {
    owner: "testorg", name: ("repo" + (. | tostring)),
    nameWithOwner: ("testorg/repo" + (. | tostring)),
    description: "", isPrivate: false, pushedAt: "2024-01-01T00:00:00Z",
    url: ("https://github.com/testorg/repo" + (. | tostring)) }]' \
    > "$alfred_workflow_data/repos.json"
  printf 'testorg\n' > "$alfred_workflow_data/orgs"
}

@test "perf: listing 500 repos stays fast" {
  local start end
  start=$(date +%s)
  run bash -c '. src/gh.sh list "testorg/"'
  end=$(date +%s)
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.items | length == 500' >/dev/null
  [ $((end - start)) -lt 3 ]
}

@test "perf: filtering 500 repos stays fast" {
  local start end
  start=$(date +%s)
  run bash -c '. src/gh.sh list "testorg/repo1"'
  end=$(date +%s)
  [ "$status" -eq 0 ]
  [ $((end - start)) -lt 3 ]
}
