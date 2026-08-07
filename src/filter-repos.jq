# Filter repositories by a case-insensitive substring of "owner/name" and format
# them as Alfred items. Hidden repos are dropped, pinned repos are marked with a
# star and sorted to the top, and each item carries a cmd modifier that hides it
# and an alt modifier that pins or unpins it.
# --arg q the query, --arg icon the icon path, --argjson hidden a list of hidden
# "owner/name" strings, --argjson pinned a list of pinned "owner/name" strings.
def matches($q): $q == "" or
  (.nameWithOwner | ascii_downcase | contains($q | ascii_downcase));
[ .[]
  | select(.nameWithOwner as $n | ($hidden | index($n)) == null)
  | select(matches($q)) ]
| sort_by(.pushedAt) | reverse
| map(. + { _pinned: (.nameWithOwner as $n | ($pinned | index($n)) != null) })
| (map(select(._pinned)) + map(select(._pinned | not)))
| map({
    title: (if ._pinned then "★ " + .nameWithOwner else .nameWithOwner end),
    subtitle: (if .description == "" then .url else .description end),
    arg: ("open https://github.com/" + .nameWithOwner),
    autocomplete: (.nameWithOwner + " "),
    valid: true,
    icon: { path: $icon },
    mods: {
      cmd: { valid: true, arg: ("hide " + .nameWithOwner),
             subtitle: "Hide this repository" },
      alt: (if ._pinned
            then { valid: true, arg: ("unpin " + .nameWithOwner), subtitle: "Unpin from the top" }
            else { valid: true, arg: ("pin " + .nameWithOwner), subtitle: "Pin to the top" }
            end)
    }
  })
