# Filter repositories by a case-insensitive substring of "owner/name" and format
# them as Alfred items. Repos absent from the visible list are dropped, pinned
# repos are marked with a star and sorted to the top, and each item carries a cmd
# modifier that hides it and an alt modifier that pins or unpins it.
# --arg q the query, --arg icon the icon path, --argjson visible a list of visible
# "owner/name" strings or null for all, --argjson pinned a list of pinned strings,
# --argjson hideable true to add the cmd hide modifier.
# Match owner and repo name separately, so "owner/pdf" finds a repo whose name
# contains "pdf" anywhere, not only names that start with it.
def matches($q):
  $q == ""
  or (($q | ascii_downcase) as $lq
      | if ($lq | contains("/"))
        then (($lq | split("/")) as $p
              | (.owner | ascii_downcase | contains($p[0]))
                and (.name | ascii_downcase | contains($p[1:] | join("/"))))
        else (.nameWithOwner | ascii_downcase | contains($lq))
        end);
[ .[]
  | select($visible == null or (.nameWithOwner as $n | ($visible | index($n)) != null))
  | select(matches($q)) ]
| sort_by(.pushedAt) | reverse
| map(. + { _pinned: (.nameWithOwner as $n | ($pinned | index($n)) != null) })
| (map(select(._pinned)) + map(select(._pinned | not)))
| map({
    title: (if ._pinned then "★ " + .nameWithOwner else .nameWithOwner end),
    subtitle: (if .description == "" then .url else .description end),
    autocomplete: (.nameWithOwner + " "),
    valid: false,
    icon: { path: $icon },
    mods: (
      (if $hideable
       then { cmd: { valid: true, arg: ("hide " + .nameWithOwner), subtitle: "Hide this repository" } }
       else {} end)
      + { alt: (if ._pinned
                then { valid: true, arg: ("unpin " + .nameWithOwner), subtitle: "Unpin from the top" }
                else { valid: true, arg: ("pin " + .nameWithOwner), subtitle: "Pin to the top" }
                end) }
    )
  })
