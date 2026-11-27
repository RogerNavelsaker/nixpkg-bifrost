# Bifrost OCI image

Nix-built OCI image for upstream Bifrost 2.7.0, pinned to commit `a05ea20e68bf116a35e9f05b1a3d749624b3935e`. The flake targets `x86_64-linux` and builds the binary and enterprise UI from source; it does not use an upstream container image.
The upstream tag commit is pinned and built unpatched; `scripts/sync-bifrost.sh` bumps it and recomputes `npmDepsHash`/`vendorHash`. Go 1.27.4 comes from an overlay until nixpkgs ships it.

## Build and load

```sh
IMAGE_TAR="$(nix build .#image --no-link --print-out-paths)"
podman load -i "$IMAGE_TAR"
```

The loaded image is `localhost/bifrost:v2.7.0`.

The published image is available from GHCR:

```sh
podman pull ghcr.io/rogernavelsaker/bifrost:v2.7.0
```

## Run an isolated evaluation instance

```sh
podman run --rm --name bifrost-eval \
  --publish 127.0.0.1:8080:8080 \
  --volume bifrost-eval-data:/data \
  localhost/bifrost:v2.7.0
```

Open `http://127.0.0.1:8080/`; the health endpoint is `/health`. The image runs as UID/GID `10001:10001`, uses `/data` for persistent state, and listens on port 8080. Keep the host port bound to loopback for evaluation and provide provider credentials only through Bifrost's runtime configuration when you intentionally test inference.

On a fresh data directory, Bifrost synchronously loads its pricing and model-parameter datasheets from `getbifrost.ai`; allow outbound access to that service or configure local `file://` datasheet URLs. The image contains no provider credentials and this package does not make inference requests.

## Smoke test

After loading the image, run:

```sh
tests/smoke.sh localhost/bifrost:v2.7.0
```

The smoke test seeds a disposable data directory with the small upstream datasheet examples in `tests/fixtures`, disables MCP library syncing, and uses an internal Podman network. It binds the published port only to loopback and checks the non-root UID, `/health`, and dashboard HTML without contacting a model provider or requiring outbound network access.

The image includes the upstream Apache-2.0 license and third-party notices at `/usr/share/licenses/bifrost/`.
