# Format the GitHub commits API response as Alfred items, filtered by a sha
# prefix or a message substring. Shows the short sha and the first line.
# --arg q filter, --arg repo "owner/repo", --arg icon icon path.
def subject: (.commit.message | split("\n")[0]);
def matches($q): $q == ""
  or (.sha | startswith($q))
  or (subject | ascii_downcase | contains($q | ascii_downcase));
[ .[] | select(matches($q))
  | { title: ("\(.sha[0:7]) \(subject)"),
      subtitle: "Commit",
      arg: ("open https://github.com/\($repo)/commit/\(.sha)"),
      autocomplete: ("\($repo) *\(.sha[0:7])"),
      valid: true,
      icon: { path: $icon } } ]
