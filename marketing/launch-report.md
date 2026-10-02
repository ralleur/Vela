# Vela launch delivery — 2 October 2026

> This records the initial source-preview launch pass. The subsequent signed
> and notarized 0.9.4 DMG is documented in the [release notes](../docs/release/0.9.4.md).

The public presentation package is implemented locally. Nothing was pushed,
published to GitHub Pages, released or uploaded to social accounts. Existing
uncommitted engineering work is preserved. Public copy is English.

## 1. Positioning

**A modern macOS video player with Jellyfin built in.** The story starts with the
activity: a local file and a Jellyfin film lead to the same player. Everyday
comfort and unobtrusive controls carry the argument. No new decoding technology,
universal codec compatibility or native system Picture-in-Picture is claimed.

## 2. Headline and supporting copy

**Just watch the video.**

**Your files. Your Jellyfin library. One player.**

[Copy sheet](copy/positioning.md) includes launch text and editorial boundaries.

## 3. README

[README.md](../README.md) now leads with the definition, real clean player and
local/Jellyfin experience. It gives Swiftfin prominent credit, explains free/open
source, and distinguishes the 0.9.4 source preview from the older public 0.9.3 ZIP.
Build/platform/contribution links remain easy to find. Detailed build guidance
is in [BUILDING.md](../docs/BUILDING.md); the existing VELA.md was preserved.

## 4. Website

[website](../website/) contains static HTML, CSS and a small accessible image
comparison script. Narrative: hero → one activity → local files → Jellyfin →
controls disappear → comforts → Swiftfin → whole app free → beta/platforms.
The dedicated credits page documents licenses and independence. Existing Vela
artwork, navy palette and blue accent define the identity. No framework, npm
install, remote fonts, analytics, autoplay or build-time network dependency.
Canonical/social URL is prepared for `https://ralleur.github.io/Vela/`.

## 5. Screenshot inventory

All are real app/macOS captures. No UI has been painted in or removed.

| Export in `screenshots/macos` | Public size | Notes |
| --- | --- | --- |
| `player-clean.jpg` | 1366×614 | Real window, matching Sintel frame, controls hidden |
| `player-controls.jpg` | 1366×614 | Same frame, actual controls visible |
| `local-workflow.jpg` | 880×448 | Native Open Video panel; selected MKV |
| `jellyfin-home.jpg` | 823×755 | Continue and three licensed films |
| `jellyfin-detail.jpg` | 823×755 | Actual Sintel detail, Play and recommendations |
| `subtitles.jpg` | 800×642 | Detail crop of real embedded/external subtitle menu |
| `mac-window.jpg` | 1366×614 | Named reuse of the clean window, not another capture |
| `fullscreen.jpg` | 3840×2192 | Native full-screen capture including outer window extent |

[Manifest](screenshots/manifest.json) records raw sizes, crops, phases and SHA-256.
The 1366-pixel window images are native captures, not artificially upscaled
Retina files. The full-screen capture and selected live recordings are 3840
pixels wide. WebP variants include a readable portrait library crop. Initial
and final build fingerprints distinguish captures around the two small UI fixes.

## 6. Demo media and rights

Sintel and Big Buck Bunny: Blender Foundation, CC BY 3.0. Caminandes: Gran Dillama:
Caminandes team / Blender Foundation, documented CC BY-SA 3.0. Masters came from
Blender's official download archive. Posters use film-frame crops and original
neutral typography. Source links, adaptation notes and required credits are in
[sources-and-licenses.md](sources-and-licenses.md). Compositions containing
Caminandes are offered under CC BY-SA 3.0. No commercial-film posters, external
music or private library images appear in the public exports.

## 7. Swiftfin and library attribution

Swiftfin is named and linked prominently in README, website, the main film and a
dedicated Short. Existing MPL-2.0 license and source notices remain. The prose
explains the inherited Apple/Jellyfin foundation and Vela's broader Mac role.
Independence from Jellyfin/Swiftfin is explicit. Playback library notices are
linked; a new binary release still requires its own GPL/LGPL/source review.

## 8. Main product film

**Rendered:** `build/launch/exports/vela-product-60s.mp4` — 60 seconds,
1920×1080, H.264, 30 fps, yuv420p, fast-start, intentionally silent.

[Exact script and shot list](video/product/production.md), editable JSON,
SRT/VTT and thumbnail are complete. The film combines held real UI captures
with two actual recordings: local MKV and Jellyfin playback. Clean cuts and
on-screen text make it understandable without audio. Final title includes the
repository, source-preview status and Swiftfin credit. The upload description
contains the complete media credits. The reviewed raw live clips are separately
available as `local-playback-source.mov` and `jellyfin-playback-source.mov` in
the local export directory.

## 9. Shorts

[All eight production plans](video/shorts/production.md) include a distinct hook,
script, timings, exact shots/assets, framing, title, description, hashtags and
SRT/VTT. All eight have finished thumbnail images.

| # | Concept | Status |
| --- | --- | --- |
| 01 | Why choose an app? | Complete plan, captions, thumbnail; shots captured |
| 02 | Just play the file / VideoLAN credit | Complete plan, captions, thumbnail; shots captured |
| 03 | Disappearing UI | **Rendered**, 18 s |
| 04 | Local + Jellyfin | **Rendered**, 20 s |
| 05 | The whole app is free | **Rendered**, 18 s |
| 06 | Built on Swiftfin | **Rendered**, 22 s |
| 07 | Choose your default player | Complete plan/captions/thumbnail; Finder Get Info pickup remains specified |
| 08 | Small comforts | Complete plan, captions, thumbnail; shots captured |

Rendered Shorts use `vela-short-<number>-<slug>.mp4` in the export directory,
1080×1920 with the same codec settings. The four priority topics requested are
all rendered. Three additional distinct follow-ups are specified separately.

## 10. Thumbnails

[thumbnails](thumbnails/) contains a 1280×720 product-film thumbnail, eight
1080×1920 Short covers and a 1200×630 social preview. They use the real Vela
mark, one brief idea and a genuine product capture crop. No generated app UI.

## 11. Build and validation

- Mac Catalyst Debug build succeeded with Xcode 27.0; strict deep signature
  verification passed. Version 0.9.4 (5), minimum macOS 15.6, arm64 capture host.
- 44 Swift logic tests passed: 33 Vela tests and 11 playback-core tests.
- Actual local opening, playback, pause/resume, seek, menu choices, fullscreen,
  clean controls, Jellyfin browsing/playback and Continue state were observed.
- Two small Mac fixes were built and runtime-verified: accessible profile
  account menu, and re-hiding navigation chrome after source changes.
- Static build validates two HTML pages, assets, anchors, alt/dimension
  attributes, base-path-safe links and size limits. Output: `build/site`.
- Chrome QA at 1440×1000, 1280×800, 768×1024 and 390×844: no page overflow;
  desktop/laptop/tablet/phone screenshots reviewed. Comparison click/Enter,
  library expansion and credits navigation passed. Mobile library image uses
  the 430×610 source. No browser errors/warnings observed.
- Main text contrast 9.36:1, muted text on the lighter panel 8.19:1, blue labels
  7.24:1. Reduced-motion CSS and the no-JavaScript fallback were reviewed.
- Website source plus all assets is about **440 KB**; public marketing files
  are about **3.3 MB**. Existing Git packs are 74.41 MiB. Large film masters and
  raw takes remain ignored; the Pages artifact contains only the staged site.
- All five MP4s have verified duration/codec/dimensions, decoded without errors,
  and were reviewed through extracted scene contact sheets. See
  [render manifest](video/render-manifest.json) and [web QA](validation.json).
- The initial source-change whitespace check passed. Third-party notices retain
  upstream formatting. No user code was reset. The release source is committed
  and tagged as `vela-0.9.4`.

[GitHub Pages workflow](../.github/workflows/pages.yml) is deployed. Actions are
SHA-pinned; deployment permissions are limited to the deployment job.

## 12. Publication

Published on 2026-10-02:

- [Project website](https://ralleur.github.io/Vela/), with a working direct DMG
  download in the hero and installation section.
- [Vela 0.9.4 Beta release](https://github.com/ralleur/Vela/releases/tag/vela-0.9.4):
  a 140,288,000-byte universal Mac DMG, SHA-256, matching source bundle and its
  SHA-256. The app is Developer ID signed, notarized and stapled.
- Release source commit `f343155bf247e5881d6f4b1da8bfc660207a958d` on `vela`,
  tagged `vela-0.9.4`.
- [Successful Pages deployment](https://github.com/ralleur/Vela/actions/runs/37048480493).
  The public HTML matches the source; all 19 deployed files returned HTTP 200.
  A fresh public DMG download matched the original SHA-256.
- The exact DMG app passed bundle/architecture/sandbox/signature verification,
  Apple-ticket validation and Gatekeeper assessment, and played a local MKV.

See [release notes](../docs/release/0.9.4.md) and the machine-readable
[publication record](../docs/release/publication.json). The GitHub repository's
homepage now points to the live site.

The remaining channel-publication step is to upload the reviewed MP4s, matching
captions and thumbnails using the supplied titles/descriptions and film credits.
No social-account upload was performed.

The local `build/launch/Vela-launch-media.zip` bundles the five final videos,
captions, descriptions, public screenshots, thumbnails and production notes.
It deliberately excludes private server data and rejected raw takes.

## 13. Explicit limits and cleanup

The website, README, release and DMG are public. No social upload, new physical
Apple TV qualification or exhaustive codec test is claimed. The Intel slice
is included; runtime qualification was on Apple silicon.
The non-priority default-player Short has an exact Finder pickup left; Finder
associations were not changed. The main film and all four priority Shorts were
produced, so there is no remaining render/tooling blocker for that launch batch.

The temporary local Jellyfin process was stopped after capture. The original
Vela server/account selection was restored, along with System language and the
optional window logo. The separate Open Cinema entry and demo files remain
available for future capture; existing accounts/history were not wiped.
