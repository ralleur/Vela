# Launch claim audit — 2 October 2026

> This records the initial source-preview launch pass. The subsequent signed
> and notarized 0.9.4 DMG is documented in the [release notes](release/0.9.4.md).

Audit target: Vela 0.9.4 (Mac build 5), working tree based on
`10c4bdb693999b6dcc9744cb3f739c8a3da42182`, branch `vela`.
The existing engineering changes were uncommitted on arrival. Captures represent
that working tree, not the public 0.9.3 release. Initial and final source fingerprints are
recorded with the capture manifest. Two intermediate captures are explicitly
identified; their visible content did not change with the later player fix.

## Evidence and claim boundaries

| Area | Source/evidence | Public wording / limit |
| --- | --- | --- |
| Mac | Catalyst target; built Info.plist declares macOS 15.6 | Modern macOS video player; oldest OS not requalified |
| Apple TV | `Swiftfin tvOS`, tvOS 26.1; existing simulator build evidence in VELA.md | Jellyfin on Apple TV; no Mac/TV feature parity claim |
| iPhone/iPad | Inherited iOS 18.6 target, also used by Catalyst | Do not announce a separately qualified Vela mobile release |
| Local opening | `VelaLocalFiles`, `VelaFileMenu`, Info.plist document types | Open Video, Finder Open With, file-open events; MKV/MP4/MOV |
| Drag/drop | `.onDrop` and URL handling in VelaLocalFiles | Implemented; distinguish gesture verification from code review |
| Source boundary | `Playback/Core`, `LocalMediaPlayerItem`, `JellyfinMediaPlayerItem` | One player for local files and Jellyfin; no server required for local |
| Engines | VLC automatic local default, existing mpv alternate, inherited AVPlayer | No all-codec/HDR/Atmos/passthrough guarantee |
| Subtitles | Engine tracks, SRT/ASS/SSA/VTT sidecars, timing menus | Embedded and external subtitles; discovery depends on sandbox access |
| Audio | Track IDs/memory and timing menu | Select available audio tracks; no universal format claim |
| Speed | Shared rate API; menu 0.5–2×, Mac shortcuts 0.25–4× | Adjustable playback speed |
| Resume | Local history/bookmarks, per-file track choices; server reporting adapter | Local progress stays on Mac; Jellyfin retains server progress |
| Fullscreen | VelaMacPlayer, Cmd-F and double-click | macOS fullscreen, controls hide during playback |
| Mini player | Runtime AppKit window bridge | Floating mini player; **not system Picture-in-Picture** |
| Jellyfin | Swiftfin browsing/detail/provider, segment and episode supplements | First-class client foundation; metadata-dependent episode features |
| Free | No StoreKit, advertising, paywall or purchase SDK calls found in app code | Free/open source, no subscription, no IAP, no Pro tier |
| Privacy | Local source has no server progress reporter | No local account requirement; no blanket network-free claim |
| Distribution | GitHub API release inspection | 0.9.3 beta ZIP exists, development-signed and not notarized; 0.9.4 source build only |
| Source license | LICENSE.md and source headers | MPL-2.0; retain upstream notices |
| Libraries | VelaThirdPartyNotices.txt, pinned packages | Binary distribution review remains open; especially `Libmpv-GPL` |

## Independently executed for this package

- Mac Catalyst Debug build: `xcodebuild -workspace Vela.xcworkspace -scheme
  Swiftfin -configuration Debug … build` succeeded on Xcode 27.0.
- Strict, deep signature verification passed on the resulting bundle.
- `swift test --package-path Tools/VelaLogicTests`: 44 tests passed.
- Native Open Video selected and played the full licensed Sintel MKV.
- Space pause/resume, timeline seek, controls show/hide and Cmd-F fullscreen
  were observed in the running app. Matching clean/controls stills use 11:30.
- Embedded subtitle and audio choices were enumerated by the actual player.
- Further live capture evidence and dimensions are in the media manifest.

Prior phase test evidence in VELA.md remains useful, but is not relabeled as new
launch testing. There is no claim of complete codec coverage, a packet capture,
a new physical Apple TV pass, or a distribution legal clearance.

## References and attribution decisions

- [Hauser repository](https://github.com/ralleur/hauser) and
  [site](https://ralleur.github.io/hauser/): reviewed the real-use narrative,
  screenshot/state comparisons and visible limitations. No visuals copied.
- [Maker channel](https://www.youtube.com/channel/UC2004JSW91qR6YOA-pxPFFQ):
  public metadata exposed the 1:07 Hauser product video, “hauser: Your home, as
  it really is – your smart home as a picture (Apple Home & Home Assistant)”.
  The Shorts feed did not expose reliable individual titles. No claim that all
  channel videos were watched or their pacing benchmarked.
- [Swiftfin](https://github.com/jellyfin/Swiftfin) provides the Apple Jellyfin
  client foundation; name and link are prominent in README, site and video.
- [Jellyfin branding policy](https://jellyfin.org/docs/general/contributing/branding/)
  permits interoperability descriptions, requests distinct names/marks and
  prohibits false affiliation. Use Vela's existing mark; describe Jellyfin in
  text. No Jellyfin or Swiftfin logo is repurposed.
- [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/) is retained; source headers,
  license and library notices are not replaced by marketing asset licenses.

See [sources and licenses](../marketing/sources-and-licenses.md) for film rights.

## Capture-discovered fixes and final runtime checks

The existing Mac profile control opened Settings but did not expose the account
route reliably. The Catalyst profile control now opens an ordinary menu with
Settings and Accounts and Servers. English/German labels were added. The actual
menu was used to connect the isolated Open Cinema server and Viewer account.

A local/server transition could replace the tab controller after the player
attached, leaving Home/Search/Media over the video. The player now reapplies
its existing tab-bar hiding when updating its window title, retaining the
original hidden state only once for restoration. A fresh build and actual
local → library → Jellyfin playback confirmed hidden navigation chrome; closing
the player restored the library toolbar. This is a product fix, not retouching.

The capture pass observed Jellyfin home/detail, real server playback and Continue
progress; native local MKV opening; seeking; pause/resume; embedded subtitle
choices; fullscreen and clean controls. Both live clips were recaptured after
the chrome fix. The final 44-test run and strict deep signature check passed.
Physical Apple TV, drag/drop gestures, mini-player behavior and all codec variants
were not newly exhaustively exercised by this launch pass; code/prior-phase
coverage is identified separately above and in VELA.md.

## Distribution follow-up — 2026-10-02

The audited 0.9.4 (5) source was built in Release for arm64 and x86_64, exported
with Developer ID signing, accepted by Apple notarization and packaged as a
universal DMG. The app started from the final image and played a local MKV.
The public download was fetched again and its SHA-256 matched.

[Release notes](release/0.9.4.md) record remaining beta qualification limits;
[publication.json](release/publication.json) records the release artifacts and
successful GitHub Pages deployment. The website now links to this installer.
