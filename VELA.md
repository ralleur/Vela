# Vela fork of Swiftfin

This branch (`vela`) is Swiftfin with a small set of changes for the Apple TV.
Upstream is `jellyfin/Swiftfin` (remote `upstream`). The app installs as
**Swiftfin+** (`com.ralleur.swiftfin`), next to the App Store Swiftfin.

## What is different

**Player (tvOS)**
- Audio and subtitle choices are remembered per film and per series, by
  language. The next episode of a series starts with the series' choice.
  Changes made through the presets or through Swiftfin's own menus count.
  A track picked on the detail page before playing wins over the memory.
- Three preset buttons next to the player's action buttons:
  `EN + EN UT`, `EN + DE UT`, `DE ohne UT`. A preset is hidden if the title lacks
  the audio track or full (non-forced) subtitles it needs. The active preset
  shows a checkmark.

**Home (tvOS)**
- Continue: films only if played within the last 7 days; series stay (the
  episode in progress or the next one). A series comes back to the front with a
  "Neue Folge" badge when an episode was added after it was last watched.
  Series without anything new drop out after Swiftfin's Next Up limit
  (Settings, one year by default).
- Rows: Zuletzt hinzugefügt: Filme, Zuletzt hinzugefügt: Serien, Neueste Filme,
  Neueste Serien (plus Swiftfin's optional Recently Played and Live TV rows).

## Where the code is

New code lives in its own files, so upstream changes rarely touch it:

- `Shared/Vela/` – track memory, language matching, presets, Continue logic, badge
- `Swiftfin tvOS/Vela/` – the home screen provider
- `XcodeConfig/DevelopmentTeam.xcconfig` – team, bundle ID, display name
  (upstream ignores this file, so it never conflicts)
- `Tools/VelaLogicTests/` – unit tests for the pure logic (`swift test`)
- `Tools/vela/` – device install and upstream update scripts

Upstream files carry only small hooks, each marked with a `// Vela` comment (the display name in `Info.plist` is the one exception):

| File | Hook |
|---|---|
| `MediaPlayerItem+Build.swift` | restore/remember tracks before asking the server; attach the observer |
| `VideoPlayer+Toolbar.swift` | preset buttons on tvOS |
| `BaseItemDto+Poster.swift` | "Neue Folge" badge in the poster overlay |
| `MainTabView.swift` | tvOS home uses `VelaHomeContentGroupProvider` |
| `Swiftfin tvOS/Resources/Info.plist` | display name from `VELA_DISPLAY_NAME` |

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
