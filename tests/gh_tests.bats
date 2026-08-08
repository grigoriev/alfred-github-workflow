#!/usr/bin/env bats

# Integration tests for src/gh.sh. gh, open and pbcopy are mocked.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data"
  printf 'testorg\n' > "$alfred_workflow_data/orgs"
}

@test "gh.sh: lists configured orgs for an empty query" {
  run bash -c '. src/gh.sh list ""'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.items[].title] | index("testorg") != null' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="testorg") | .autocomplete == "testorg/"' >/dev/null
}

@test "gh.sh: a Starred line in the orgs file positions the pseudo-org" {
  printf 'testorg\n@Starred\n' > "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list ""'
  echo "$output" | jq -e '[.items[].title] == ["testorg", "Starred"]' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="Starred") | .autocomplete == "Starred/"' >/dev/null
  run bash -c '. src/gh.sh list "star"'
  echo "$output" | jq -e '[.items[].title] == ["Starred"]' >/dev/null
}

@test "gh.sh: no Starred line means no starred pseudo-org in the list" {
  run bash -c '. src/gh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("Starred") == null' >/dev/null
}

@test "gh.sh: a My line in the orgs file positions the pseudo-org" {
  printf 'testorg\n@My\n' > "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list ""'
  echo "$output" | jq -e '[.items[].title] == ["testorg", "My"]' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="My") | .autocomplete == "My/"' >/dev/null
}

@test "gh.sh: My/ lists the user's pages, opening them in the browser" {
  printf '@My\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "My/"'
  echo "$output" | jq -e '[.items[].title] | index("My pull requests") != null and index("My issues") != null and index("My notifications") != null' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="My pull requests") | .arg == "open https://github.com/pulls"' >/dev/null
}

@test "gh.sh: My/ includes login-based pages and caches the login" {
  printf '@My\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "My/"'
  echo "$output" | jq -e '.items[] | select(.title=="My profile") | .arg == "open https://github.com/testuser"' >/dev/null
  [ -f "$alfred_workflow_data/login" ]
}

@test "gh.sh: My/ filters its items" {
  printf '@My\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "My/pull"'
  echo "$output" | jq -e '[.items[].title] == ["My pull requests"]' >/dev/null
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

@test "gh.sh: filters repos by a substring of the name, not only a prefix" {
  run bash -c '. src/gh.sh list "testorg/ph"'
  echo "$output" | jq -e '[.items[].title] == ["testorg/alpha"]' >/dev/null
  run bash -c '. src/gh.sh list "testorg/et"'
  echo "$output" | jq -e '[.items[].title] == ["testorg/beta"]' >/dev/null
}

@test "gh.sh: a repo item drills into the repo menu on enter" {
  run bash -c '. src/gh.sh list "testorg/al"'
  echo "$output" | jq -e '.items[0].valid == false' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "testorg/alpha "' >/dev/null
}

@test "gh.sh: Starred/ lists the user's starred repos" {
  printf '@Starred\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "Starred/"'
  echo "$output" | jq -e '[.items[].title] | index("octocat/hello") != null and index("torvalds/linux") != null' >/dev/null
  [ -f "$alfred_workflow_data/starred.json" ]
}

@test "gh.sh: repos are listed alphabetically, not by date" {
  printf '@Starred\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "Starred/"'
  echo "$output" | jq -e '[.items[].title] == ["octocat/hello", "torvalds/linux"]' >/dev/null
}

@test "gh.sh: Starred/ filters and drills into the real repo" {
  printf '@Starred\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "Starred/linux"'
  echo "$output" | jq -e '[.items[].title] == ["torvalds/linux"]' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "torvalds/linux "' >/dev/null
}

@test "gh.sh: starred items pin but do not offer hide" {
  printf '@Starred\n' >> "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "Starred/hello"'
  echo "$output" | jq -e '.items[0].mods.alt.arg == "pin octocat/hello"' >/dev/null
  echo "$output" | jq -e '.items[0].mods | has("cmd") | not' >/dev/null
}

@test "gh.sh: an unconfigured pseudo-org does not work when typed by hand" {
  run bash -c '. src/gh.sh list "Starred/"'
  echo "$output" | jq -e '[.items[].title] | index("octocat/hello") == null' >/dev/null
}

@test "gh.sh: All/ searches across orgs and excludes hidden repos" {
  printf 'testorg\n@All\n' > "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "testorg/"'
  run bash -c '. src/gh.sh run "hide testorg/beta"'
  run bash -c '. src/gh.sh list "All/a"'
  echo "$output" | jq -e '[.items[].title] == ["testorg/alpha"]' >/dev/null
  echo "$output" | jq -e '.items[0].mods | has("cmd") | not' >/dev/null
}

@test "gh.sh: unknown owner shows a no-repositories hint" {
  run bash -c '. src/gh.sh list "nope/"'
  echo "$output" | jq -e '.items[0].title == "No repositories found"' >/dev/null
}

@test "gh.sh: shows a sign-in hint when gh is not authenticated" {
  printf 'nope\n' > "$alfred_workflow_data/orgs"
  run bash -c 'export MOCK_UNAUTH=1; . src/gh.sh list "nope/"'
  echo "$output" | jq -e '.items[0].title == "Not signed in to GitHub"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "auth login"' >/dev/null
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

@test "gh.sh: the repo menu offers branches, tags and security" {
  run bash -c '. src/gh.sh list "testorg/alpha "'
  echo "$output" | jq -e '[.items[].title] | index("Branches") != null and index("Tags") != null and index("Security") != null' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="Security") | .arg == "open https://github.com/testorg/alpha/security"' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="Tags") | .arg == "open https://github.com/testorg/alpha/tags"' >/dev/null
}

@test "gh.sh: a section prefix filters to branches" {
  run bash -c '. src/gh.sh list "testorg/alpha branch"'
  echo "$output" | jq -e '[.items[].title] == ["Branches"]' >/dev/null
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

@test "gh.sh: # lists open issues and pull requests" {
  run bash -c '. src/gh.sh list "testorg/alpha #"'
  echo "$output" | jq -e '[.items[].title] == ["#1 First issue", "#2 Fix things"]' >/dev/null
  echo "$output" | jq -e '.items[] | select(.title=="#2 Fix things") | .subtitle == "Pull request"' >/dev/null
}

@test "gh.sh: # filters issues and links to the issue url" {
  run bash -c '. src/gh.sh list "testorg/alpha #1"'
  echo "$output" | jq -e '[.items[].title] == ["#1 First issue"]' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/issues/1"' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "testorg/alpha #1"' >/dev/null
}

@test "gh.sh: # with an unknown number offers a direct open" {
  run bash -c '. src/gh.sh list "testorg/alpha #999"'
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/issues/999"' >/dev/null
}

@test "gh.sh: @ lists branches" {
  run bash -c '. src/gh.sh list "testorg/alpha @"'
  echo "$output" | jq -e '[.items[].title] == ["main", "develop"]' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/tree/main"' >/dev/null
}

@test "gh.sh: @ filters branches" {
  run bash -c '. src/gh.sh list "testorg/alpha @dev"'
  echo "$output" | jq -e '[.items[].title] == ["develop"]' >/dev/null
}

@test "gh.sh: * lists commits with short shas" {
  run bash -c '. src/gh.sh list "testorg/alpha *"'
  echo "$output" | jq -e '.items[0].title == "abc1234 first commit"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "open https://github.com/testorg/alpha/commit/abc1234def5678"' >/dev/null
}

@test "gh.sh: caches api responses" {
  run bash -c '. src/gh.sh list "testorg/alpha #"'
  [ -f "$alfred_workflow_cache/issues_testorg_alpha.json" ]
}

@test "gh.sh: a stale database serves repos and asks for a rerun" {
  mkdir -p "$alfred_workflow_data"
  printf '[{"owner":"testorg","name":"alpha","nameWithOwner":"testorg/alpha","description":"","isPrivate":false,"pushedAt":"2024-01-01T00:00:00Z","url":"https://github.com/testorg/alpha"}]' > "$alfred_workflow_data/repos.json"
  run bash -c 'export DATABASE_TTL=0; . src/gh.sh list "testorg/"'
  echo "$output" | jq -e '.rerun == 0.5' >/dev/null
  echo "$output" | jq -e '[.items[].title] | index("testorg/alpha") != null' >/dev/null
}

@test "gh.sh: a stale cache serves data and asks for a rerun" {
  mkdir -p "$alfred_workflow_cache"
  printf '[{"number":1,"title":"Cached issue"}]' > "$alfred_workflow_cache/issues_testorg_alpha.json"
  touch -t 200001010000 "$alfred_workflow_cache/issues_testorg_alpha.json"
  run bash -c '. src/gh.sh list "testorg/alpha #"'
  echo "$output" | jq -e '.rerun == 0.4' >/dev/null
  echo "$output" | jq -e '(.items | length) >= 1' >/dev/null
}

@test "gh.sh: a repo item offers a hide modifier" {
  run bash -c '. src/gh.sh list "testorg/al"'
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "hide testorg/alpha"' >/dev/null
}

@test "gh.sh: hiding a repo removes it from the picker" {
  run bash -c '. src/gh.sh list "testorg/"'
  run bash -c '. src/gh.sh run "hide testorg/beta"'
  [ -f "$alfred_workflow_data/visible/testorg" ]
  run bash -c '. src/gh.sh list "testorg/"'
  echo "$output" | jq -e '[.items[].title] == ["testorg/alpha"]' >/dev/null
}

@test "gh.sh: new org repos are synced in as commented and hidden" {
  run bash -c '. src/gh.sh list "testorg/"'
  printf 'testorg/alpha\n' > "$alfred_workflow_data/visible/testorg"
  run bash -c '. src/gh.sh list "testorg/"'
  grep -qxF '#testorg/beta' "$alfred_workflow_data/visible/testorg"
  echo "$output" | jq -e '[.items[].title] == ["testorg/alpha"]' >/dev/null
}

@test "gh.sh: > hidden lists an org edit item and hidden repos" {
  run bash -c '. src/gh.sh list "testorg/"'
  run bash -c '. src/gh.sh run "hide testorg/beta"'
  run bash -c '. src/gh.sh list "> hidden"'
  echo "$output" | jq -e '[.items[].title] | index("Edit testorg repositories") != null' >/dev/null
  echo "$output" | jq -e '[.items[].title] | index("testorg/beta") != null' >/dev/null
}

@test "gh.sh: edit-visible opens the org file in an editor" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  run bash -c '. src/gh.sh run "edit-visible testorg"'
  [ -f "$alfred_workflow_data/visible/testorg" ]
  grep -q "visible/testorg" "$OPEN_LOG"
}

@test "gh.sh: hiding reopens the org list so the window stays open" {
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  run bash -c '. src/gh.sh run "hide testorg/beta"'
  grep -q "gh testorg/" "$OSASCRIPT_LOG"
}

@test "gh.sh: unhiding a repo restores it" {
  run bash -c '. src/gh.sh list "testorg/"'
  run bash -c '. src/gh.sh run "hide testorg/beta"'
  run bash -c '. src/gh.sh run "unhide testorg/beta"'
  run bash -c '. src/gh.sh list "testorg/"'
  echo "$output" | jq -e '[.items[].title] | index("testorg/beta") != null' >/dev/null
}

@test "gh.sh: a repo item offers a pin modifier" {
  run bash -c '. src/gh.sh list "testorg/al"'
  echo "$output" | jq -e '.items[0].mods.alt.arg == "pin testorg/alpha"' >/dev/null
}

@test "gh.sh: pinning a repo sorts it to the top with a star" {
  run bash -c '. src/gh.sh run "pin testorg/beta"'
  [ -f "$alfred_workflow_data/pinned" ]
  run bash -c '. src/gh.sh list "testorg/"'
  echo "$output" | jq -e '.items[0].title == "★ testorg/beta"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.alt.arg == "unpin testorg/beta"' >/dev/null
}

@test "gh.sh: unpinning a repo removes the star" {
  run bash -c '. src/gh.sh run "pin testorg/beta"'
  run bash -c '. src/gh.sh run "unpin testorg/beta"'
  run bash -c '. src/gh.sh list "testorg/"'
  echo "$output" | jq -e '[.items[].title] | index("★ testorg/beta") == null' >/dev/null
}

@test "gh.sh: # with no match shows a hint" {
  run bash -c '. src/gh.sh list "testorg/alpha #zzz"'
  echo "$output" | jq -e '.items[0].title == "No open issues or pull requests"' >/dev/null
}

@test "gh.sh: @ with no match shows a hint" {
  run bash -c '. src/gh.sh list "testorg/alpha @zzz"'
  echo "$output" | jq -e '.items[0].title == "No branches found"' >/dev/null
}

@test "gh.sh: * with no match shows a hint" {
  run bash -c '. src/gh.sh list "testorg/alpha *zzz"'
  echo "$output" | jq -e '.items[0].title == "No commits found"' >/dev/null
}

@test "gh.sh: orgs not matching the query are skipped" {
  printf 'testorg\nother\n' > "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list "test"'
  echo "$output" | jq -e '[.items[].title] == ["testorg"]' >/dev/null
}

@test "gh.sh: > orgs lists an edit item and the configured orgs" {
  run bash -c '. src/gh.sh list "> orgs"'
  echo "$output" | jq -e '.items[0].title == "Edit organizations"' >/dev/null
  echo "$output" | jq -e '.items[0].arg == "edit-orgs"' >/dev/null
  echo "$output" | jq -e '[.items[].title] | index("testorg") != null' >/dev/null
}

@test "gh.sh: edit-orgs seeds and opens the orgs file in an editor" {
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  rm -f "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh run "edit-orgs"'
  [ -f "$alfred_workflow_data/orgs" ]
  grep -q "orgs" "$OPEN_LOG"
}

@test "gh.sh: shows an add-organizations hint when none are configured" {
  rm -f "$alfred_workflow_data/orgs"
  run bash -c '. src/gh.sh list ""'
  echo "$output" | jq -e '[.items[].title] | index("No organizations yet") != null' >/dev/null
}

@test "gh.sh: run ignores an unknown action" {
  run bash -c '. src/gh.sh run "bogus payload"'
  [ "$status" -eq 0 ]
}
