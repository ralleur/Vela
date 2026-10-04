<p align="center"><img src="marketing/brand/kurtz-icon.png" alt="kurtz" width="96"></p>

# kurtz

**A video player for Mac, iPhone, iPad and Apple TV — with Jellyfin built in.**

Mac beta available now. iPhone/iPad and Apple TV App Store releases are in preparation.

Good videos go further. Your files. Your Jellyfin library. One player.

![Sintel playing in the real kurtz Mac window, with playback controls hidden.](marketing/screenshots/kurtz-0.9.6/player-clean.jpg)

Watching a video shouldn't start with choosing an app. Open an MKV on your Mac,
or pick a film from your Jellyfin library. Use the same player. The controls
are there when you need them, then they get out of the way.

**Free. Open source. No subscription, in-app purchases or Pro tier.**

[Download kurtz 0.9.6 for Mac](https://github.com/ralleur/kurtz/releases/download/kurtz-0.9.6/kurtz-0.9.6-macOS-universal.dmg) · [Website](https://ralleur.github.io/kurtz/) · [Release notes](https://github.com/ralleur/kurtz/releases/tag/kurtz-0.9.6)

> **kurtz 0.9.6 Beta is available as a universal DMG.** macOS 15.6 or later;
> Apple silicon and Intel. The app is Developer-ID signed and notarized by Apple.
> Open the disk image and drag kurtz into Applications.

## Two ways to press play

**Your files.** On macOS, use **File → Open Video** (`⌘O`), Finder's **Open With**,
or drop a video into kurtz. Local playback needs no account or server. Set kurtz
as a format's default in Finder's Get Info → Open with → Change All if you want
to open it with a double-click. kurtz doesn't change your associations for you.

**Your library.** Connect your Jellyfin server, browse its library, open a detail
page and start watching. Server progress, audio/subtitle preferences and
metadata-dependent episode features retain the Swiftfin client foundation.
Use `⌘O` to open a local file while browsing. On the Mac, the profile menu offers
**Settings** and **Accounts and Servers**.

![The real kurtz Jellyfin detail page for Sintel.](marketing/screenshots/kurtz-0.9.6/jellyfin-detail.jpg)

## The small comforts

- **Pick up where you left off.** Up to 20 recent local files, positions and
  selected tracks stay on your Mac. Clear or disable history in Settings.
- **Choose what you hear and read.** Available audio tracks, embedded subtitles,
  and external SRT, ASS/SSA or VTT files, with timing controls in the track menus.
  Use `⇧⌘O` to add a subtitle; nearby matching files are discovered when access permits.
- **Stay on the keyboard.** Space to pause, arrows to seek, `⌘↑`/`⌘↓` for volume,
  `⌘F` or a double-click for fullscreen. Shortcuts and seek intervals are configurable.
- **Set your pace.** Playback speed controls, fullscreen and a floating mini
  player. The mini player is a floating kurtz window, not system Picture-in-Picture.
- **Try the other engine.** VLC is the default for local files; **Try Compatible
  Playback** offers one retry with the bundled mpv alternative if a file fails.

![The same film frame with kurtz’s actual playback controls visible.](marketing/screenshots/kurtz-0.9.6/player-controls.jpg)

Format behavior depends on the engine and file. There is no blanket claim of
all-codec, HDR or audio-passthrough support. See the [claim audit](docs/product-audit.md)
and [engineering evidence](KURTZ.md) for the tested scope.

## Built on Swiftfin, with gratitude

kurtz is a fork of **[Swiftfin](https://github.com/jellyfin/Swiftfin)**. Swiftfin
and its contributors built the native Apple Jellyfin client foundation that
made this possible. kurtz adds a broader Mac role: that client becomes useful
when the video happens to be a local file, too.

kurtz is an independent project, not an official or endorsed Jellyfin or Swiftfin
application. Their names and marks belong to their respective owners.

## Platforms and status

| Platform | Current scope |
| --- | --- |
| **macOS** | Mac Catalyst; local files and Jellyfin. Build minimum macOS 15.6; launch captures on Apple silicon. Release is configured for Apple silicon and Intel. |
| **Apple TV** | Jellyfin browsing and playback; tvOS 26.1+. Source builds available; App Store release in preparation. No local-file workflow. |
| **iPhone / iPad** | iOS/iPadOS 18.6+. Local videos from Files, recent files, subtitles and Jellyfin in one app. Development builds; device qualification and App Store release in preparation. |

kurtz is beta software. Physical Apple TV behavior, oldest supported operating
systems and long-session reliability still need further qualification. Existing downloads are listed in
[releases](https://github.com/ralleur/kurtz/releases); read their signing/version
notes before choosing a build.

See the [Apple release plan](docs/release/apple-release-plan.md) for implementation evidence and remaining release gates. There are no public iOS/tvOS App Store or TestFlight links yet. Windows and Linux are not supported. Screenshots above show the Mac release.

## Build, understand, contribute

Requirements: macOS, Xcode (validated with Xcode 27) and signing configuration.

```sh
cp XcodeConfig/DevelopmentTeam.example.xcconfig XcodeConfig/DevelopmentTeam.xcconfig
# Set your team in the ignored local file.
CONFIGURATION=Debug Tools/kurtz/install-mac.sh
swift test --package-path Tools/KurtzLogicTests
```

The Debug build stays in `build/dd-mac`; omitting `CONFIGURATION=Debug` builds
Release and replaces `/Applications/kurtz.app`.

- [Build and installation guide](docs/BUILDING.md): signing, package patches, Mac and Apple TV.
- [KURTZ.md](KURTZ.md): architecture, source-independent playback, validation and upstream updates.
- [Contribution guide](Documentation/contributing.md): inherited Swiftfin engineering conventions.
- [Launch assets](marketing/README.md): screenshots, video, Shorts, credits and reproduction.
- [Website](website/README.md): static GitHub Pages build and publication instructions.

The player core accepts source-independent media, chapters and tracks. Local
files own their sandbox access and local history. The Jellyfin adapter owns
server models, streaming negotiation and server progress reporting. The engines
and playback UI are shared. Local playback doesn't create a Jellyfin progress
session; an already connected server may continue its normal browsing activity.

## License and acknowledgements

kurtz source is under the [Mozilla Public License 2.0](LICENSE.md), retaining
Swiftfin's license and source notices. Thank you to Swiftfin, Jellyfin, VideoLAN,
mpv and the other projects in the [third-party notices](Shared/Resources/KurtzThirdPartyNotices.txt),
also available inside Mac Settings.

Bundled playback binaries retain their own licenses. The release includes the
GPL-enabled mpv build; the combined binary is provided under GPL-3.0-or-later,
with kurtz/Swiftfin source notices retained under MPL-2.0. See the
[distribution source and license record](docs/release/README.md) for matching
engine sources, patches, component recipes and the release source bundle.

Sintel © copyright Blender Foundation / [durian.blender.org](https://durian.blender.org/),
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Detail recommendations
also show Big Buck Bunny © 2008 Blender Foundation and Caminandes: Gran Dillama
© Caminandes team / Blender Foundation, (CC) caminandes.com (CC BY-SA 3.0).
The detail screenshot composition is CC BY-SA 3.0. Frames are cropped/resized
for demo artwork. See [media sources and licenses](marketing/sources-and-licenses.md).
