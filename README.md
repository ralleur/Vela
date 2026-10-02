# Vela

Vela is an independent Jellyfin client for Apple TV and Mac, based on
[Swiftfin](https://github.com/jellyfin/Swiftfin). It keeps Swiftfin's native
Apple-platform experience and adds a focused home screen, remembered audio and
subtitle choices, language-aware playback presets, intro and recap skipping,
next-episode actions, and a Mac Catalyst app.

Vela is not an official Jellyfin or Swiftfin application. Jellyfin and Swiftfin
are trademarks of their respective owners.

## Platforms

- Apple TV: the `Swiftfin tvOS` target, distributed as **Vela**
- macOS: a Mac Catalyst build of Swiftfin's iPhone/iPad target, distributed as
  **Vela** (`com.ralleur.vela.mac`)

The Mac app adds native window and full-screen handling, keyboard controls,
continued playback while the window is covered, a right-click playback menu,
and a floating mini-player. During playback the window follows the video's
aspect ratio, can be dragged from anywhere in the player, and hides its macOS
window buttons together with the playback controls. Closing the player restores
the previous menu window size and shape. Stable whole-player window dragging
takes precedence over player swipe gestures, except on interactive controls.
A translucent Vela logo is shown by default in windowed playback, hidden in
full screen, and can be disabled in Settings (⌘,). Settings also provide language,
independent seek intervals, customizable audio/subtitle presets and 35 remappable
playback shortcuts based on VLC for Mac. This is not VLC's entire application
command set. Right-click the home settings button for account/server settings.
Click the timeline to seek; hovering shows the target time and a thumbnail when
the server provides preview images.

## Playback presets

Vela offers up to three one-press audio/subtitle combinations while a title is
playing. The local language follows Apple's per-app language setting, which by
default follows the device language. For example:

- German: `EN + EN UT`, `EN + DE UT`, `DE ohne UT`
- French: `EN + EN ST`, `EN + FR ST`, `FR sans ST`

The preset group is hidden when a title has no full subtitle choice. Individual
presets are hidden when their required audio or subtitle track is unavailable.

## Build and install

Requirements:

- a current Xcode installation
- an Apple developer team configured for signing

Create the ignored local signing configuration:

```sh
cp XcodeConfig/DevelopmentTeam.example.xcconfig XcodeConfig/DevelopmentTeam.xcconfig
# Add your DEVELOPMENT_TEAM value to DevelopmentTeam.xcconfig.
```

Install the Mac app:

```sh
Tools/vela/install-mac.sh
```

Build and install on an Apple TV:

```sh
Tools/vela/install-device.sh "Apple TV name"
```

Run the Vela logic tests:

```sh
(cd Tools/VelaLogicTests && swift test)
```

See [VELA.md](VELA.md) for the complete feature list, architecture notes,
development commands, and the upstream update process.

## Upstream and license

The `vela` branch is maintained on top of `jellyfin/Swiftfin` `main`. Upstream
files retain their original notices. Vela's additions use the same
[Mozilla Public License 2.0](LICENSE).
