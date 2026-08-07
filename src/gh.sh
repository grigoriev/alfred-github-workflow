#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/config.sh
. src/database.sh

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
      *) ;;
    esac
  done < <(configured_orgs)
  return 0
}

# The repository picker for "owner/partial": filter the database and print items.
repo_picker() {
  local query="$1" repos items
  repos="$(read_database)"
  items="$(jq -c -f src/filter-repos.jq --arg q "$query" --arg icon "$ICON_REPO" <<< "$repos")"
  if [[ "$items" == "[]" ]]; then
    add_result "" "" "No repositories found" "Check the org name, or rebuild the database" "$ICON_REPO" "no"
    get_json_results
    return 0
  fi
  printf '{"items":%s}\n' "$items"
  return 0
}

# Queue a repo-section item when its name matches the filter prefix.
# $1 name  $2 filter  $3 title  $4 subtitle  $5 arg  $6 icon
section_item() {
  local name="$1" filter="$2" title="$3" subtitle="$4" arg="$5" icon="$6"
  case "$name" in
    "$filter"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "yes" ;;
    *) ;;
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
  local repo="$1" rest="$2" base target
  base="https://github.com/$repo"
  case "$rest" in
    "#"*)
      target="${rest#\#}"
      if [[ -n "$target" ]]; then
        add_result "" "open $base/issues/$target" "Open #$target" "Issue or pull request $target" "$ICON_ISSUE" "yes"
      else
        add_result "" "" "Issue or pull request" "Type a number, e.g. 123" "$ICON_ISSUE" "no"
      fi
      get_json_results
      return 0
      ;;
    "@"*)
      target="${rest#@}"
      if [[ -n "$target" ]]; then
        add_result "" "open $base/tree/$target" "Open branch $target" "Browse the $target branch" "$ICON_BRANCH" "yes"
      else
        add_result "" "" "Branch" "Type a branch name" "$ICON_BRANCH" "no"
      fi
      get_json_results
      return 0
      ;;
    "*"*)
      target="${rest#\*}"
      if [[ -n "$target" ]]; then
        add_result "" "open $base/commit/$target" "Open commit $target" "View the commit" "$ICON_COMMIT" "yes"
      else
        add_result "" "" "Commit" "Type a commit sha" "$ICON_COMMIT" "no"
      fi
      get_json_results
      return 0
      ;;
    *) ;;
  esac
  repo_menu "$repo" "$rest"
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
    *) ;;
  esac
  exit
fi

# List mode
if [[ "$query" == *" "* ]] && [[ "${query%% *}" == */?* ]]; then
  # owner/repo <subquery> -> repo-scoped
  first="${query%% *}"
  rest="${query#"$first"}"
  rest="${rest# }"
  repo_scoped "$first" "$rest"
elif [[ "$query" == *"/"* ]]; then
  # owner/partial -> repo picker
  repo_picker "$query"
else
  # bare query -> matching orgs
  add_org_items "$query"
  get_json_results
fi
