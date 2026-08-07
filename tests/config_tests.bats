#!/usr/bin/env bats

. src/config.sh

setup() {
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  mkdir -p "$alfred_workflow_data"
}

@test "configured_orgs: defaults to the three orgs" {
  run configured_orgs
  [[ "$output" =~ "grigoriev" ]]
  [[ "$output" =~ "intechcore" ]]
  [[ "$output" =~ "SchweizerischeBundesbahnen" ]]
}

@test "configured_orgs: reads an override file" {
  printf 'foo\nbar\n' > "$alfred_workflow_data/orgs"
  run configured_orgs
  [ "${lines[0]}" == "foo" ]
  [ "${lines[1]}" == "bar" ]
  [ "${#lines[@]}" -eq 2 ]
}
