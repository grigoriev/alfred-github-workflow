#!/bin/bash

# The GitHub organizations whose repositories the workflow offers. Edit the list
# with "gh > orgs". It is stored one org per line in "$alfred_workflow_data/orgs".

# Path to the organizations list.
orgs_file() {
  printf '%s/orgs' "${alfred_workflow_data:-.}"
  return 0
}

# Print the configured orgs, one per line, skipping blank and comment lines.
configured_orgs() {
  local file
  file="$(orgs_file)"
  if [[ -f "$file" ]]; then
    grep -vE '^[[:space:]]*(#.*)?$' "$file" || true
  fi
  return 0
}
