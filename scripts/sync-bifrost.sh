#!/usr/bin/env bash
# Bump flake.nix to the latest maximhq/bifrost transports/vX.Y.Z tag and recompute npmDepsHash/vendorHash.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
repo=https://github.com/maximhq/bifrost
tag=$(git ls-remote --tags --refs "$repo" 'transports/v*' | awk '{sub("refs/tags/","",$2);print $2}' | grep -E '^transports/v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
new=${tag#transports/v}
cur=$(grep -oE 'version = "[0-9.]+"' flake.nix | head -n1 | sed -E 's/.*"(.*)"/\1/')
[ "$new" != "$cur" ] || { echo "bifrost $cur up to date"; exit 0; }
rev=$(git ls-remote "$repo" "refs/tags/$tag^{}" | awk '{print $1}')
[ -n "$rev" ] || rev=$(git ls-remote "$repo" "refs/tags/$tag" | awk '{print $1}')
sed -i -E "s|bifrost/[0-9a-f]{40}\"|bifrost/$rev\"|; s|revision = \"[0-9a-f]{40}\"|revision = \"$rev\"|; s|version = \"$cur\"|version = \"$new\"|; s|Bifrost $cur|Bifrost $new|" flake.nix
sed -i "s|$cur|$new|g" README.md tests/smoke.sh
nix flake update bifrost-src
for attr in npmDepsHash:ui vendorHash:bifrost; do
  key=${attr%%:*}; pkg=${attr##*:}
  sed -i -E "s|$key = \"[^\"]*\"|$key = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"|" flake.nix
  got=$(nix build ".#$pkg" --no-link 2>&1 | awk '/got:/{print $2}' | head -n1)
  [ -n "$got" ] || { echo "no $key hash for $pkg" >&2; exit 1; }
  sed -i -E "s|$key = \"[^\"]*\"|$key = \"$got\"|" flake.nix
done
echo "bifrost $cur -> $new"
