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

@test "gh.sh: the global menu lists hidden repositories" {
  run bash -c '. src/gh.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Hidden repositories") != null' >/dev/null
}

@test "gh.sh: > hidden lists hidden repos with an unhide action" {
  mkdir -p "$alfred_workflow_data/visible"
  printf '#testorg/beta\n' > "$alfred_workflow_data/visible/testorg"
  run bash -c '. src/gh.sh list "> hidden"'
  echo "$output" | jq -e '[.items[].title] | index("testorg/beta") != null' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="testorg/beta") | .arg == "unhide testorg/beta"' >/dev/null
}

@test "gh.sh: > hidden with none shows a hint" {
  run bash -c '. src/gh.sh list "> hidden"'
  echo "$output" | jq -e '.items[0].title == "No hidden repositories"' >/dev/null
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

@test "gh.sh: > with no match yields an empty menu" {
  run bash -c '. src/gh.sh list "> zzz"'
  echo "$output" | jq -e '.items == []' >/dev/null
}

@test "gh.sh: run delete ignores an unknown target" {
  run bash -c '. src/gh.sh run "delete bogus"'
  [ "$status" -eq 0 ]
}

@test "gh.sh: run autoupdate ignores an unknown value" {
  run bash -c '. src/gh.sh run "autoupdate bogus"'
  [ "$status" -eq 0 ]
  [ ! -f "$alfred_workflow_data/autoupdate" ]
}

@test "gh.sh: > update delegates to the updater when present" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"updater ran"}]}'
STUB
  run bash -c '. src/gh.sh list "> update"'
  rm -f src/update.sh
  echo "$output" | jq -e '.items[0].title == "updater ran"' >/dev/null
}

@test "gh.sh: > update shows a hint when the updater is missing" {
  rm -f src/update.sh
  run bash -c '. src/gh.sh list "> update"'
  echo "$output" | jq -e '.items[0].title == "Updater unavailable"' >/dev/null
}

@test "gh.sh: run installs an update from a url" {
  export INSTALL_LOG="$BATS_TEST_TMPDIR/install.log"
  cat > src/update.sh <<'STUB'
#!/bin/bash
echo "install [$1]" >> "$INSTALL_LOG"
STUB
  run bash -c '. src/gh.sh run "https://example.com/GitHub.alfredworkflow"'
  rm -f src/update.sh
  grep -q 'install \[https://example.com/GitHub.alfredworkflow\]' "$INSTALL_LOG"
}

@test "gh.sh: autoupdate records a pending update and shows a banner" {
  : > "$alfred_workflow_data/autoupdate"
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"Update to v9.9.9","arg":"https://example.com/GitHub.alfredworkflow"}]}'
STUB
  run bash -c '. src/gh.sh list ""'
  rm -f src/update.sh
  [ -f "$alfred_workflow_data/update-available" ]
  echo "$output" | jq -e '.items[0].title == "Update available"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "https://example.com/GitHub.alfredworkflow"' >/dev/null
}

@test "gh.sh: autoupdate disabled does not check" {
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"Update to v9","arg":"https://x/y"}]}'
STUB
  run bash -c '. src/gh.sh list ""'
  rm -f src/update.sh
  [ ! -f "$alfred_workflow_data/update-available" ]
}

@test "gh.sh: autoupdate is throttled within a day" {
  : > "$alfred_workflow_data/autoupdate"
  : > "$alfred_workflow_data/autoupdate-checked"
  cat > src/update.sh <<'STUB'
#!/bin/bash
printf '{"items":[{"title":"Update to v9","arg":"https://x/y"}]}'
STUB
  run bash -c '. src/gh.sh list ""'
  rm -f src/update.sh
  [ ! -f "$alfred_workflow_data/update-available" ]
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
