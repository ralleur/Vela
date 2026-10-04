# kurtz brand

The product name is always **kurtz**, including sentence starts, app bundles,
installer volumes, download names and navigation. The owner's concept sheet is
preserved unchanged in `reference/kurtz-branding-reference.jpg` (4 October 2026).

The wordmark uses a custom curled z; the separate curled symbol carries two
Electric Yellow rays. Both were redrawn as clean paths from the supplied design.
Use the dark variant on Graphite and the light variant on Ivory. Never substitute
plain typeset text for the wordmark when the actual mark is appropriate.

| Token | Value |
| --- | --- |
| Graphite | `#1F1F1F` |
| Ivory | `#FAF8F1` |
| Electric Yellow | `#FFE600` |
| Typeface | Sora Regular, SemiBold, Bold |
| Claim | Good videos go further. |

Sora is bundled locally under the SIL Open Font License; the upstream source is
[sora-xor/sora-font](https://github.com/sora-xor/sora-font), pinned at
`7f9a9c5d0ccd1c099cfac420aa27133df1c5fdc4`. Full license text accompanies the
Apple resources and web fonts. No remote font service is required.

```sh
npm install --prefix build/rebrand-kurtz/tools @resvg/resvg-js@2.6.2
node Tools/marketing/build-kurtz-brand.cjs
node Tools/marketing/build-kurtz-dmg.cjs
python3 Tools/marketing/build-site.py
```

The vector generator supplies the app icon variants, player mark, website mark,
tvOS layered icons and Top Shelf images. Source geometry is shared; rendering is
deterministic. The app retains system fonts for platform controls and symbols;
Sora supplies branded headings and default prose. Yellow controls on light
surfaces use Graphite where necessary for legibility.

Historical Vela releases and original captures keep their true names and hashes.
They are not current kurtz promotional assets. Rebranding does not alter their
provenance or grant publication rights for unrelated content.
