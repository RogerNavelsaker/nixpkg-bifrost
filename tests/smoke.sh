#!/usr/bin/env bash
set -euo pipefail

image=bifrost:v2.3.2
if [[ $# -gt 0 ]]; then image=$1; fi
name="bifrost-smoke-$$"
network="$name-net"
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
command -v podman >/dev/null
command -v curl >/dev/null
podman image exists "$image" || { echo "Image not found locally: $image" >&2; exit 2; }
fixture_dir="$(mktemp -d)"

cleanup() {
  podman rm --force "$name" >/dev/null 2>&1 || true
  podman network rm "$network" >/dev/null 2>&1 || true
  rm -rf "$fixture_dir"
}
trap cleanup EXIT
cp "$script_dir/fixtures/config.json" "$script_dir/fixtures/pricing.json" "$script_dir/fixtures/model-parameters.json" "$fixture_dir/"

podman network create --internal "$network" >/dev/null
podman run --detach \
  --name "$name" \
  --network "$network" \
  --userns=keep-id:uid=10001,gid=10001 \
  --publish 127.0.0.1::8080 \
  --volume "$fixture_dir:/data" \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=64m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  "$image" >/dev/null

test "$(podman inspect --format '{{.Config.User}}' "$name")" = "10001:10001"
port="$(podman port "$name" 8080/tcp | sed 's/.*://')"
test -n "$port"
ready=0
for ((attempt = 0; attempt < 60; attempt++)); do
  if curl --fail --silent --max-time 2 "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if [[ "$(podman inspect --format '{{.State.Status}}' "$name" 2>/dev/null || true)" != running ]]; then
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "Bifrost did not become healthy" >&2
  podman logs "$name" 2>&1 | tail -40 >&2 || true
  exit 1
fi
dashboard_type="$(curl --fail --silent --show-error --max-time 5 -o /dev/null -w '%{content_type}' \
  "http://127.0.0.1:$port/")"
[[ "$dashboard_type" == text/html* ]]

printf 'Bifrost smoke test passed: %s, non-root UID, offline /health, dashboard HTML\n' "$image"
