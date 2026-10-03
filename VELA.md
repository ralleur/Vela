# Vela fork of Swiftfin

Beta releases stay on `0.9.x`, incrementing only the patch number (0.9.1 →
0.9.2 → 0.9.3) until beta is explicitly declared finished. The earlier
1.0.0/1.1.0 release labels were mistakes.

This branch (`vela`) is Swiftfin with a small set of changes for the Apple TV
and a Mac app. Upstream is `jellyfin/Swiftfin` (remote `upstream`). The app
installs as **Vela** (`com.ralleur.vela`) with the Vela tile and replaces the
earlier, self-written Vela app on the Apple TV. It runs next to the App Store
Swiftfin.

The Mac app (`com.ralleur.vela.mac`, `/Applications/Vela.app`) is the Mac
Catalyst build of Swiftfin's iPhone/iPad target, with the same Vela changes.

## What is different

**Player (tvOS and Mac)**
- Audio and subtitle choices are remembered per film and per series, by
  language. The next episode of a series starts with the series' choice.
  Changes made through the presets or through Swiftfin's own menus count.
  A track picked on the detail page before playing wins over the memory.
- Up to three preset buttons next to the player's action buttons. The app
  language replaces German in the combinations: a German app shows
  `EN + EN UT`, `EN + DE UT`, `DE ohne UT`; a French app shows
  `EN + EN ST`, `EN + FR ST`, `FR sans ST`. The effective app language follows
  Apple's per-app language setting and therefore defaults to the Mac's language.
  No preset buttons are shown for titles without a full (non-forced) subtitle
  choice. Otherwise, each preset is hidden when its required audio or subtitle
  track is missing, and the active preset shows a checkmark.
  On tvOS and Mac the quick buttons use the same height as the other player buttons;
  the subtitles-off choice is labeled with just the audio language (for example
  `DE`), with the full description retained for VoiceOver.

- Prompts in the bottom trailing corner (with the controls hidden, select
  triggers them on tvOS; on the Mac they can be clicked, and Return triggers
  them; with the controls shown they are normal buttons):
  On tvOS, merely touching the Siri Remote while a skip or next-episode button is
  visible keeps the controls hidden, so the following Select click performs its
  action immediately. A next-episode prompt without an available next episode
  (only an outlook card) does not suppress touch. Otherwise touch reveals the
  controls as usual; directional and Play/Pause presses still provide explicit
  access to the controls.
  Mac uses direct pointer clicks and Return for these same prompt actions;
  the Siri Remote touch interception only applies on tvOS.
  - "Intro überspringen" / "Rückblick überspringen" during intro and recap
    segments (Jellyfin media segments; chapter names like "Intro" or "Vorspann"
    as a fallback for episodes).
  - Episode credits (outro segment, "Credits" chapter, or the last 30 s):
    "Nächste Folge" with season/episode and title. After the last episode in the
    library a card says what comes next, from TVmaze (no API key): the date of
    the next episode or season, an announced season without a date, an episode
    that aired but is missing from the library, or that the series has ended.
  - Film credits (outro segment, "Credits" chapter, or the last 3 % of the
    runtime, two to five minutes): "Als Favorit markieren", pressing again
    removes the favorite.

**Home (tvOS and Mac)**
- Continue: films only if played within the last 7 days; series stay (the
  episode in progress or the next one). A series comes back to the front with a
  "Neue Folge" badge when an episode was added after it was last watched.
  Series without anything new drop out after Swiftfin's Next Up limit
  (Settings, one year by default).
- Rows: Zuletzt hinzugefügt: Filme, Zuletzt hinzugefügt: Serien, Neueste Filme,
  Neueste Serien (plus Swiftfin's optional Recently Played and Live TV rows).
  On tvOS Continue is the large selector at the top; on the Mac it is a row of
  landscape posters.

**Mac**
- Resizable window, Vela icon (Icon Composer file built from the tvOS layers),
  name "Vela" in the menu bar and Dock.
- Shows up in Jellyfin as client "Swiftfin macOS", device "Mac" (Swiftfin would
  report an iPad).
- Swiftfin's keyboard shortcuts work in the player (space, arrows, ⌘F, …).
- In the player the window's toolbar (title and tabs) is hidden, also in full
  screen, and comes back when the player closes.
- The window is resized and locked to the video's aspect ratio during playback;
  closing the player restores the menu's previous size and aspect constraint.
- The red, yellow and green window buttons disappear together with the playback
  controls. The window can be dragged from the player background with stable,
  screen-coordinate movement, including while it is the floating mini player.
- The translucent Vela logo is enabled by default in windowed playback and always
  hidden in full screen. Settings (⌘,) control the logo, app language, separate
  forward/backward seek intervals, quick presets and 35 playback shortcuts based
  on VLC for Mac. VLC-specific application commands are not implemented.
- The timeline supports click-to-seek and hover time previews, with thumbnails
  when the server supplies preview images.
- Playback goes on when the window is covered, hidden or another app is in
  front (Swiftfin pauses when the app goes to the background, which a Mac
  window does as soon as it is covered).
- Right click in the player: play/pause and "Bild in Bild". Bild in Bild turns
  the window into a 480 pt wide 16:9 player in the bottom right corner that
  floats above other windows and follows to every Space; "Bild in Bild beenden"
  (or closing the player, or quitting) brings the window back, into full screen
  if it came from there. The system's Picture in Picture cannot show VLC's video
  in a Mac Catalyst app (AVKit never reports it possible for libVLC's sample
  buffer output, and starting it anyway does nothing), so the window itself
  becomes the mini player; Mac Catalyst has no API for window level and frame,
  so the AppKit window is driven through its public methods at runtime.

## Where the code is

New code lives in its own files, so upstream changes rarely touch it:

- `Shared/Vela/` – track memory, language matching, presets, Continue logic,
  badge, home screen provider, prompt overlay (all platforms)
- `XcodeConfig/Vela.xcconfig` – public bundle IDs, display name, app icons and
  Mac entitlements
- `XcodeConfig/DevelopmentTeam.xcconfig` – local signing team (ignored; copy the
  tracked `DevelopmentTeam.example.xcconfig` before building)
- `Swiftfin tvOS/Vela/VelaAssets.xcassets` – the Vela tile and Top Shelf images
- `Swiftfin/Vela/` – the Mac/iOS icon (`AppIcon-vela.icon`) and the Mac
  entitlements (keychain, user-selected file access and app-scope bookmarks)
- `Vela.xcworkspace` – the Mac build: Swiftfin's project plus two fixed packages
  (see below)
- `Tools/VelaLogicTests/` – unit tests for the pure logic (`swift test`)
- `Tools/vela/` – device and Mac install, Mac package preparation, upstream update

The original Vela features use small hooks in upstream files. The universal-player work also refactors the shared playback item, manager and engine contracts; see the source-independent playback section below. Historical hooks:

| File | Hook |
|---|---|
| `JellyfinMediaPlayerItem+Build.swift` | restore/remember tracks before asking the server; attach the observer |
| `VideoPlayer+Toolbar.swift` | preset buttons |
| `BaseItemDto+Poster.swift` | "Neue Folge" badge in the poster overlay |
| `MainTabView.swift` | home uses `VelaHomeContentGroupProvider` (tvOS and iOS/Mac) |
| `PlaybackControls.swift` (tvOS and iOS) | prompt overlay; on iOS also `VelaMacPlayerSupport` (Mac window handling, right-click menu) |
| `NavigationRoute+Media.swift` | no pause on background in the Mac app |
| `VideoPlayer+KeyCommands.swift` (iOS) | Return triggers the visible prompt |
| `JellyfinClient.swift` | the Mac app reports client "Swiftfin macOS", device "Mac" |
| `VideoPlayerContainerView.swift` | select press triggers a visible prompt while the controls are hidden |
| `Swiftfin tvOS/Resources/Info.plist` | display name from `VELA_DISPLAY_NAME` |
| `Swiftfin/Resources/Info.plist` | display and bundle name from `VELA_DISPLAY_NAME` |
| `XcodeConfig/Shared.xcconfig` | includes the public Vela identity and the optional local signing team |
| `Swiftfin.xcodeproj/project.pbxproj` | tvOS app icon from `VELA_APP_ICON`; iOS target: Mac Catalyst on, `Shared.xcconfig` as base of both configurations (upstream only has it on the project's Debug), app icon and entitlements from `VELA_IOS_*`, no hard-coded Release bundle ID, OpenGLES linked on iOS only |

## Build, test, install

```sh
# Simulator build (signed, so the keychain works and sign-in survives)
xcodebuild -project Swiftfin.xcodeproj -scheme "Swiftfin tvOS" \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p),OS=27.0' \
  -derivedDataPath build/dd -skipMacroValidation -skipPackagePluginValidation -allowProvisioningUpdates build

# Logic tests
(cd Tools/VelaLogicTests && swift test)

# Apple TV (Release by default)
Tools/vela/install-device.sh Wohnzimmer
```

An unsigned simulator build (`CODE_SIGNING_ALLOWED=NO`) has no keychain access
and crashes right after sign-in; that is Swiftfin's debug assertion, not a bug
of the fork.

In Debug builds, launching with `-VelaDebugMarkNextUpNew YES` marks every next
episode as new, to check the badge without waiting for a new episode.

### Mac

```sh
Tools/vela/install-mac.sh                     # Release build → /Applications/Vela.app
CONFIGURATION=Debug Tools/vela/install-mac.sh # Debug build, stays in build/dd-mac
```

The Mac build goes through `Vela.xcworkspace`, not the project, because two of
Swiftfin's packages do not build for Mac Catalyst as published.
`Tools/vela/prepare-mac-packages.sh` (run by the install script; run it once
before opening the workspace in Xcode) puts fixed copies into
`build/mac-packages`, at the revisions the project pins, and the workspace uses
them in place of the remote packages:

- BlurHashKit takes Mac Catalyst for AppKit (`canImport(AppKit)`) and does not
  compile. The copy adds `!targetEnvironment(macCatalyst)`.
- MPVUI's `Libmpv.xcframework` ships its Mac Catalyst slice as an iOS-style
  bundle, which Xcode refuses to embed in a Mac app. The copy turns it into a
  versioned bundle.

When a Swiftfin update moves those pins, the script fetches the new revisions
and applies the same fixes; if upstream fixes them, the overrides can go.

The Mac app must be signed with a provisioning profile: the keychain group in
`Swiftfin/Vela/Vela-Mac.entitlements` asks for one. Without it the keychain
refuses Swiftfin's access token and the Debug build stops right after sign-in
(same assertion as in the unsigned simulator build).

Debug builds of the Mac app write a picture and the view hierarchy of their
window on `notifyutil -p com.ralleur.vela.snapshot` to
`~/Library/Containers/com.ralleur.vela.mac/Data/Library/Caches/vela-snapshots/`
(`latest.png`, `latest.txt`, which also holds the prompt state, the mini
player's steps and the AppKit state of the windows: frame, full screen, level). That is how
the player can be checked from a script without screen recording permission;
the player controls do not show up in the accessibility tree. Trust the AppKit
line over `CGWindowListCopyWindowInfo`: a full-screen window with its title bar
hidden looks there like a screen-sized ordinary window.

When testing playback through Jellyfin's remote control, pick the session by
client "Swiftfin macOS" *and* this Mac's IP address. Other Macs run Vela too and
show up with the same client and device name.

## Taking Swiftfin updates

```sh
Tools/vela/update-upstream.sh        # onto upstream main
Tools/vela/update-upstream.sh 1.7    # or onto a newer release tag
```

The script rebases the fork's commits, builds, and runs the logic tests. On a
conflict it stops; resolve, `git rebase --continue`, run it again. Conflicts are
most likely in the hook files above.

The fork started on upstream `main` (September 2026) rather than on release
1.6.1, because 1.6.1 no longer builds with Xcode 27 (CoreStore). Once a newer
release builds, following release tags is the calmer choice.

## License

Swiftfin is MPL-2.0. The fork's own files carry the same MPL header; upstream
headers stay untouched. The name "Swiftfin" and its logo are not licensed for
redistribution – before publishing anything, give the app its own name and icon.


## Source-independent playback (October 2026)

Before this change, the shared `MediaPlayerItem` contained `BaseItemDto`,
`MediaSourceInfo`, `MediaStream`, a device profile and a Jellyfin play-session ID.
Constructing it also constructed a server progress reporter. The manager inherited
the authenticated `ViewModel`. Engines accepted synthetic `MediaStream` objects
just to identify a selected track. This made a local URL insufficient to create
a playback session.

The shared player now uses `PlaybackMedia`, `PlaybackChapter` and `PlaybackTrack`
from `Shared/Vela/Playback/Core`. Those files import Foundation, with CryptoKit
used by the engine index map; the `PlaybackCore` test target has no Jellyfin
package dependency. `MediaPlayerManager` is an `ObservableObject` whose inputs
are a `MediaPlayerItem` or `PlaybackItemProviding`. Its state machine, transport,
clock, volume and rate do not fetch a server session. Engine track selection uses
integer engine IDs rather than fabricated API objects.

The source boundary is explicit:

- `JellyfinMediaPlayerItem`, `JellyfinPlaybackAdaptation` and
  `JellyfinMediaPlayerItem+Build` own the real server models, playback-info
  requests, device profiles, transcoding rebuilds, server subtitle URLs and
  metadata conversion. Only this adapter creates `MediaProgressObserver`.
  Item replacement and errors finish that reporter once, before detaching it.
- `LocalMediaPlayerItem` owns a `LocalFileAccess` lease, filename metadata,
  readable sibling subtitles and local resume persistence. It never constructs
  a Jellyfin object or reporter. Duration and tracks arrive from the engine.
- `MediaPlayerItem` owns common selection state and source policy hooks for
  rebuilding and supplements. Local playback has no server quality selector,
  episode queue or server-only supplements. The UI still uses the same
  `VideoPlayerViewShim`, player container, toolbar, timeline and track menus.

A third source can provide common metadata and a playable URL/item through the
same protocol. It need not implement Jellyfin authentication, reporting or DTOs.
The app remains a single application target; this is a source boundary, not a
second player stack or a fully extracted standalone player package.

### Mac file workflow

Use File → Open File (`⌘O`), Finder Open With, a file-open event at launch,
or drop a file onto the root or active player. A new video replaces the current
session after stopping its decoder and finishing its source. No default file
handler is changed. The bundle registers an Alternate Viewer for video and
imports Matroska/WebM content types; users can choose Vela in Finder normally.

A signed-out Mac shows Open File, Connect to Jellyfin and recent files.
File handling sits outside local-user authentication, so incoming videos do not
need a configured server. Existing signed-in users retain the Jellyfin home.

The File menu also provides Open Recent, Clear Menu, Add Subtitle File (`⇧⌘O`)
and Try Other Playback Engine (`⌥⌘P`). Subtitle attachment and engine retry apply
to local sessions. Server-supplied external subtitles retain their existing path.
The local player uses `UIPreferencesHostingController` so the established Mac
keyboard commands work in its presented view. Space, arrow seeking, speed,
volume/mute, language shortcuts and fullscreen are shared with server playback.
Double-clicking the video toggles fullscreen. The existing floating mini player
is reused; it is not native system Picture in Picture.

Recent files are capped at 20. Positions are saved periodically and at teardown;
very short and completed positions restart at the beginning. The existing resume
offset preference still applies. Clear Menu removes bookmarks and positions.
Same-stem SRT, ASS/SSA and VTT discovery is best effort: the app does not request
a parent directory just to discover subtitles. Explicitly selected subtitles
hold their own lease for the life of the media item.

### Engine and sandbox decisions

Automatic local playback currently means VLC. The existing native AVPlayer
adapter does not implement track switching or speed configuration fully, so
routing ordinary MP4 files there would remove controls that users expect. No
new playback framework was added. The existing mpv engine is an opt-in preference
and an explicit retry path. A retry preserves the saved position and uses the
same player UI. There is no silent engine retry loop.

The bundled libass has no working CoreText font provider in the tested Catalyst
build. VLC's supported `ssa-fontsdir` media option points it to the readable Mac
system-font directory; a styled external ASS fixture rendered after this change.
This does not bundle or copy system fonts. Fonts embedded in media remain the
engine's responsibility.

The signed Mac app retains App Sandbox and network-client entitlements.
`UIDocumentPickerViewController` in this tested Catalyst runtime requests a
read-write sandbox extension when opening in place. A read-only user-selected
entitlement caused the native panel to close without delivering a URL. The Mac
entitlement therefore allows **user-selected** read/write access; playback only
reads media, and persisted security-scoped bookmarks explicitly allow read-only
access. There is no broad Movies, home-directory or full-disk entitlement.
`LocalFileAccess` balances its scope acquisition with release on deinit, verifies
that a selection is a readable regular file without loading its contents, and
stays retained until the decoder view releases the media item. Missing or
inaccessible selections ask the user to choose the file again.

### Validation and reproduction

Run the pure logic suites with:

```sh
swift test --package-path Tools/VelaLogicTests
```

The CI workflow now runs these suites in a separate job. The 33 existing tests
and seven new playback-core tests pass locally. New tests cover server-free
metadata, track identity mapping, resume edge cases, sidecar matching, readable
files, directories, missing files and rejected remote URLs.

Generate synthetic fixtures without downloading media:

```sh
Tools/LocalPlaybackFixtures/create.sh build/local-fixtures --high-bitrate
```

The optional HEVC fixture needs ffmpeg's VideoToolbox encoder. Existing video
fixtures are reused. The directory is ignored by Git. The script also creates
multi-audio MP4/MOV/MKV, embedded subtitles, external SRT/ASS and corrupt input.

Build the Mac through `Vela.xcworkspace` after package preparation, as above.
A Debug launch with `-VelaLocalOnly` displays the welcome view before starting
account/store/authentication routing, without deleting existing accounts. Open
`long.mp4`, then use Debug File → Run Local Playback Checks (`⌃⌥⌘T`). The check
requires the VLC multi-track fixture and reports actual engine/clock assertions;
it restores rate, volume and track selections, then leaves playback paused.
It is excluded from Release builds.

Executed in this workspace on Xcode 27:

| Check | Observed result |
|---|---|
| Mac Catalyst Debug build | Passed |
| Mac Catalyst Release build | Universal arm64/x86_64 build and strict code-signature verification passed |
| tvOS 27 simulator build | Passed |
| Pure logic tests | 33 existing + 7 new passed |
| Live local VLC assertions | All 13 passed, including after a server session |
| Native `⌘O` picker | Opened and played the selected local MP4 |
| LaunchServices file opening / running-app replacement | Played MP4, MOV and MKV; a video passed at process launch played |
| Finder Open With | Finder listed the Debug bundle; choosing it played MKV without changing the default |
| Account-free startup path | Welcome and local playback before account startup |
| Keyboard and fullscreen | Space pause/resume, arrow seek, `⌘F` entry and Escape exit; double-click entry and exit observed |
| Floating mini player | Local playback entered the small floating window and restored its original size |
| Embedded tracks | Two audio tracks enumerated/switched; subtitle enabled/disabled |
| External subtitles | Native picker attachment, SRT text and styled ASS rendering observed |
| High bitrate / HEVC | 3840×2160, 30 fps, 45.35 Mb/s MOV played; VLC logged VideoToolbox HEVC decoding |
| Manual engine fallback | VLC → mpv → VLC played, retained position; mpv rendered external ASS and responded to pause/seek |
| Teardown | No open fixture file handles and 0% CPU observed after stopping the engine round trip |
| Corrupt input | Actionable decode error; a valid MOV played afterward |
| Recent/resume | Reopening across relaunch restored position with the configured resume offset |
| Jellyfin | Existing login/library, playback, track controls and bitrate rebuild exercised |
| Cross-source reuse | Jellyfin → local → Jellyfin and local → Jellyfin → local, without restart |

The live Jellyfin bitrate check rebuilt HEVC playback into H.264 at the selected
lower bitrate. Reporting remains in the server adapter, but a separate server
log audit of every start/progress/stop request has not been performed. Local
runtime checks confirm no source reporters, and the source-free core compiles
without a Jellyfin dependency; this is not a packet-capture claim.

Still requiring release qualification: Finder/Dock drag gestures (the drop handlers are implemented but the cross-window gesture was not automated here), physical Apple TV remote/focus behavior,
revoked security-scoped permissions across OS restarts, multi-hour/very large
files, HDR/Dolby/audio passthrough, full codec and subtitle-language coverage,
and signed/notarized distribution. The short HEVC test verifies acceleration
for that fixture on this Mac, not every codec or HDR format. Native AVPlayer's
remaining feature gaps are why it is not selected for local media. Existing Mac
mini-player/window bridging still relies on the fork's runtime AppKit bridge.

### Distribution review

No playback dependency was introduced or upgraded. SwiftVLC's wrapper carries
an MIT license; [libVLC documents LGPL 2.1 licensing](https://images.videolan.org/vlc/libvlc.html).
The existing MPVUI package names its binary target `Libmpv-GPL`; do not infer that
binary's license from the wrapper's license or from an LGPL-capable mpv build.
[mpv documents its licensing and build distinctions](https://mpv.io/manual/stable/#copyright).
The exact shipped binaries and notices still need release/distribution review.
This work does not claim App Store eligibility or perform notarization, publishing,
or replacement of the installed application. The existing Mac install workflow
and upstream iOS/tvOS packaging remain in place.

## Phase 2: everyday-player product pass (October 2026)

This phase was performed in the working Mac port, `vela-swiftfin`, on branch
`vela`. The older sibling `Vela` checkout is tvOS-only. The incoming universal
player work was already present as uncommitted changes; it was retained and
inspected against the repository history, source and earlier build logs.

### Independent audit and priorities

The previous phase genuinely separated local media from Jellyfin DTOs,
authentication and reporting. Local files already used the shared player, with
native open events, recent bookmarks, resume, track discovery, external subtitles
and two existing decoders. Its Debug/Release Mac, simulator and logic-test build
claims were supported by logs. The architecture did not need replacement.

The largest remaining gaps were lifecycle correctness and discoverability:
rapid opens could overlap UIKit presentations; a disappearing globally injected
player view could act on its replacement; error alerts exposed decoder details;
engine retry was buried in a menu; track choices were not remembered for local
files; timing controls existed only as shortcuts; some Mac UI remained hardcoded
German while new file actions were English. Foreground session restoration and
Jellyfin remote commands also needed to respect a local session.

The comparison used the products' own descriptions, not a claim that a full
head-to-head benchmark was performed:

| Benchmark | Relevant gap | Decision and implementation |
|---|---|---|
| [VLC](https://images.videolan.org/vlc/features.html): broad playback and subtitle/track controls | Reliability on repeated opens, meaningful failure recovery, accessible timing adjustments | Keep the existing broad decoder, serialize replacement, bound alternate-engine attempts, expose timing in track menus. No new decoder or renderer. |
| [IINA](https://iina.io/): Mac interaction, minimal controls, system integration | Immediate file opening, remembered choices, in-player settings, cursor behavior, menu/keyboard ergonomics | Improve existing file host and shared controls, recent rows, local track memory, cursor hiding, settings organization and localization. Retain the existing floating mini player. Native PiP remains a separate limitation. |
| [Infuse](https://firecore.com/infuse): polished Apple/server experience | Local playback must not disrupt server browsing or inherit server commands | Keep shared playback UI, preserve server-only quality/episode features, isolate local sessions from server state/track commands and defer account restoration on file launch. |

A full local library, subtitle download service, new rendering engine, cloud
history and monetization infrastructure were deliberately outside this focused
work. Vela remains free and open source, with the useful version available to all.

### Implemented behavior

- A single main-actor worker owns local presentation and dismissal. Bursts keep
  the newest pending video, and new presentation waits for the old transition.
  `VideoPlayer` observes the manager explicitly passed to it. Stale teardown may
  clear global playback ownership only if it still owns that session. Decoder
  events caused by an explicit stop are ignored.
- Local errors offer **Try Compatible Playback** and **Choose Another Video**.
  The other existing engine is offered once per open operation; another failure
  ends the attempt without looping. Retry carries the position, volume, mute,
  timing offsets and retained external-subtitle resources into the new item.
  A new normal open starts a new attempt. This supersedes Phase 1's unrestricted
  manual engine round trip; `⌥⌘P` now follows the same bounded retry policy.
- Recent rows show a filename, parent folder and resume position, with Start Over
  and Remove from Recent actions. Resolved moved bookmarks migrate the history
  identity. History can be cleared or disabled; disabling clears saved bookmarks,
  positions and choices. No local media database was added.
- Audio/subtitle memory uses language and useful labels rather than decoder IDs.
  Labels prefer localized languages, include VLC channel counts, and retain
  meaningful titles such as commentary. Subtitle Off is localized. Track menus
  expose synchronization in 50 ms increments and reset, sharing the same state
  as the existing shortcuts. External subtitle opening is available from the
  subtitle menu even when the video contains no subtitle track.
- Settings group General, Playback, Presets, Keyboard and Advanced. Engine choice
  and subtitle encoding are advanced options; automatic playback remains VLC.
  VLC subtitle sizing reuses the existing renderer configuration. The alternative
  engine's text presentation retains its existing accessibility-backed styling.
- The welcome, new menus and settings have English/German resources. Other
  languages fall back to English for these additions. Existing translated
  Jellyfin views remain intact. Reduced Motion is honored by control/supplement
  animations; decorative settings/welcome logos are excluded from accessibility.
- Cursor hiding follows playback controls and restores on movement/teardown.
  The existing Mac window bridge is reused, not replaced. No branding redesign.

### Privacy and Jellyfin boundary

`LocalMediaPlayerItem` has no server reporters or source observers. Local IDs,
filenames and URLs are redacted from the manager's structured playback metadata.
Jellyfin pause/seek/stop/track/bitrate commands now require a Jellyfin item.
Explicit remote requests to play server media remain supported.

On cold file launch, the root gives the document event a short opportunity to
arrive, then defers account restoration while local playback is opening/active.
Foregrounding the app does not refresh the account during a local session. This
is not a firewall: an already connected Jellyfin library/socket may legitimately
continue background activity. The startup grace period is not proof that every
possible OS event timing is network-free.

The source audit found no Sentry/analytics/advertising/StoreKit/paywall calls in
application code. Pulse and PersistentLogHandler record local diagnostics;
Jellyfin's NetworkLogger redacts password request bodies. Existing TVmaze episode
information is tied to server episode prompts, not local files. No speculative
logging or networking framework removals were made. OS-level and binary-internal
network behavior was not established by packet capture.

### Reproduction and evidence

The synthetic fixture generator and Phase 1 commands above remain applicable.
The live local command `⌃⌥⌘T` now checks 15 actual engine behaviors, adding audio
and subtitle delay round trips. It restores selected settings and leaves playback
paused. After opening `long.mp4`, `sample.mov` and `sample.mkv` once, Debug File →
Run Replacement Checks (`⌃⌥⌘R`) runs eight rapid-open bursts, verifies the requested
video settles, stops playback, then checks weak references to prior managers after a pointer-input checkpoint.
These developer commands are absent from Release builds.

The first replacement run reproduced stale alerts, overlapping presentation and
an orphaned decoder file handle. After fixing ownership/presentation, all eight
cycles passed, previous manager references were released and `lsof` showed no
fixture files held after stopping. libVLC emitted seek-abort diagnostics during
aggressive replacement, but the corrected run did not surface a false failure.
This is a short stress regression check, not a multi-hour memory-leak guarantee.

Phase 2 also manually verified retained German audio/subtitle-off choices on
reopen, an attached styled ASS file surviving retry and rendering in mpv, and a
malformed file reaching a terminal error after one alternative attempt. Native
window close ended the test process. The local live checks passed all 15
assertions. Final build and cross-source evidence is recorded below.

### Packaging and remaining release requirements

Both platform marketing versions are prepared as **0.9.4**. The Mac build is 5;
tvOS is 71, preserving monotonic progression from its inherited build 70. The
previous tvOS marketing value was 1.4.1 despite the repository's beta-numbering
policy. Mac app category metadata is now emitted in the actual bundle. About
content points to Vela while retaining upstream attribution.

`Tools/vela/collect-notices.py` gathers license/notice texts from pinned package
checkouts and bundled resources without downloading dependencies. Its generated
inventory is bundled and accessible offline in Mac Settings. It is not proof of
complete binary licensing compliance. In particular, reconcile the existing
`Libmpv-GPL` artifact with its build/source and transitive obligations before
public distribution; do the same for libVLC and its components. No playback
package was added or upgraded by this phase.

Verify a built Release bundle without installing or publishing it:

```sh
Tools/vela/verify-mac-build.py --universal
```

The verifier checks identity, beta version, document registration, category,
assets/notices, strict signing, sandbox/file/bookmark entitlements and universal
architecture when requested. It does not notarize, publish, assert App Store
eligibility or settle binary license/source obligations.

Release qualification still needs physical Apple TV input/focus tests,
Finder/Dock drag gestures, revoked bookmark permissions after OS restarts,
network interruption recovery, multi-hour and very large media, unusual codec
and character-encoding corpora, HDR/Dolby/passthrough, actual VoiceOver/reduced
motion sessions, and a separate audit of Jellyfin start/progress/stop requests.
The existing runtime AppKit window bridge remains a distribution risk to assess.
Native system PiP is unavailable for the current VLC Catalyst output; the
floating mini player remains available. Subtitle sidecar discovery is bounded
by granted folder access, and explicit attachments are retained for the active
session/retry, not persisted as separate security-scoped subtitle bookmarks.

### Final Phase 2 validation results

Validation on the development Mac with Xcode 27 (2026-10-02):

| Evidence type | Check | Result |
|---|---|---|
| Automated build | Mac Catalyst Debug | Passed after the final controller-restoration and debug-check changes |
| Automated build | Mac Catalyst Release | Passed; universal arm64/x86_64, strict signature and bundle verifier passed |
| Automated build | tvOS 27 simulator | Passed; actual bundle version 0.9.4 (71) |
| Automated tests | Pure Vela and PlaybackCore suites | 33 + 11 tests passed; covers bounded retry, semantic track memory and decoder-label cleanup as well as Phase 1 source policy |
| In-app assertions | Local VLC transport/tracks/timing | All 15 passed, including after Jellyfin playback and malformed-file recovery |
| In-app stress + pointer checkpoint | Eight rapid replacement bursts | Passed; all tracked previous managers released and active session cleared |
| OS diagnostics | Stopped local stress run | No fixture handles; 0.0% CPU at the sampled idle point |
| Manual UI | Normal cold launch with a local file | Played directly; no local-only debug launch argument needed |
| OS diagnostics | Cold local playback before account restoration | `lsof` found zero open IP sockets for that process at the sampled point; not a packet-capture guarantee |
| Manual UI | Cold local playback → Jellyfin | After waiting for controller dismissal, the saved account's home and playable detail page loaded |
| Manual UI | Jellyfin playback and quality | Playback worked; selecting lower quality rebuilt HEVC into H.264, confirmed by decoder output |
| Manual UI | Jellyfin → local MKV → Jellyfin | Both played without restarting; server quality/episode controls stayed server-specific |
| Manual UI | Local track memory | German audio and subtitle Off restored on reopen |
| Manual UI | External subtitle retry | Explicit ASS attachment remained available after retry and rendered with styling in mpv |
| Manual UI | Final failure recovery | Localized useful error; one alternate attempt; terminal error had no repeated retry; Choose Another Video opened the native picker and a valid MP4 played |
| Manual UI | Settings during playback | Opened and closed; space, seeking and shared controls remained usable afterward |
| Manual UI | Presentation | Localized welcome/recent rows, simplified language/channel track menus, settings and offline notices inspected |
| Manual UI | Native window close | Closed the development app, with no continued test process |
| Static validation | Plists, English/German strings, diff whitespace | Passed |

A useful stress-test distinction: after an entirely programmatic replacement run,
UIKit can retain its last hovered view and that view's SwiftUI environment until
new pointer input. A no-content heap/reference-tree inspection traced one stopped
manager specifically to `UIHoverEvent → UITouch → UIView → SwiftUIEnvironmentWrapper`.
After an actual pointer event, another heap inspection found no `MediaPlayerManager`
instances. The debug test now asks for that pointer checkpoint before asserting
release, rather than reporting normal UIKit event caching as a permanent leak.
No UIKit internal state is mutated to force the result. The same inspection
reported a 199.7 MB current physical footprint versus a 520.7 MB peak after the
mixed server/local run; these are point measurements, not an endurance benchmark.

One exploratory cold-local/fullscreen run left initial server views loading for
an extended period. Account startup now also waits until the local controller
has actually dismissed, not merely until the manager announces Stop. The repeated
cold-local/home/detail check passed afterward. The exact cause of that original
loading delay was not proven, so exhaustive fullscreen/network transition timing
remains release qualification work rather than a claim of universal coverage.

Build logs for this run were written to `/tmp/vela-phase2-debug-verified.log`,
`/tmp/vela-phase2-release-verified.log`, `/tmp/vela-phase2-tvos-verified.log` and
`/tmp/vela-phase2-tests-final2.log`; packaging output is in
`/tmp/vela-phase2-release-verification.log`. These are local evidence, not tracked
release artifacts. The fixtures and derived data remain ignored.

Additional scope limits: local playback is a single-video workflow, without a
local playlist or embedded-chapter extraction. Attaching a Mac subtitle file is
currently local-playback-only; Jellyfin keeps its server-supplied subtitle path. Subtitle encoding options and
appearance settings use engine facilities but were not validated against a full
multilingual corpus. No public release, notarization, default-handler change or
replacement of `/Applications/Vela.app` was performed.
