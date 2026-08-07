#!/bin/bash

# Global commands behind "gh >": auth, cache and database maintenance, updates.

. src/media.sh
. src/cache.sh

# Lowercase a string.
gh_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
  return 0
}

# The autoupdate flag lives as a file in the data dir.
autoupdate_flag() {
  printf '%s/autoupdate' "${alfred_workflow_data:-.}"
  return 0
}

autoupdate_enabled() {
  [[ -f "$(autoupdate_flag)" ]]
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
  global_item "update"          "$filter" "Check for updates" "Check for a new version"          ""                "no"  "$ICON_UPDATE" "> update"
  global_item "delete cache"    "$filter" "Delete cache"      "Drop cached API responses"        "delete cache"    "yes" "$ICON_TRASH"  ""
  global_item "delete database" "$filter" "Delete database"   "Rebuild the repository list"      "delete database" "yes" "$ICON_TRASH"  ""
  if autoupdate_enabled; then
    global_item "deactivate autoupdate" "$filter" "Deactivate autoupdate" "Stop checking automatically" "autoupdate off" "yes" "$ICON_UPDATE" ""
  else
    global_item "activate autoupdate"   "$filter" "Activate autoupdate"   "Check automatically"         "autoupdate on"  "yes" "$ICON_UPDATE" ""
  fi
  get_json_results
  return 0
}

# Open a terminal running a gh auth command. $1 = login | logout.
run_auth() {
  osascript - "gh auth $1" <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    activate
    do script (item 1 of argv)
  end tell
end run
APPLESCRIPT
  return 0
}

# Delete the cache or the database. $1 = cache | database.
run_delete() {
  case "$1" in
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

# Toggle autoupdate. $1 = on | off.
set_autoupdate() {
  case "$1" in
    on)
      mkdir -p "${alfred_workflow_data:-.}"
      : > "$(autoupdate_flag)"
      ;;
    off)
      rm -f "$(autoupdate_flag)"
      ;;
    *) : ;;
  esac
  return 0
}
