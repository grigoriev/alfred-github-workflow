# Format the GitHub branches API response as Alfred items, filtered by a
# substring of the branch name.
# --arg q filter, --arg repo "owner/repo", --arg icon icon path.
def matches($q): $q == "" or (.name | ascii_downcase | contains($q | ascii_downcase));
[ .[] | select(matches($q))
  | { title: .name,
      subtitle: "Branch",
      arg: ("open https://github.com/\($repo)/tree/\(.name)"),
      autocomplete: ("\($repo) @\(.name)"),
      valid: true,
      icon: { path: $icon } } ]
