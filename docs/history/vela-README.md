# Vela launch package

Positioning: **A modern macOS video player with Jellyfin built in.**
Headline: **Just watch the video.**
Supporting line: **Your files. Your Jellyfin library. One player.**

The assets show the working **0.9.4 (5) Mac source build**, based on commit
`10c4bdb693999b6dcc9744cb3f739c8a3da42182` plus existing engineering changes and
two capture-discovered Mac UI fixes. They do not represent the public 0.9.3 ZIP.
The current public DMG is [Vela 0.9.4 Beta](../docs/release/0.9.4.md).
Read the [claim audit](../docs/product-audit.md) and [rights record](sources-and-licenses.md).

## Deliverables

| Asset | Location |
| --- | --- |
| Curated real screenshots | [screenshots/macos](screenshots/macos/) — eight JPEGs |
| Capture sizes, crops and raw hashes | [screenshots/manifest.json](screenshots/manifest.json) |
| Source/build fingerprint | [screenshots/build.json](screenshots/build.json) |
| Main film: script, edit decisions, captions | [video/product](video/product/) |
| Eight complete Shorts, captions and three future concepts | [video/shorts/production.md](video/shorts/production.md) |
| Main, eight vertical and social thumbnails | [thumbnails](thumbnails/) |
| Launch post and editorial choices | [copy/positioning.md](copy/positioning.md) |
| Final report and validation | [launch-report.md](launch-report.md) |
| Website | [../website](../website/) |

Final video delivery files are in ignored `build/launch/exports` on the production
machine. Keep them outside Git; upload those reviewed files individually when
publishing. All are silent H.264, 30 fps, yuv420p, fast-start MP4:

- `vela-product-60s.mp4` — 1920×1080, 60 seconds.
- `vela-short-03-disappearing-ui.mp4` — 1080×1920, 18 seconds.
- `vela-short-04-local-and-jellyfin.mp4` — 1080×1920, 20 seconds.
- `vela-short-05-whole-app-free.mp4` — 1080×1920, 18 seconds.
- `vela-short-06-built-on-swiftfin.mp4` — 1080×1920, 22 seconds.

Each has a ready-to-paste description beside it, and its SRT/VTT captions are
in `marketing/video`. The master is intentionally understandable without sound;
there is no external music or synthesized narration to license. Held captures
and live playback are distinguished in the edit decisions. No UI interaction
is animated or fabricated. The two live excerpts are actual local and Jellyfin
playback recordings. The clean/controls comparison holds real matching stills.

## Reproduction

Use Python 3.9+ with Pillow and `ffmpeg`/`ffprobe` on PATH. Raster typography
uses installed macOS Arial and Arial Bold; no font binaries are distributed.
The website itself needs only standard-library Python.

1. Build the current app using [BUILDING.md](../docs/BUILDING.md). Retain the exact
   source tree and fingerprint with the recordings.
2. Download the three masters (save the Sintel MKV as `Sintel.mkv`) from [sources-and-licenses.md](sources-and-licenses.md)
   into ignored `build/launch/media`; unzip the two MP4 archives. Run
   `python3 Tools/marketing/prepare-demo.py`. This creates neutral posters, NFOs
   and the three-film library; it does not contact a personal Jellyfin server.
3. For new Jellyfin captures, use a separate official Jellyfin server with a
   local-only listener, a throwaway Viewer account, external metadata downloads
   disabled, and only `build/launch/library` indexed. Import the generated NFO
   and poster/backdrop files. The captured server used loopback port 18096.
   Server credentials and cache belong only under ignored `build/launch/server`.
4. Open the Debug Vela app. Use English app language and disable the optional
   player watermark for the clean comparison. Use the native Open Video panel
   and a clean folder containing the three films. Do not change Finder defaults.
5. Record the actual app window. Find its window ID with a read-only
   `CGWindowListCopyWindowInfo` listing filtered to Vela; then use:

   ```sh
   screencapture -x -o -l WINDOW_ID build/launch/raw/capture.png
   screencapture -x -o -v -V 9 -l WINDOW_ID build/launch/raw/capture.mov
   ```

   Inspect each result: fullscreen transitions change the capture dimensions,
   and early takes may include unrelated desktop content. Never upload the raw
   directory wholesale. The selected full-screen recordings are 3840×2192;
   the renderer excludes the 32-pixel outer title strip. The windowed hero and
   matching controls are native 1366×614, not upscaled Retina originals.
6. Keep the raw names/crops listed by `export-images.py`. Run:

   ```sh
   python3 Tools/marketing/export-images.py
   python3 Tools/marketing/prepare-video-plans.py
   python3 Tools/marketing/render-videos.py
   python3 Tools/marketing/build-site.py
   ```

   `render-videos.py --only product` or `--only 03` renders a single edit;
   `--thumbnails-only` exports all nine video thumbnails. Encoding is libx264,
   CRF 18, fast preset, 30 fps, yuv420p, no audio, fast-start MP4. Main is 16:9;
   Shorts are 9:16. Headlines stay in the upper safe area; source/CTA text is
   inside the central 84…996 pixels. Real player detail crops preserve their
   relative UI geometry. The footer credits are repeated in upload descriptions.
7. Inspect the decoded contact sheets in `build/launch/render/<name>` and play
   each final MP4. The renderer checks duration and fully decodes each file.
   Keep the resulting render manifest and SHA-256 hashes with the delivery.
8. Preview `/site/` with `python3 -m http.server 4173 --directory build`. Review
   desktop, laptop, tablet and phone layouts before using the Pages workflow.

Raw screen capture itself is a deliberate manual/UI step; it is not recreated
from a fake app mockup. Downloaded film masters total well over a gigabyte and
are deliberately excluded from the public repository and Pages artifact.
