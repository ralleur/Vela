# Vela web wordmark

`vela-wordmark.svg` follows the approved lettering in the DMG background:
the rounded V, blue-dot accent and matching lowercase letterforms.
It is intended for dark backgrounds.

`Tools/marketing/export-wordmark.py` traces the approved lettering into two
flat-color SVG paths and writes the brand master and website copy. The source
is `marketing/dmg/background@2x.png`; Pillow is only needed to regenerate the
vector. The website needs no font file or build-time image dependency.

```sh
python3 Tools/marketing/export-wordmark.py
python3 Tools/marketing/build-site.py
```

The site header displays the wordmark at 126 pixels wide on desktop and
108 pixels on mobile. The home link retains its accessible name. Desktop at
1440 pixels and mobile at 320 pixels were visually checked with no overflow.
