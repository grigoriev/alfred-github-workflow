# Filter repositories by a case-insensitive substring of "owner/name" and format
# them as Alfred items, most recently pushed first.
# --arg q the query, --arg icon the icon path.
def matches($q): $q == "" or
  (.nameWithOwner | ascii_downcase | contains($q | ascii_downcase));
[ .[] | select(matches($q)) ]
| sort_by(.pushedAt) | reverse
| map({
    title: .nameWithOwner,
    subtitle: (if .description == "" then .url else .description end),
    arg: ("open https://github.com/" + .nameWithOwner),
    autocomplete: (.nameWithOwner + " "),
    valid: true,
    icon: { path: $icon }
  })
