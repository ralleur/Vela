# kurtz Connect transport experiment

This is a disposable research harness, **not a kurtz feature or deployable VPN/helper**. Read the [decision document](../../docs/kurtz-connect-feasibility.md) first. Production app targets, entitlements and playback files are unchanged.

The native macOS Swift process embeds `tailscale.com/tsnet` **v1.102.5** in a Go C archive. It exposes a loopback HTTP origin with a random per-process capability and one fixed upstream. A separate local Go process provides an automatically approving test controller, local STUN/DERP and a second tsnet node that forwards to a newly created Jellyfin container. Native `URLSession` and `AVPlayer` access the bridge with ordinary URLs.

```text
Native Swift → in-process local bridge → embedded tsnet
    → direct encrypted peer path OR local DERP ciphertext relay
    → separate tsnet helper → disposable real Jellyfin 10.11.11
```

The unencrypted baseline uses loopback on the same Mac. It is **not a physical LAN benchmark**. Direct and DERP tests also run on the same Mac; they prove the code paths, not Internet NAT traversal, hosted DERP speed, or Apple TV performance.

## Reproduce

Requirements: Apple silicon Mac with Xcode/Swift, Go **1.26.6 or later** (tested with 1.27.1), Docker CLI with a running engine and FFmpeg with libx264. The test uses a locally installed `jellyfin/jellyfin:10.11.11` image. To install it explicitly if needed:

```sh
docker pull jellyfin/jellyfin:10.11.11
```

From this directory:

```sh
bash build.sh
go test ./internal/gateway
go vet ./cmd/bridge ./cmd/lab ./internal/gateway
python3 run-lab.py
```

The runner creates a unique Docker network/container and private temporary directories. The Jellyfin port is published **only to 127.0.0.1**. It generates a six-second H.264 sample, initializes a throwaway admin account with a random password, disables automatic port mapping and indexes one movie. It never uses an existing Jellyfin, Tailscale profile or account. The Docker network is a separate bridge with normal outbound connectivity; it is not a firewall guarantee. Metadata fetchers for the sample library are disabled.

The harness clears inherited `TS_*` variables, disables Tailscale remote logs and automatic port mapping, and sets `TS_DEBUG_ALWAYS_USE_DERP=true` only for the forced-relay run. No `tailscale up`, OS VPN, route installation, provisioning profile or user Keychain change occurs. Test nodes use temporary filesystem state, **not a production Keychain implementation**.

On ordinary success/failure, `finally` removes only its uniquely named container/network and temporary credentials/state. A host crash or SIGKILL can interrupt cleanup; inspect resources labeled `kurtz-connect-poc=true` before removing any such leftovers. The pinned image, Go dependency cache and ignored build outputs remain. Sanitized results are written to `runs/results.json`; tracked measurements are in [evidence/results.json](evidence/results.json).

## What each successful native run asserts

- A genuine Jellyfin `/System/Info/Public` response with the disposable server's expected ID.
- Successful Jellyfin username/password authentication and a nonempty movie library.
- HTTP 206 with the requested 1,024-byte range from the real movie stream.
- Native URLSession WebSocket echo through the bridge (a fixture, **not** Jellyfin's session protocol).
- Three uncached 32-MiB synthetic transfers with monotonic elapsed time. The app buffers each response; this is not a realistic streaming-memory benchmark.
- Muted native AVPlayer starts the real Jellyfin MP4 and advances beyond half a second. No claim of a long playback, HLS, VLC or mpv test.
- For overlay runs, a DISCO ping reports the requested direct or DERP route before and after transfers; peer byte counters also increase. `Relay` text alone is never treated as evidence. These snapshots do not rule out transient route changes in the unforced direct run.
- Missing capability, foreign browser Origin and off-origin redirects are rejected. Unit tests additionally exercise foreign Host, arbitrary absolute-form target, CONNECT and forwarding-header rejection.

If the direct path cannot be established, the direct test fails rather than relabeling a relay result. The forced-relay setting disables direct UDP in that test process; it does not modify system firewall rules or send load to Tailscale's hosted relays.

## Cross-platform compilation

```sh
bash cross-build.sh tvos
bash cross-build.sh catalyst
```

These compile a Go archive and link a tiny Swift **dynamic-library anchor**, then print its `LC_BUILD_VERSION`. They do not create an app, sign it, run in a simulator, install on a TV or validate App Store acceptance. A native macOS binary is not a Catalyst binary; separate target metadata is verified.

The same `GOOS=ios/GOARCH=arm64` is used for both experiments, with distinct cgo target flags. Those flags must be part of Go's build-cache identity: changing an environment variable read only by a compiler wrapper can accidentally reuse objects from the other Apple platform. Do not fix this by rewriting Mach-O headers. The complete media Swift probe is tested on native macOS only. Intel Catalyst and iOS runtime are outstanding.

## Deliberate boundaries

The local control server auto-enrolls nodes and has permissive test policy. Its HTTP control URL and DERP self-signed-certificate exception are **loopback-only test mechanisms**. Never deploy `cmd/lab` publicly or reuse it for pairing. There is no production device approval, grants test, cryptographic server pin, Keychain state store, device revocation or account recovery in this harness.

The bridge only accepts a loopback test control URL and a `100.64.0.0/10` test peer. It has no API for arbitrary destinations. These guards reduce accidental misuse; they do not make it production hardened. It rejects all redirects and browser Origins, does not rewrite HLS/HTML/absolute URLs, does not establish correct Jellyfin remote/local proxy semantics, and does not implement per-device helper authorization or seamless route migration. Existing WebSocket connections need explicit lifecycle tracking for production shutdown/revocation. Per-engine loopback security and app background behavior still need real-device testing.

For production, an HTTPS/pinned helper, deny-by-default network and helper policy, verified forwarding metadata/Jellyfin KnownProxies, authenticated LAN identity and media URL coverage are requirements. Do not expose the generic tsnet LocalAPI or SOCKS proxy to media engines or other apps.

## Source and license evidence

New harness source is MPL-2.0 under the repository [license](../../LICENSE.md). No Go dependencies or binaries are vendored into the production project. `go.mod`/`go.sum` pin the research dependency graph.

[third-party-licenses.csv](evidence/third-party-licenses.csv) records upstream license URLs and detections from `google/go-licenses/v2 v2.0.1` for the **darwin/arm64 bridge**, with [hashes of 34 collected upstream license files](evidence/license-hashes.json). Multiple rows for one license file reflect mixed notices (not a demand to choose one license). The repository's own MPL files were identified manually because the tool does not search outside this module for the parent license.

Recreate the reports:

```sh
go run github.com/google/go-licenses/v2@v2.0.1 report ./cmd/bridge > build/licenses.csv
go run github.com/google/go-licenses/v2@v2.0.1 save ./cmd/bridge \
  --save_path=build/notices --ignore=kurtz.local/connect-poc
go list -deps -json ./cmd/bridge > build/dependencies.json
```

The scanner warns about C/assembly and does not establish licenses for embedded JavaScript or every external tool. Go runtime notices, Apple framework/developer terms, the separate test-lab dependency graph, Docker Jellyfin/FFmpeg and each eventual release target need their own inventory. The saved report is evidence of the inspected packages, **not legal clearance for an App Store binary**. The current kurtz release's GPL-enabled native players are a separate existing concern documented in the decision.

## Rebrand provenance

This isolated feasibility probe now uses kurtz paths/module names. The evidence
files preserve the original Vela experiment and do not claim it is a released
kurtz feature. This probe is not linked into the shipping app.
