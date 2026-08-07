#!/usr/bin/env bats

# gh is mocked (tests/mocks/bin) and the org list is a one-org fixture.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_data"
  printf 'testorg\n' > "$alfred_workflow_data/orgs"
}

@test "rebuild_database: normalizes repos from the configured orgs" {
  run bash -c '. src/database.sh; rebuild_database; cat "$(repos_db)"'
  echo "$output" | jq -e 'length == 2' >/dev/null
  echo "$output" | jq -e '.[0] | has("owner") and has("nameWithOwner") and has("url")' >/dev/null
  echo "$output" | jq -e 'map(.owner) | all(. == "testorg")' >/dev/null
}

@test "read_database: builds the database when it is missing" {
  run bash -c '. src/database.sh; read_database'
  echo "$output" | jq -e '[.[].name] | index("alpha") != null and index("beta") != null' >/dev/null
}

@test "read_database: fresh within the ttl, stale past it" {
  bash -c '. src/database.sh; rebuild_database'
  run bash -c '. src/database.sh; read_database >/dev/null'
  [ "$status" -eq 0 ]
  run bash -c 'export DATABASE_TTL=0; . src/database.sh; read_database >/dev/null'
  [ "$status" -eq 1 ]
}
