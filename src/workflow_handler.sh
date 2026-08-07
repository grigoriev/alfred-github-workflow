#!/bin/bash

RESULTS=()
RERUN=""
VARIABLES=()

###############################################################################
# Ask Alfred to re-run the script filter after N seconds (0.1 - 5.0)
#
# $1 delay in seconds
###############################################################################
set_rerun() {
  local delay="$1"
  RERUN="$delay"
  return 0
}

###############################################################################
# Set an Alfred variable, passed back to the script on the next run
#
# $1 key
# $2 value
###############################################################################
add_variable() {
  local key="$1" value="$2"
  VARIABLES+=("$key"$'\t'"$value")
  return 0
}

###############################################################################
# Adds a result to the result array
#
# $1 uid
# $2 arg
# $3 title
# $4 subtitle
# $5 icon
# $6 valid (pass "no" for a non-actionable item; anything else is valid)
# $7 autocomplete
# $8 cmd modifier subtitle (optional, shown when ⌘ is held)
# $9 cmd modifier arg (optional; the arg used when ⌘⏎ selects the item)
###############################################################################
add_result() {
  local uid="$1" arg="$2" title="$3" subtitle="$4" icon="$5" valid="$6" \
    autocomplete="$7" mod_subtitle="$8" mod_arg="$9"

  # Router subcommands set ARG_PREFIX so a selected item's arg routes back
  # through the keyword (e.g. "Off" becomes "wifi Off").
  if [[ -n "$ARG_PREFIX" ]] && [[ -n "$arg" ]]; then
    arg="$ARG_PREFIX$arg"
  fi

  # A ⌘ modifier routes its own arg the same way as the item arg.
  if [[ -n "$ARG_PREFIX" ]] && [[ -n "$mod_arg" ]]; then
    mod_arg="$ARG_PREFIX$mod_arg"
  fi

  local item="{"
  if [[ -n "$uid" ]]; then
    item+="\"uid\":\"$(json_encode "$uid")\","
  fi
  item+="\"title\":\"$(json_encode "$title")\","
  item+="\"subtitle\":\"$(json_encode "$subtitle")\","
  item+="\"arg\":\"$(json_encode "$arg")\","
  item+="\"icon\":{\"path\":\"$(json_encode "$icon")\"},"
  if [[ "$valid" == "no" ]]; then
    item+="\"valid\":false,"
  else
    item+="\"valid\":true,"
  fi
  if [[ -n "$autocomplete" ]]; then
    item+="\"autocomplete\":\"$(json_encode "$autocomplete")\","
  fi
  if [[ -n "$mod_arg" ]]; then
    item+="\"mods\":{\"cmd\":{\"valid\":true,\"arg\":\"$(json_encode "$mod_arg")\",\"subtitle\":\"$(json_encode "$mod_subtitle")\"}},"
  fi
  item="${item%,}}"
  RESULTS+=("$item")
  return 0
}

###############################################################################
# Prints the feedback json to stdout (Alfred Script Filter format)
###############################################################################
get_json_results() {
  local out="{"

  if [[ -n "$RERUN" ]]; then
    out+="\"rerun\":$RERUN,"
  fi

  if [[ "${#VARIABLES[@]}" -gt 0 ]]; then
    out+="\"variables\":{"
    local index=0 pair key value
    for pair in "${VARIABLES[@]}"; do
      key="${pair%%$'\t'*}"
      value="${pair#*$'\t'}"
      if [[ "$index" -gt 0 ]]; then
        out+=","
      fi
      out+="\"$(json_encode "$key")\":\"$(json_encode "$value")\""
      index=$((index + 1))
    done
    out+="},"
  fi

  out+="\"items\":["
  local count=0 result
  for result in "${RESULTS[@]}"; do
    if [[ "$count" -gt 0 ]]; then
      out+=","
    fi
    out+="$result"
    count=$((count + 1))
  done
  out+="]}"
  printf '%s\n' "$out"
  return 0
}

###############################################################################
# Escapes a string for embedding in a JSON string literal
###############################################################################
json_encode() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\r'/\\r}"
  printf '%s' "$text"
  return 0
}

###############################################################################
# Save key=value to the workflow properties
#
# $1 key
# $2 value
# $3 non-volatile 0/1
# $4 filename (optional, filename will be "settings" if not specified)
###############################################################################
set_pref() {
  local key="$1" value="$2" volatile="$3" filename="$4"

  local pref_dir
  if [[ "$volatile" == "0" ]]; then
    pref_dir="$alfred_workflow_data"
  else
    pref_dir="$alfred_workflow_cache"
  fi

  if [[ ! -d "$pref_dir" ]]; then
    mkdir -p "$pref_dir"
  fi

  local pref_file
  if [[ -z "$filename" ]]; then
    pref_file="$pref_dir/settings"
  else
    pref_file="$pref_dir/$filename"
  fi

  if [[ ! -f "$pref_file" ]]; then
    touch "$pref_file"
  fi

  local key_exists
  key_exists=$(grep -c "^$key=" "$pref_file" || true)
  if [[ "$key_exists" != "0" ]]; then
    local tmp
    tmp=$(grep -ve "^$key=" "$pref_file" || true)
    echo "$tmp" > "$pref_file"
  fi
  echo "$key=$value" >> "$pref_file"
  return 0
}

###############################################################################
# Read a value for a given key from the workflow preferences
#
# $1 key
# $2 non-volatile 0/1
# $3 filename (optional, filename will be "settings" if not specified)
###############################################################################
get_pref() {
  local key="$1" volatile="$2" filename="$3"

  local pref_dir
  if [[ "$volatile" == "0" ]]; then
    pref_dir="$alfred_workflow_data"
  else
    pref_dir="$alfred_workflow_cache"
  fi

  if [[ ! -d "$pref_dir" ]]; then
    return 0
  fi

  local pref_file
  if [[ -z "$filename" ]]; then
    pref_file="$pref_dir/settings"
  else
    pref_file="$pref_dir/$filename"
  fi

  if [[ ! -f "$pref_file" ]]; then
    return 0
  fi

  local value
  value=$(sed "/^#/d" "$pref_file" | grep "^$key=" | tail -n 1 | cut -d "=" -f2-)
  echo "$value"
  return 0
}
