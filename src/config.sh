#!/bin/bash

# The GitHub organizations whose repositories the workflow offers.
# Override by writing one org per line to "$alfred_workflow_data/orgs".
DEFAULT_ORGS="grigoriev intechcore SchweizerischeBundesbahnen"

# Print the configured orgs, one per line.
configured_orgs() {
  local orgs_file org
  orgs_file="${alfred_workflow_data:-.}/orgs"
  if [[ -f "$orgs_file" ]]; then
    grep -vE '^[[:space:]]*$' "$orgs_file"
  else
    for org in $DEFAULT_ORGS; do
      printf '%s\n' "$org"
    done
  fi
  return 0
}
