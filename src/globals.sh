#!/bin/bash

# Global commands behind "gh >": auth, cache and database maintenance, updates.
# The autoupdate helpers (autoupdate_enabled, set_autoupdate, autoupdate_refresh,
# autoupdate_banner, ...) come from the shared, fetched src/autoupdate.sh.

. src/media.sh
. src/autoupdate.sh

# Lowercase a string.
gh_lower() {
  local text="$1"
  printf '%s' "$text" | tr '[:upper:]' '[:lower:]'
  return 0
}

# Queue a global command when its token contains the filter (case-insensitive).
# $1 token  $2 filter  $3 title  $4 subtitle  $5 arg  $6 valid  $7 icon  $8 autocomplete
global_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" valid="$6" icon="$7" auto="$8"
  case "$(gh_lower "$token")" in
    *"$(gh_lower "$filter")"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "$valid" "$auto" ;;
    *) : ;;
  esac
  return 0
}

# The global command menu, filtered by a substring.
globals_menu() {
  local filter="$1"
  global_item "login"           "$filter" "Sign in"           "Run gh auth login in a terminal"  "auth login"      "yes" "$ICON_LOGIN"  ""
  global_item "logout"          "$filter" "Sign out"          "Run gh auth logout in a terminal" "auth logout"     "yes" "$ICON_LOGOUT" ""
  global_item "organizations orgs" "$filter" "Organizations"  "Edit the list of organizations"   ""                "no"  "$ICON_ORG"    "> orgs"
  global_item "hidden repos"    "$filter" "Hidden repositories" "Edit org lists and unhide repos" ""               "no"  "$ICON_REPO"   "> hidden"
  global_item "delete cache"    "$filter" "Delete cache"      "Drop cached API responses"        "delete cache"    "yes" "$ICON_TRASH"  ""
  global_item "delete database" "$filter" "Delete database"   "Rebuild the repository list"      "delete database" "yes" "$ICON_TRASH"  ""
  autoupdate_menu "$filter" "$ICON_UPDATE"
  get_json_results
  return 0
}

# Open a terminal running a gh auth command. $1 = login | logout. Clear the
# token env vars so a login stores credentials instead of using an inherited
# GITHUB_TOKEN (which Alfred would not see anyway).
run_auth() {
  local command="$1"
  osascript - "env -u GITHUB_TOKEN -u GH_TOKEN gh auth $command" <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    activate
    do script (item 1 of argv)
  end tell
end run
APPLESCRIPT
  return 0
}

# Open the organizations list in a text editor, seeding a template if missing.
edit_orgs() {
  local file
  file="$(orgs_file)"
  mkdir -p "${alfred_workflow_data:-.}"
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "# One GitHub organization or user per line." \
                  "# Add \"@Starred\" for your starred repositories." \
                  "# Add \"@My\" for your pull requests, issues, and profile." \
                  "# Add \"@All\" to search repos across every org." \
                  "# Lines that start with # are ignored." > "$file"
  fi
  open -e "$file"
  return 0
}

# Delete the cache or the database. $1 = cache | database.
run_delete() {
  local target="$1"
  case "$target" in
    cache)
      if [[ -n "$alfred_workflow_cache" ]]; then
        rm -rf "$alfred_workflow_cache"
        mkdir -p "$alfred_workflow_cache"
      fi
      ;;
    database)
      rm -f "${alfred_workflow_data:-.}/repos.json"
      ;;
    *) : ;;
  esac
  return 0
}
