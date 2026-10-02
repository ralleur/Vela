# Vela installer artwork

A graphite background with a flowing periwinkle/glass ribbon, small luminous
spheres and a subtle drag arrow. The Finder window contains only two visible
items: the real Vela app and an Applications-folder link.

`background@2x.png` is an opaque RGB image, 1536 × 1024 pixels. It was created
with the built-in **Imagegen** tool, then refined for opacity and readable
Finder labels. [The complete prompt sequence](final-prompts.txt) is retained.
The artwork is new; it contains no movie still or fabricated app icon.

## Finder layout

- Window: 768 × 512 points; no sidebar, toolbar or path bar.
- Icons: 112 points, centered at `(224, 230)` and `(544, 230)`.
- Small silver-blue surfaces sit behind Finder's black filename labels.
- The volume uses Vela's existing app icon.
- A multi-resolution TIFF includes the 1× and 2× image representations.

Finder draws the two icons and their labels; they are not part of the bitmap.
The Applications link resolves to `/Applications`. Open-source notices remain
available in the app, and full distribution records are retained under the
hidden `.licenses` directory. There are no extra visible text documents.

## Rebuild

```sh
python3 -m venv build/dmg-tools
build/dmg-tools/bin/python -m pip install -r Tools/vela/dmg-requirements.txt
build/dmg-tools/bin/python Tools/vela/package-dmg.py \
  build/release/notarized/Vela.app --output build/release/installer --revision 2
```

The builder refuses to overwrite an existing image or working directory.
`style-dmg.py` writes Finder metadata using `ds_store` and `mac_alias`, following
the [dmgbuild settings format](https://dmgbuild.readthedocs.io/en/latest/settings.html).
Build dependencies are pinned and are not shipped inside Vela.

The app's signed contents stay unchanged. In particular, no FinderInfo
attribute is added to the app bundle, which would invalidate strict signature
verification. The image is compressed as UDZO with an APFS volume; ASIF is only
an intermediate format on newer build hosts. Package revision 2 identifies the
new installer while the application remains version 0.9.4, build 5.
