# Vela fork of Swiftfin

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

- Prompts in the bottom trailing corner (with the controls hidden, select
  triggers them on tvOS; on the Mac they can be clicked, and Return triggers
  them; with the controls shown they are normal buttons):
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
  controls. The window can be dragged from anywhere in the player, including
  while it is the floating mini player.
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
  entitlements (Swiftfin's without Wi-Fi info, plus a keychain group)
- `Vela.xcworkspace` – the Mac build: Swiftfin's project plus two fixed packages
  (see below)
- `Tools/VelaLogicTests/` – unit tests for the pure logic (`swift test`)
- `Tools/vela/` – device and Mac install, Mac package preparation, upstream update

Upstream files carry only small hooks, each marked with a `// Vela` comment (except the two build-setting hooks in `Info.plist` and the project file):

| File | Hook |
|---|---|
| `MediaPlayerItem+Build.swift` | restore/remember tracks before asking the server; attach the observer |
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
