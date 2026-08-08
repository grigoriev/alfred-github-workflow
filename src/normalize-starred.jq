# Normalize the GitHub starred API response into the compact database record.
map({
  owner: .owner.login,
  name: .name,
  nameWithOwner: .full_name,
  description: (.description // ""),
  isPrivate: .private,
  pushedAt: .pushed_at,
  url: .html_url
})
