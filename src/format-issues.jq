# Format the GitHub issues API response (issues and pull requests) as Alfred
# items, filtered by a number prefix or a title substring.
# --arg q filter, --arg repo "owner/repo", --arg icon icon path.
def matches($q): $q == ""
  or ((.number | tostring) | startswith($q))
  or (.title | ascii_downcase | contains($q | ascii_downcase));
[ .[] | select(matches($q))
  | { title: ("#\(.number) \(.title)"),
      subtitle: (if .pull_request then "Pull request" else "Issue" end),
      arg: ("open https://github.com/\($repo)/issues/\(.number)"),
      autocomplete: ("\($repo) #\(.number)"),
      valid: true,
      icon: { path: $icon } } ]
