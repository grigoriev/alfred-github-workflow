#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/config.sh
. src/database.sh

# Single entry point behind the "gh" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/gh.sh list "{query}"
#   run mode  (Run Script):    . src/gh.sh run  "{query}"
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
if [[ "$query" == *"/"* ]]; then
  # owner/rest -> repos in that owner filtered by the whole "owner/rest"
  repos="$(read_database)"
  items="$(jq -c -f src/filter-repos.jq --arg q "$query" --arg icon "$ICON_REPO" <<< "$repos")"
  if [[ "$items" == "[]" ]]; then
    add_result "" "" "No repositories found" "Check the org name, or rebuild the database" "$ICON_REPO" "no"
    get_json_results
    exit
  fi
  printf '{"items":%s}\n' "$items"
else
  # Bare query -> matching orgs to drill into
  add_org_items "$query"
  get_json_results
fi
