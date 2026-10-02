# Vela 0.9.4 — distribution source and licenses

The release contains Vela/Swiftfin application code, Swift packages, static
libVLC and the GPL-enabled libmpv framework. The combined executable distribution
is provided under **GPL-3.0-or-later**; MPL-2.0 notices continue to apply to the
Vela/Swiftfin source files. This uses MPL-2.0 section 3.3's secondary-license
permission for the combined work. MIT/BSD/Apache/LGPL and other component
notices remain in force. No warranty is provided.

- [Vela 0.9.4 source](https://github.com/ralleur/Vela/tree/vela-0.9.4)
- [Vela source archive](https://github.com/ralleur/Vela/archive/refs/tags/vela-0.9.4.tar.gz)
- [Release downloads, including the source bundle](https://github.com/ralleur/Vela/releases/tag/vela-0.9.4)
- [MPL-2.0](../../LICENSE.md), [GPL-3.0](licenses/GPL-3.0.txt),
  [GPL-2.0](licenses/GPL-2.0.txt), [LGPL-3.0](licenses/LGPL-3.0.txt),
  [LGPL-2.1](licenses/LGPL-2.1.txt)
- [Bundled source-package copyright/license notices](../../Shared/Resources/VelaThirdPartyNotices.txt)

## Matching engine inputs

| Binary input | Exact source and modifications |
| --- | --- |
| SwiftVLC 1.0.0 | [192393a45cdcd7ebb6befac26586360b8b1676b3](https://github.com/harflabs/SwiftVLC/tree/192393a45cdcd7ebb6befac26586360b8b1676b3); MIT wrapper, libVLC build script and six native patches under `Scripts/patches` |
| libVLC | VLC commit `c833c4be0`, as pinned by the SwiftVLC build script; LGPL-2.1-or-later library and separately licensed plugins/contrib inputs. Build with that script and its patches, not an arbitrary current VLC tree. |
| MPVUI 0.1.1 | [794ef73e5fb0fa356a4b488ab98d3cd43903b521](https://github.com/LePips/MPVUI/tree/794ef73e5fb0fa356a4b488ab98d3cd43903b521); MIT wrapper; GPL-enabled native artifact |
| mpv 0.41.0 | [41f6a645068483470267271e1d09966ca3b9f413](https://github.com/mpv-player/mpv/tree/41f6a645068483470267271e1d09966ca3b9f413), with the eight patches in MPVUI `Build/Patches/mpv` |
| FFmpeg 8.1.2 inside libmpv | [38b88335f99e76ed89ff3c93f877fdefce736c13](https://github.com/FFmpeg/FFmpeg/tree/38b88335f99e76ed89ff3c93f877fdefce736c13), with MPVUI's Metal pixel-buffer patch |
| Native recipe foundation | [MPVKit 288527dffbc6d3e63cce147fc7b520c64a791603](https://github.com/mpvkit/MPVKit/tree/288527dffbc6d3e63cce147fc7b520c64a791603) |

[MPVUI-Inputs.lock.json](MPVUI-Inputs.lock.json) identifies every prebuilt native
SDK input, original download, digest and builder release. The associated
component-builder repositories are pinned to resolved commits in
[source-index.json](source-index.json), alongside the Swift package and core
engine sources. Builder recipes contain their upstream source versions/URLs,
patches and configuration. VLC's pinned tree includes its contrib source
recipes, checksums and patches. These are source pointers, not claims that all
component version numbers equal the SDK release number.

[MPVUI-Artifacts.lock.json](MPVUI-Artifacts.lock.json) records the original
`Libmpv.xcframework.zip` SHA-256; [binary provenance](MPVUI-binary-provenance.json)
records combined component hashes. The original SwiftVLC artifact SHA-256 is
`23509b945aafb97634d2e66af24a377d7bd50b672aba8f5dec1d6f9ef8614045`.
The original MPVUI artifact SHA-256 is
`2cac3b64db0e2c88ba38f444389d1496387637424370c487d8b2a45618649289`.

## Source delivery and rebuilding

The source bundle offered beside the DMG contains the exact Vela release tree,
pinned Swift-package sources, mpv/FFmpeg/VLC sources, component build recipes,
patches and this index. Source archives in the index are free to download from
the immutable upstream URLs as well. Platform SDKs and system libraries come
from Apple/Xcode. Upstream component source downloads referenced by the recipes
are not all duplicated in the bundle; the recipes identify their exact inputs.

Run `Tools/vela/prepare-mac-packages.sh` to apply Vela's Catalyst packaging fixes.
These change BlurHashKit's image-platform handling and the mpv framework's
versioned directory layout; the script is part of the Vela source archive.
Use [BUILDING.md](../BUILDING.md) to compile the application. To modify/relink an
engine, build its pinned source using its recorded upstream recipe and replace
the corresponding local package artifact before rebuilding Vela. You can sign
your modified app with your own Apple development team; the release signing
key is not needed to compile or modify it. Vela adds no DRM or restriction on
modifying these libraries.

The release was compiled with Xcode 27.0 on macOS, with arm64 and x86_64 slices.
Developer ID signing was supplied by Xcode's authenticated automatic export;
the resulting direct-distribution profile permits all devices. Apple accepted
the notarization, and the exported app has a stapled ticket. `codesign --verify
--deep --strict`, `stapler validate`, and Gatekeeper assessment passed.

## Release tooling

`collect-release-sources.py` fetches source data without executing upstream code.
`archive-built-mac.py` wraps a verified Release build for Xcode distribution;
this avoids an Xcode 27 archive-action collision between Catalyst and host Swift
macro dependencies. `package-dmg.py` verifies the signed/notarized universal app,
preserves its signature, adds the Applications link/notices, creates a compressed
DMG and writes its SHA-256. It does not replace an installed app.
