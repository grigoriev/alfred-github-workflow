#!/bin/bash

# Regenerate the PNG icons from Octicons (https://github.com/primer/octicons,
# MIT). macOS only: rasterizes with the built-in qlmanage. Run via `make icons`.
# The PNGs are committed, so neither the build nor CI needs a rasterizer.

color="#8b949e"
base="https://raw.githubusercontent.com/primer/octicons/main/icons"
tmp="$(mktemp -d)"
mkdir -p icons

# Rasterize one octicon into a colored PNG.
# $1 output path  $2 octicon name  $3 pixel size
render() {
  local out="$1" octicon="$2" size="$3"
  if ! curl -sfL "$base/$octicon.svg" -o "$tmp/in.svg"; then
    echo "  MISSING $octicon"
    return 0
  fi
  sed -E 's/<svg /<svg fill="'"$color"'" /' "$tmp/in.svg" > "$tmp/c.svg"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$size" -h "$size" "$tmp/c.svg" -o "$out"
  else
    qlmanage -t -s "$size" -o "$tmp" "$tmp/c.svg" >/dev/null 2>&1
    cp "$tmp/c.svg.png" "$out"
  fi
  echo "  $out"
  return 0
}

icons="org:organization-24 repo:repo-24 issue:issue-opened-24 \
pull:git-pull-request-24 branch:git-branch-24 commit:git-commit-24 \
actions:workflow-24 admin:gear-24 clone:download-24 \
discussion:comment-discussion-24 milestone:milestone-24 release:tag-24 \
update:sync-24 login:sign-in-24 logout:sign-out-24 trash:trash-24"

echo "generating item icons..."
for pair in $icons; do
  render "icons/${pair%%:*}.png" "${pair#*:}" 256
done

echo "generating workflow icon..."
render icon.png mark-github-24 512

rm -rf "$tmp"
echo "done"
