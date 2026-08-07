#!/usr/bin/env bats

. src/config.sh

setup() {
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_data"
}

@test "configured_orgs: returns nothing without a file" {
  run configured_orgs
  [ -z "$output" ]
}

@test "configured_orgs: reads the file, skipping blanks and comments" {
  printf '# a comment\n\nfoo\nbar\n' > "$alfred_workflow_data/orgs"
  run configured_orgs
  [ "${lines[0]}" == "foo" ]
  [ "${lines[1]}" == "bar" ]
  [ "${#lines[@]}" -eq 2 ]
}
