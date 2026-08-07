# Normalize the gh repo list into the compact database record.
map({
  owner: .owner.login,
  name: .name,
  nameWithOwner: .nameWithOwner,
  description: (.description // ""),
  isPrivate: .isPrivate,
  pushedAt: .pushedAt,
  url: .url
})
