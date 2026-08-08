#!/bin/bash

# Regenerate the PNG icons from Octicons (https://github.com/primer/octicons,
# MIT). macOS only: rasterizes with rsvg-convert (brew install librsvg), falling
# back to qlmanage. Run via `make icons`. The PNGs are committed, so neither the
# build nor CI needs a rasterizer.
#
# Icons are colored by category with the GitHub (Primer) palette: green for
# progress, blue for actions, purple for pull requests, red for destructive,
# neutral gray otherwise.

base="https://raw.githubusercontent.com/primer/octicons/main/icons"
tmp="$(mktemp -d)"
mkdir -p icons

GREEN="#3fb950"
BLUE="#58a6ff"
PURPLE="#a371f7"
RED="#f85149"
GRAY="#8b949e"
GOLD="#e3b341"

# Rasterize one octicon into a colored PNG.
# $1 output path  $2 octicon name  $3 pixel size  $4 fill color
render() {
  local out="$1" octicon="$2" size="$3" color="$4"
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

# name:octicon:color
icons="org:organization-24:$GRAY repo:repo-24:$GRAY \
issue:issue-opened-24:$GREEN pull:git-pull-request-24:$PURPLE \
branch:git-branch-24:$GRAY commit:git-commit-24:$GRAY \
actions:workflow-24:$BLUE admin:gear-24:$GRAY clone:download-24:$BLUE \
discussion:comment-discussion-24:$BLUE milestone:milestone-24:$GREEN \
release:tag-24:$GREEN update:sync-24:$BLUE login:sign-in-24:$GREEN \
logout:sign-out-24:$GRAY trash:trash-24:$RED star:star-fill-24:$GOLD \
user:person-24:$GRAY all:search-24:$GRAY"

echo "generating item icons..."
for entry in $icons; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  render "icons/$name.png" "${rest%%:*}" 256 "${rest#*:}"
done

echo "generating workflow icon..."
render icon.png mark-github-24 512 "$GRAY"

rm -rf "$tmp"
echo "done"
