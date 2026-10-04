# kurtz marketing

**Good videos go further.** A free Mac video player for local files and Jellyfin.
The current identity uses the owner’s curled wordmark, Sora, Graphite, Ivory and
Electric Yellow. The spelling is always **kurtz**.

| Current deliverable | Source |
| --- | --- |
| Reproducible wordmark, symbol, icon variants and social card | [brand](brand/README.md) |
| Actual kurtz 0.9.6 Mac screenshots and capture hashes | [screenshots/kurtz-0.9.6](screenshots/kurtz-0.9.6/) |
| Six approved feature Shorts in the new identity | [kurtz-curated-v2](video/shorts/kurtz-curated-v2/README.md) |
| Installer artwork | [dmg](dmg/README.md) |
| Product copy | [positioning](copy/positioning.md) |
| Product site | [website](../website/README.md) |
| Credits and rights | [sources-and-licenses](sources-and-licenses.md) |

The six final MP4s, captions, descriptions and review gallery are in
`build/launch/exports/kurtz-curated-v2/INDEX.html` on the production machine.
They are 1080×1920, 30 fps, 10–13 seconds and use the original Ralleur music.
They preserve the original approved action/result footage, with its pre-rebrand
provenance explicitly recorded. Captured series dates are labelled examples.
They have not been uploaded or scheduled. Exact-export checks and the remaining
subjective audio-review limitation are in that series’ validation record.

## Reproduction

```sh
npm install --prefix build/rebrand-kurtz/tools @resvg/resvg-js@2.6.2
node Tools/marketing/build-kurtz-brand.cjs
python3 Tools/marketing/export-images.py
node Tools/marketing/build-kurtz-social.cjs
python3 Tools/marketing/prepare-video-plans.py
python3 Tools/marketing/render-videos.py
python3 marketing/video/shorts/kurtz-curated-v2/source/validate.py
python3 marketing/video/shorts/kurtz-curated-v2/source/gallery.py
python3 Tools/marketing/build-site.py
```

Python/Pillow and ffmpeg/ffprobe are required for media exports. Fonts are local
Sora files under `Shared/Resources/Fonts`, with their OFL license. Screenshots
must first be captured from the actual app; their exporter never fabricates UI.
Use the isolated Open Cinema demo library and the credited films, not a personal
server. Keep credentials, film masters and unedited captures in ignored `build`.

## Historical material

The original Vela product film, eight launch Shorts, exploratory twenty-Shorts
campaign, six original feature edits, original screenshots and thumbnails are
preserved at their existing paths. They are historical sources, not current
kurtz publishing candidates. Their dates, names, hashes and old version labels
are intentional. Older generator scripts are in `Tools/marketing/archive-vela`;
the original icon/wordmark is in `brand/archive-vela`. The earlier launch report
and production documents also describe Vela, not a retroactive kurtz release.
