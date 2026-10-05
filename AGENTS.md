# docker-beeper

Beeper Desktop (v4, Linux AppImage) in a LinuxServer.io selkies container, streamed to a browser, so its Desktop API and MCP server (`127.0.0.1:23373`, MCP at `/v0/mcp`) run around the clock. Fork of `zachatrocity/docker-beeper` (remote `upstream`); images publish to `ghcr.io/llttlltt/docker-beeper:<beeper-version>` and `:latest`.

## Layout

- `Dockerfile`: system packages in one layer, Beeper in its own layer after `ARG BEEPER_VERSION`, so a Beeper update reuses every other layer. Keep `ARG` and `ENV` lines below the package layer; anything above it invalidates that layer's cache.
- `root/`: copied over the base image. s6 services live in `root/etc/s6-overlay/s6-rc.d/`; a service runs only when listed in `user/contents.d/`, and its order comes from `dependencies.d/`.
- `root/usr/bin/`: the image-owned scripts (`beeper-session`, `beeper-watchdog`, `stream-on-demand`). `root/defaults/autostart` is copied into `/config` only on first boot, so it stays a one-line `exec` and behaviour changes go in the scripts.

## Invariants

- **Fail closed**: the web desktop always requires a login (`init-beeper-auth`). The password is hashed with SHA-512 crypt; a plaintext `/config/auth/password` is deleted in the same start. Never generate a password, and keep `/config/auth` root-only.
- **Network-agnostic**: authentication works without any particular VPN or proxy; users may run this on a plain LAN.
- **Hardened by default**: no sudo or terminals, same-origin stream only, no file transfer or remote commands. `xdg-open` stays enabled because Beeper opens sign-in and approval links in Chromium.
- **Language-neutral**: keep Chromium's and Beeper's translations; size cuts must not assume an English user.

## Build and test

- CI (`.github/workflows/docker-build.yml`) builds amd64 on push to `main`, on manual dispatch, and weekly; the weekly run skips a Beeper version that is already published. Pushes that only touch files outside the image (Markdown, `LICENSE`, `compose.yml`, editor and git config) skip the build; extend that `paths-ignore` list when adding such files.
- Local builds on Apple silicon produce arm64 natively: `docker build -t docker-beeper:test .` (add `--build-arg BEEPER_VERSION=x.y.z` to pin). Beeper keeps only a few old builds; 4.2.269 still downloads for update tests.
- Test containers on Docker Desktop: use named volumes for `/config`. A bind-mounted folder that was deleted and recreated leaves Docker Desktop with a stale handle, and init fails with "No such file or directory".
- Verify behaviour end to end, not just the build: login (401 without, 200 with, 429 after repeated failures), streaming on demand (`s6-svstat -o up /run/service/svc-selkies`), watchdog restarts (`docker logs` lines tagged `[beeper-watchdog]`), and the health check (`docker inspect -f '{{.State.Health.Status}}'`).

## Gotchas

- Chromium needs an Arial-compatible font (`fonts-liberation2`); without it, pages using system font stacks draw spaces and digits with the emoji font.
- nginx `return` runs before `limit_req`, so the failed-login location answers with `try_files … =401` to keep rate limiting effective.
- Pulls from ghcr.io are limited per connection (as low as 2.5 MB/s observed) while Docker Hub's CloudFront served the same size of layer at about 50 MB/s, and Docker downloads each layer as a single stream.

## Next

- **Publish to Docker Hub as well**: push every build to both registries so users pull from CloudFront. Needs a Docker Hub account and an access token stored as a repository secret; the token stays out of the repo and out of chat.
