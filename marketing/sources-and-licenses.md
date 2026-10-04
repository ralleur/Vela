# Sources, rights and reproduction

Current website screenshots show the actual kurtz 0.9.6 app. The six current
Shorts reuse approved original Vela feature footage, with explicit provenance,
in the kurtz identity. Historical captures retain their original labels. No app
controls or capabilities were painted in or removed. Exports may crop the outer
window/title strip (including the operating system's screen-capture indicator),
resize and compress. Phone crops are identified in the capture manifest.

## Film masters

| Film | Download used | Rights and required credit |
| --- | --- | --- |
| Sintel | [Blender archive MKV](https://download.blender.org/demo/movies/Sintel.2010.1080p.mkv) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); © copyright Blender Foundation / durian.blender.org. [Project terms](https://durian.blender.org/sharing/). |
| Big Buck Bunny (Sunflower) | [Blender archive ZIP](https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_30fps_normal.mp4.zip) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); © copyright 2008, Blender Foundation / www.bigbuckbunny.org. [Project terms](https://peach.blender.org/about/). Sunflower conversion credits remain in the master. |
| Caminandes: Gran Dillama | [Blender archive ZIP](https://download.blender.org/demo/movies/caminandes_gran_dillama.mp4.zip) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/); (CC) caminandes.com / Caminandes team, Blender Foundation. [Reviewed license record](https://commons.wikimedia.org/wiki/File:Caminandes_-_Gran_Dillama_-_Blender_Foundation%27s_new_Open_Movie.webm). The original project domain was not accessible during this audit. Use the documented share-alike terms. |

Only excerpts/frames are published in this package. The entire films and credit
rolls remain in the ignored local masters. Spring was considered but not used;
its original master download required a Studio subscription. The original launch films were silent. The current six feature Shorts use
the original Ralleur/Hauser D and F music masters from the approved production,
with their provenance in each edit. No new third-party track was introduced;
source-film sound is not reused.

## Demo artwork and redistribution

Posters are film-frame crops with original, neutral typesetting made by
`Tools/marketing/prepare-demo.py`. They do not reuse excluded film logos or DVD
covers. Local NFO descriptions were written for this demo. The server is a real,
isolated Jellyfin instance; it has no connection to the user's personal library.

Sintel/BBB-only image exports and their new composition are offered under
CC BY 3.0 with the credits above. Adapted Caminandes posters and compositions
that include them (including library captures and videos) are offered under
CC BY-SA 3.0 with the credits above. Keep these credits and license links when
sharing. This grant covers the new composition and licensed film imagery, not
ownership of macOS UI, third-party marks, kurtz branding or a change to the app's
source license. No endorsement by filmmakers is claimed.

Ready-to-paste video/post credit:

> Demo films: Sintel © Blender Foundation / durian.blender.org; Big Buck Bunny
> © 2008 Blender Foundation / www.bigbuckbunny.org (CC BY 3.0).
> Caminandes: Gran Dillama © Caminandes team / Blender Foundation,
> (CC) caminandes.com (CC BY-SA 3.0). Film frames cropped/resized for this demo.
> This video composition is CC BY-SA 3.0. https://creativecommons.org/licenses/by-sa/3.0/

## App, marks and fonts

- kurtz wordmark and symbol: clean vector paths in `Tools/marketing/build-kurtz-brand.cjs`,
  based on the owner's supplied concept, preserved in `brand/reference`.
  Graphite `#1F1F1F`, Ivory `#FAF8F1`, Electric Yellow `#FFE600`.
- DMG illustration: generated with Imagegen from the owner's branding direction;
  prompt and retained source are in `marketing/dmg`. Exact vector mark and local
  Sora text are composited reproducibly over that illustration.
- Swiftfin: [upstream](https://github.com/jellyfin/Swiftfin), MPL-2.0. Existing
  LICENSE.md, headers and acknowledgements retained. Prominent prose credit in
  README, site, main film and a dedicated Short. No upstream logo used as ours.
- Jellyfin: [branding policy](https://jellyfin.org/docs/general/contributing/branding/).
  Distinct kurtz name/mark; text describes interoperability; explicit independence.
- Playback libraries: existing [notices](../Shared/Resources/KurtzThirdPartyNotices.txt).
  The current `Libmpv-GPL` binary and libVLC need their own release/source review.
  A marketing asset review is not binary distribution clearance.
- App, website and current media: local Sora Regular, SemiBold and Bold,
  distributed under the SIL Open Font License in `Shared/Resources/Fonts` and
  `website/assets/fonts`. The pinned source is recorded in `brand/README.md`.
  Historical launch artwork used system/Arial fonts and remains unchanged.
- Hauser supplies the approved editorial standard and original Ralleur music.
  No Hauser product logos or screenshots are used as kurtz branding.

## Storage

`build/launch/media`: downloaded masters and contact sheets.
`build/launch/server`: private demo server state and credentials; ignored.
`build/launch/raw`: unedited captures, including rejected takes; ignored.
`build/launch/exports`: final MP4 delivery files; ignored to avoid Git bloat.
`marketing/screenshots`, `marketing/thumbnails`, `marketing/video`: compact
public images, captions, scripts, manifests and edit decisions.
`website/assets`: optimized public exports only.

Do not upload the raw directory wholesale. Some rejected early takes include
unrelated desktop material and are excluded from every public export.
