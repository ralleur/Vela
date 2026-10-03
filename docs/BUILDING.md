# Build and install Vela

Vela **0.9.5 Beta** is available as a [universal Mac DMG](https://github.com/ralleur/Vela/releases/download/vela-0.9.5/Vela-0.9.5-macOS-universal.dmg).
The app is Developer-ID signed and notarized by Apple. It supports Apple silicon
and Intel on macOS 15.6 or later. Open the DMG and drag Vela into Applications.
[Release notes and SHA-256](https://github.com/ralleur/Vela/releases/tag/vela-0.9.5)
identify the exact package. Vela is not distributed through the App Store.

The older 0.9.3 ZIP predates local playback and was development-signed rather
than notarized. Use 0.9.5 for the experience shown on the project website.

## Mac

Use macOS, Xcode and your own Apple development team. This checkout was built
with **Xcode 27.0 (27A266a)**. The generated Mac app declares **macOS 15.6** as
its minimum; testing on the oldest supported OS still needs release qualification.
Both Intel and Apple silicon are configured for Release; the launch capture
build was run on Apple silicon. Vela uses Mac Catalyst.

```sh
cp XcodeConfig/DevelopmentTeam.example.xcconfig XcodeConfig/DevelopmentTeam.xcconfig
# Set DEVELOPMENT_TEAM in your local, ignored copy.
CONFIGURATION=Debug Tools/vela/install-mac.sh
```

The Debug app stays at `build/dd-mac/Build/Products/Debug-maccatalyst/Swiftfin.app`.
The inherited target/bundle filename is a build detail; the app calls itself Vela.

```sh
Tools/vela/install-mac.sh
```

The default Release command builds, verifies signing, and **replaces
`/Applications/Vela.app`**. It refuses to replace an app with another bundle ID.
It is an installation helper, not a notarized distribution pipeline.

The helper prepares pinned Mac-compatible copies of BlurHashKit and MPVUI in
`build/mac-packages`. Open **Vela.xcworkspace**, rather than the bare Xcode
project, after preparation. A provisioning profile is needed for the app's
keychain access; an unsigned Debug build can assert on sign-in.

## Apple TV

The `Swiftfin tvOS` target is Vela's Jellyfin client on Apple TV (deployment
target tvOS 26.1). Local Finder/file features are specific to the Mac.

```sh
Tools/vela/install-device.sh "Your Apple TV name"
```

Physical-device signing and provisioning are required. The inherited iOS target
is also the basis of the Mac Catalyst build; the iPhone/iPad app is now being prepared for release, with a local Files workflow in addition to Jellyfin. It is not yet a qualified App Store release.

## Validate

```sh
swift test --package-path Tools/VelaLogicTests
Tools/LocalPlaybackFixtures/create.sh build/local-fixtures --high-bitrate
```

46 logic tests passed for 0.9.5 (35 Vela tests and 11 playback tests).
See [the product audit](product-audit.md) for what was independently exercised,
and [VELA.md](../VELA.md) for architecture, previous test evidence, Debug checks,
source adapters, sandbox behavior and the upstream update process.

## Playback and privacy

VLC is the automatic local engine; mpv is the alternative. **Try Compatible
Playback** offers one retry with the other engine. The AVPlayer adapter remains
inherited code with feature gaps and is not the local default. Codec, subtitle,
HDR and passthrough support depend on the actual engine/build/file.

Local files need no Jellyfin account. Recent files, positions and track choices
stay on the Mac and can be cleared or disabled in Settings. Local playback does
not create Jellyfin progress reports. An already connected server can continue
normal browsing/socket activity. Do not describe this as network isolation.

## Contribute and distribute

Start with [VELA.md](../VELA.md) and the inherited
[contributor guide](../Documentation/contributing.md). Send Vela changes to
[ralleur/Vela](https://github.com/ralleur/Vela), and discuss generally useful
upstream fixes with Swiftfin separately. Keep upstream notices and MPL headers.

The 0.9.5 binary uses the GPL-enabled mpv build. The
[release source record](release/README.md) identifies the corresponding native
sources, patches and build recipes. Future releases must update this record
when dependencies change. The wrapper licenses do not replace engine licenses.
[Third-party notices](../Shared/Resources/VelaThirdPartyNotices.txt) are retained
in the repository and the app. No new decoder dependency was added for marketing.

## iPhone, iPad and Apple TV release preparation

The working tree prepares **0.9.6 beta** (iOS/Mac build 7, tvOS build 73).
The public Mac download remains 0.9.5; no iOS/tvOS store release is announced.
iPhone and iPad share the Swiftfin target (minimum iOS/iPadOS 18.6). The local
player uses the same source-independent playback stack as Mac, with document
picker access, recent files and mobile settings. tvOS remains Jellyfin-only.

```sh
Tools/vela/validate-apple.sh       # logic tests + iOS, tvOS and Mac builds
Tools/vela/validate-apple.sh ios   # logic tests + iPhone/iPad simulator build
Tools/vela/archive-apple.sh ios   # local device archive, no upload
Tools/vela/archive-apple.sh tvos  # local device archive, no upload
```

The validators use configured signing and never replace the installed Mac app.
Provisioning failures require configuring your own Apple development team.
Build success does not establish device or App Store qualification. See the
[release plan](release/apple-release-plan.md) and [App Review preparation](release/app-review.md).

For Debug-only local playback regression checks, copy the synthetic `sample.mkv`
from `Tools/LocalPlaybackFixtures/create.sh` into the simulator app's Documents
directory, then launch with `-VelaCheckFixture sample.mkv`. The check opens the
file, exercises transport/tracks/timing, stops and reopens the saved bookmark,
and writes `Documents/vela-playback-checks.txt`. Do not use a private video.
These launch checks are excluded from Release builds. Copy `external.ass` into
Documents as well to test external subtitles and the one-time mpv retry.
