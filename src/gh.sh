#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/config.sh
. src/database.sh
. src/cache.sh
. src/globals.sh

# Single entry point behind the "gh" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/gh.sh list "{query}"
#   run mode  (Run Script):    . src/gh.sh run  "{query}"
#
# Query grammar:
#   gh                    -> configured orgs
#   gh owner/             -> repos in that org (from the cached database)
#   gh owner/repo         -> repo picker (still matching a repo name)
#   gh owner/repo <sub>   -> repo sections, or #issue / @branch / *commit
#
# Items carry an action in their arg: "open <url>" or "copy <text>". Run mode
# dispatches on the first word.

mode="$1"
query="$2"

# Queue the configured orgs whose name matches the query prefix. Selecting one
# is drill-in only (valid=no), autocompleting "owner/" to list its repos.
add_org_items() {
  local filter="$1" org lc_filter lc_org
  lc_filter="$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r org; do
    [[ -n "$org" ]] || continue
    lc_org="$(printf '%s' "$org" | tr '[:upper:]' '[:lower:]')"
    case "$lc_org" in
      "$lc_filter"*) add_result "" "" "$org" "Browse $org repositories" "$ICON_ORG" "no" "$org/" ;;
      *) : ;;
    esac
  done < <(configured_orgs)
  return 0
}

# Print a Script Filter feedback object wrapping a JSON items array.
print_items() {
  local items="$1"
  printf '{"items":%s}\n' "$items"
  return 0
}

# Path to the hidden-repositories list.
hidden_file() {
  printf '%s/hidden' "${alfred_workflow_data:-.}"
  return 0
}

# Print the hidden repositories as a JSON array.
hidden_json() {
  local file
  file="$(hidden_file)"
  if [[ -f "$file" ]]; then
    jq -Rn '[inputs | select(length > 0)]' < "$file"
  else
    printf '[]'
  fi
  return 0
}

# Add a repo to the hidden list (deduplicated).
hide_repo() {
  local repo="$1" file
  file="$(hidden_file)"
  mkdir -p "${alfred_workflow_data:-.}"
  grep -qxF "$repo" "$file" 2>/dev/null || printf '%s\n' "$repo" >> "$file"
  return 0
}

# Remove a repo from the hidden list.
unhide_repo() {
  local repo="$1" file kept
  file="$(hidden_file)"
  [[ -f "$file" ]] || return 0
  kept="$(grep -vxF "$repo" "$file" || true)"
  printf '%s' "$kept" > "$file"
  return 0
}

# List the hidden repositories; selecting one unhides it.
list_hidden() {
  local repo found=0
  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    found=1
    add_result "" "unhide $repo" "$repo" "Press enter to unhide" "$ICON_REPO" "yes"
  done < <(hidden_json | jq -r '.[]')
  [[ "$found" -eq 1 ]] || add_result "" "" "No hidden repositories" "Hide a repo with cmd on its item" "$ICON_REPO" "no"
  get_json_results
  return 0
}

# Path to the pinned-repositories list.
pinned_file() {
  printf '%s/pinned' "${alfred_workflow_data:-.}"
  return 0
}

# Print the pinned repositories as a JSON array.
pinned_json() {
  local file
  file="$(pinned_file)"
  if [[ -f "$file" ]]; then
    jq -Rn '[inputs | select(length > 0)]' < "$file"
  else
    printf '[]'
  fi
  return 0
}

# Add a repo to the pinned list (deduplicated).
pin_repo() {
  local repo="$1" file
  file="$(pinned_file)"
  mkdir -p "${alfred_workflow_data:-.}"
  grep -qxF "$repo" "$file" 2>/dev/null || printf '%s\n' "$repo" >> "$file"
  return 0
}

# Remove a repo from the pinned list.
unpin_repo() {
  local repo="$1" file kept
  file="$(pinned_file)"
  [[ -f "$file" ]] || return 0
  kept="$(grep -vxF "$repo" "$file" || true)"
  printf '%s' "$kept" > "$file"
  return 0
}

# The repository picker for "owner/partial": filter the database and print items.
repo_picker() {
  local query="$1" repos items hidden pinned stale
  repos="$(read_database)"
  stale=$?
  if [[ "$stale" -eq 1 ]]; then
    # serve the stale list now and rebuild in the background for the rerun
    ( rebuild_database ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
  hidden="$(hidden_json)"
  pinned="$(pinned_json)"
  items="$(jq -c -f src/filter-repos.jq --arg q "$query" --arg icon "$ICON_REPO" --argjson hidden "$hidden" --argjson pinned "$pinned" <<< "$repos")"
  if [[ "$items" == "[]" ]]; then
    if gh_authed; then
      add_result "" "" "No repositories found" "Check the org name, or rebuild the database" "$ICON_REPO" "no"
    else
      add_result "" "auth login" "Not signed in to GitHub" "Press enter to run gh auth login in a terminal" "$ICON_LOGIN" "yes"
    fi
    [[ "$stale" -eq 1 ]] && set_rerun 0.5
    get_json_results
    return 0
  fi
  if [[ "$stale" -eq 1 ]]; then
    printf '{"rerun":0.5,"items":%s}\n' "$items"
  else
    print_items "$items"
  fi
  return 0
}

# Fetch a repo sub-resource (cached) and print filtered items. A cold cache is
# fetched synchronously; a stale cache is served now and refreshed in the
# background. Returns 1 when it served stale data, so the caller reruns.
# $1 repo  $2 filter  $3 cache slug  $4 api path  $5 ttl  $6 jq file  $7 icon
list_resource() {
  local repo="$1" filter="$2" slug="$3" apipath="$4" ttl="$5" jqfile="$6" icon="$7"
  local key cachefile data stale=0
  key="${slug}_$(printf '%s' "$repo" | tr '/' '_').json"
  cachefile="$(cache_path "$key")"
  if ! cache_fresh "$key" "$ttl"; then
    if [[ -f "$cachefile" ]]; then
      stale=1
      mkdir -p "$(dirname "$cachefile")"
      ( gh_api "$apipath" > "$cachefile.tmp" 2>/dev/null && mv "$cachefile.tmp" "$cachefile" ) >/dev/null 2>&1 &
      disown 2>/dev/null || true
    else
      data="$(gh_api "$apipath")"
      [[ -n "$data" ]] && printf '%s' "$data" | cache_set "$key"
    fi
  fi
  data="$(cache_get "$key")"
  [[ -n "$data" ]] || data="[]"
  jq -c -f "$jqfile" --arg q "$filter" --arg repo "$repo" --arg icon "$icon" <<< "$data"
  return "$stale"
}

# Print a resource item list, adding a rerun when the data was stale ($2 = 1).
emit_async() {
  local items="$1" stale="$2"
  if [[ "$stale" -eq 1 ]]; then
    printf '{"rerun":0.4,"items":%s}\n' "$items"
  else
    print_items "$items"
  fi
  return 0
}

# List open issues and pull requests, filtered by number or title.
list_issues() {
  local repo="$1" filter="$2" items stale
  items="$(list_resource "$repo" "$filter" issues "repos/$repo/issues?state=open&per_page=50" 60 src/format-issues.jq "$ICON_ISSUE")"
  stale=$?
  if [[ "$items" != "[]" ]]; then
    emit_async "$items" "$stale"
    return 0
  fi
  if [[ "$filter" =~ ^[0-9]+$ ]]; then
    add_result "" "open https://github.com/$repo/issues/$filter" "Open #$filter" "Open by number" "$ICON_ISSUE" "yes"
  else
    add_result "" "" "No open issues or pull requests" "Type a number to open one" "$ICON_ISSUE" "no"
  fi
  [[ "$stale" -eq 1 ]] && set_rerun 0.4
  get_json_results
  return 0
}

# List branches, filtered by name.
list_branches() {
  local repo="$1" filter="$2" items stale
  items="$(list_resource "$repo" "$filter" branches "repos/$repo/branches?per_page=100" 120 src/format-branches.jq "$ICON_BRANCH")"
  stale=$?
  if [[ "$items" != "[]" ]]; then
    emit_async "$items" "$stale"
    return 0
  fi
  add_result "" "" "No branches found" "Type a branch name" "$ICON_BRANCH" "no"
  [[ "$stale" -eq 1 ]] && set_rerun 0.4
  get_json_results
  return 0
}

# List recent commits, filtered by sha or message.
list_commits() {
  local repo="$1" filter="$2" items stale
  items="$(list_resource "$repo" "$filter" commits "repos/$repo/commits?per_page=30" 120 src/format-commits.jq "$ICON_COMMIT")"
  stale=$?
  if [[ "$items" != "[]" ]]; then
    emit_async "$items" "$stale"
    return 0
  fi
  add_result "" "" "No commits found" "Type a sha or message" "$ICON_COMMIT" "no"
  [[ "$stale" -eq 1 ]] && set_rerun 0.4
  get_json_results
  return 0
}

# Queue a repo-section item when its name matches the filter prefix.
# $1 name  $2 filter  $3 title  $4 subtitle  $5 arg  $6 icon
section_item() {
  local name="$1" filter="$2" title="$3" subtitle="$4" arg="$5" icon="$6"
  case "$name" in
    "$filter"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "yes" ;;
    *) : ;;
  esac
  return 0
}

# The section menu for a selected repository, filtered by a prefix.
repo_menu() {
  local repo="$1" filter="$2" base
  base="https://github.com/$repo"
  section_item open        "$filter" "Open $repo"     "Open the repository home"      "open $base"             "$ICON_REPO"
  section_item issues      "$filter" "Issues"         "Open issues"                   "open $base/issues"      "$ICON_ISSUE"
  section_item pulls       "$filter" "Pull requests"  "Open pull requests"            "open $base/pulls"       "$ICON_PULL"
  section_item actions     "$filter" "Actions"        "Open workflow runs"            "open $base/actions"     "$ICON_ACTIONS"
  section_item releases    "$filter" "Releases"       "Open releases"                 "open $base/releases"    "$ICON_RELEASE"
  section_item milestones  "$filter" "Milestones"     "Open milestones"               "open $base/milestones"  "$ICON_MILESTONE"
  section_item discussions "$filter" "Discussions"    "Open discussions"              "open $base/discussions" "$ICON_DISCUSSION"
  section_item admin       "$filter" "Settings"       "Open repository settings"      "open $base/settings"    "$ICON_ADMIN"
  section_item clone       "$filter" "Copy clone URL" "Copy git@github.com:$repo.git" "copy git@github.com:$repo.git" "$ICON_CLONE"
  if [[ -z "$filter" ]]; then
    add_result "" "" "#number" "Open an issue or pull request by number" "$ICON_ISSUE"  "no" "$repo #"
    add_result "" "" "@branch" "Open a branch"                           "$ICON_BRANCH" "no" "$repo @"
    add_result "" "" "*commit" "Open a commit"                           "$ICON_COMMIT" "no" "$repo *"
  fi
  get_json_results
  return 0
}

# A repository is selected: dispatch its subquery to a section or direct target.
repo_scoped() {
  local repo="$1" rest="$2"
  case "$rest" in
    "#"*) list_issues "$repo" "${rest#\#}"; return 0 ;;
    "@"*) list_branches "$repo" "${rest#@}"; return 0 ;;
    "*"*) list_commits "$repo" "${rest#\*}"; return 0 ;;
    *) : ;;
  esac
  repo_menu "$repo" "$rest"
  return 0
}

# Reopen Alfred on a query so the list refreshes in place after an action,
# instead of the window closing.
alfred_search() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  tell application id "com.runningwithcrocodiles.alfred" to search (item 1 of argv)
end run
APPLESCRIPT
  return 0
}

# Run mode: dispatch the item action.
if [[ "$mode" == "run" ]]; then
  action="${query%% *}"
  payload="${query#"$action"}"
  payload="${payload# }"
  case "$action" in
    open) open "$payload" ;;
    copy) printf '%s' "$payload" | pbcopy ;;
    auth) run_auth "$payload" ;;
    delete) run_delete "$payload" ;;
    autoupdate) set_autoupdate "$payload" ;;
    hide) hide_repo "$payload"; alfred_search "gh ${payload%%/*}/" ;;
    unhide) unhide_repo "$payload"; alfred_search "gh > hidden" ;;
    pin) pin_repo "$payload"; alfred_search "gh ${payload%%/*}/" ;;
    unpin) unpin_repo "$payload"; alfred_search "gh ${payload%%/*}/" ;;
    http://*|https://*) rm -f "$(autoupdate_pending)"; [[ -f src/update.sh ]] && . src/update.sh "$query" ;;
    *) : ;;
  esac
  exit
fi

# List mode
if [[ "$query" == ">"* ]]; then
  # global commands
  sub="${query#>}"
  sub="${sub# }"
  if [[ "$sub" == hidden* ]]; then
    list_hidden
  elif [[ "$sub" == update* ]]; then
    if [[ -f src/update.sh ]]; then
      . src/update.sh ""
    else
      add_result "" "" "Updater unavailable" "Rebuild the workflow bundle" "$ICON_UPDATE" "no"
      get_json_results
    fi
  else
    globals_menu "$sub"
  fi
elif [[ "$query" == *" "* ]] && [[ "${query%% *}" == */?* ]]; then
  # owner/repo <subquery> -> repo-scoped
  first="${query%% *}"
  rest="${query#"$first"}"
  rest="${rest# }"
  repo_scoped "$first" "$rest"
elif [[ "$query" == *"/"* ]]; then
  # owner/partial -> repo picker
  repo_picker "$query"
else
  # bare query -> matching orgs, with an optional update banner on the home view
  if [[ -z "$query" ]]; then
    autoupdate_refresh
    autoupdate_banner
  fi
  add_org_items "$query"
  get_json_results
fi
