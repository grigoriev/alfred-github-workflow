#!/usr/bin/env bats

# Coverage tests for the cached-login path, the database freshness helper, and
# the My/All pseudo-orgs.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
}

@test "github.sh: gh_login serves a cached login without a network call" {
  printf 'octocat' > "$alfred_workflow_data/login"
  run bash -c '. src/github.sh; gh_login'
  [ "$output" = "octocat" ]
}

@test "database.sh: database_fresh reports a missing database as stale" {
  run bash -c '. src/database.sh; database_fresh; echo rc=$?'
  [[ "$output" == *"rc=1"* ]]
}

@test "gh.sh: the My and All pseudo-orgs render from the orgs file" {
  printf '@My\n@All\n' > "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("My") != null and index("All") != null' >/dev/null
}
