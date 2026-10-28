# Changelog

## v2.3.2 - 2026-10-28

### Added
- Nix-built OCI image for upstream Bifrost 2.3.2, with a non-root runtime and persistent /data volume.
- Offline Podman smoke test using local datasheet fixtures.

### Security
- Updated UI dependency pins: DOMPurify 3.4.17, follow-redirects 1.16.2, Vite 8.3.5, Vitest 4.1.12, and Zod 4.6.7.
- Updated Go transport module pins, including golang.org/x/net to 0.62.0 for HTTP/2 and HTML parser fixes.
