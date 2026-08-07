# Filter repositories by a case-insensitive substring of "owner/name" and format
# them as Alfred items, most recently pushed first. Hidden repos are dropped and
# every item carries a cmd modifier that hides it.
# --arg q the query, --arg icon the icon path, --argjson hidden a list of
# hidden "owner/name" strings.
def matches($q): $q == "" or
  (.nameWithOwner | ascii_downcase | contains($q | ascii_downcase));
[ .[]
  | select(.nameWithOwner as $n | ($hidden | index($n)) == null)
  | select(matches($q)) ]
| sort_by(.pushedAt) | reverse
| map({
    title: .nameWithOwner,
    subtitle: (if .description == "" then .url else .description end),
    arg: ("open https://github.com/" + .nameWithOwner),
    autocomplete: (.nameWithOwner + " "),
    valid: true,
    icon: { path: $icon },
    mods: { cmd: { valid: true, arg: ("hide " + .nameWithOwner),
                   subtitle: "Hide this repository" } }
  })
