# Changelog

## v2.7.0 - 2026-11-27

### Changed
- Bump to upstream Bifrost 2.7.0 (d979e72); recomputed `npmDepsHash` and `vendorHash`; UI build gets a larger Node heap.
- Build with Go 1.27.4 via nixpkgs overlay (upstream requirement).
- Drop `patches/`: upstream 2.7.0 already carries the dependency updates (transport Go deps, DOMPurify, follow-redirects, Vitest, Zod). Vite is upstream's 8.1.6.
- `.nixpkg-sync.json` now `git-tag` against maximhq/bifrost with `scripts/sync-bifrost.sh` for the central sync.

## v2.3.2 - 2026-10-28

### Added
- Nix-built OCI image for upstream Bifrost 2.3.2, with a non-root runtime and persistent /data volume.
- Offline Podman smoke test using local datasheet fixtures.

### Security
- Updated UI dependency pins: DOMPurify 3.4.17, follow-redirects 1.16.2, Vite 8.3.5, Vitest 4.1.12, and Zod 4.6.7.
- Updated Go transport module pins, including golang.org/x/net to 0.62.0 for HTTP/2 and HTML parser fixes.
