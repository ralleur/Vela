# Vela growth series · 3 October 2026

Twenty English Vela Shorts, using Hauser only as the pacing and editing reference.

- [Strategy](STRATEGY.md): audience, creative rationale, first publication wave, measurement and sources.
- [Beat treatments](BEATS.md): each hook, alternative hook, proof, audience and exact shot timings.
- [Editable manifest](series.json): the generated composition inputs.
- [Results worksheet](RESULTS.csv): empty 48-hour / 7-day observations, not fabricated performance data.
- `source/`: retained Remotion film, CSS, registration, preparation and export code.
- `render-manifest.json`: actual final-file metadata, hashes, full-decode checks and audio measurements, produced after rendering.

## Delivery

Local final files: `build/launch/exports/vela-shorts-en/`.

`INDEX.html` previews all 20 videos and can isolate the first three seconds. Each
MP4 has an English SRT and description with film/source credits. `UPLOAD.csv`
contains ready-to-copy titles and descriptions. `HOOKS-20.jpg` is the visual index.
The final files are not uploaded or published by these tools.

## Working renderer

`build/launch/vela-growth-20/` is the local Remotion project. It reuses the
installed Remotion 4.0.527 runtime via its `node_modules` symlink. If that runtime
is moved, supply an equivalent installation; don't commit its binaries or the
large raw captures. The public links point to curated Vela screenshots, Vela
branding and existing original Hauser music. Prepared moving clips are real
local and Jellyfin captures from `build/launch/raw/*-playback-final.mov`, cropped
only to remove the outer 32-pixel capture/window strip.

To change the stories, edit `Tools/marketing/vela-growth-series.py`. Regenerating
writes series manifests, captions and descriptions; an existing results worksheet is
preserved. Copy edited retained renderer
sources into the working renderer's `src/` (or its root for the two scripts).
The already rendered MP4s are skipped. Remove only the matching local final MP4
and `out/Vnn-silent.mp4` when intentionally re-rendering that creative.

```sh
python3 Tools/marketing/vela-growth-series.py
python3 build/launch/vela-growth-20/prepare.py
node build/launch/vela-growth-20/render.mjs render
python3 Tools/marketing/validate-vela-series.py
python3 Tools/marketing/vela-series-gallery.py
```

A focused render uses `node .../render.mjs render V07`; a focused recheck after
an existing complete manifest uses `python3 Tools/marketing/validate-vela-series.py V07`.
`stills` in place of `render` makes frames 0, 36 and 75 for opening inspection.

## Provenance and limits

Vela source/feature evidence is the current README, claim audit and 0.9.4 release
notes. Screenshots are the curated Mac capture set, with provenance in
`marketing/screenshots/manifest.json`. Still comparisons and editorial focus
outlines do not invent app interaction or claim measured latency. No personal
Jellyfin library or unreviewed raw take is included.

Music: existing original Hauser ACE-Step tracks B/D/E/F from
`/Users/ai/workspace/hauser-promo/video/public/music`; matching music project and
metadata are in `hauser-promo/music`. No third-party placeholder tracks or source
film sound are used. Music is trimmed, faded and normalised around −14 LUFS.
The final export is 1080×1920, 30 fps, H.264 yuv420p BT.709 with stereo AAC.

Film credits and CC BY-SA 3.0 composition terms follow
`marketing/sources-and-licenses.md` and are included in each description.
Vela/third-party marks retain their own rights. There is no claim of audience
results, an optimal posting time or guaranteed distribution before publication.
