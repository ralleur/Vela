# kurtz installer artwork

The installer uses the owner's Graphite/Ivory/Electric Yellow palette, the exact
vector wordmark, Sora, and the claim “Good videos go further.” Its softly lit curl
illustration was generated with the built-in Imagegen tool; the original is
`kurtz-background-art.png`. `build-kurtz-dmg.cjs` composes the checked-in vector
mark and font over that artwork. `background.svg` and `background@2x.png` are the
reproducible 1536 × 1024 source and Finder background.

Finder draws the real app icon and Applications link. No fake app UI is baked
into the background. The window is 768 × 512 points, with 112-point icons at
(244, 216) and (524, 216). Only `kurtz.app` and `Applications` are visible.
License/source records stay under `.licenses`; the app exposes its notices too.
The signed app is never modified when styling the volume.

Rebuild with the build-only environment containing `Tools/kurtz/dmg-requirements.txt`:

```sh
node Tools/marketing/build-kurtz-dmg.cjs
build/dmg-tools/bin/python Tools/kurtz/package-dmg.py \
  build/release/0.9.6/notarized-ship/kurtz.app \
  --output build/release/kurtz-0.9.6/installer
```

The packager requires a universal, Developer-ID-signed app with a stapled ticket
for production and refuses to overwrite an existing output. Legacy artwork and
release images remain in Git history and the original release artifacts.
