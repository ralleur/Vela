# Vela project website

Static HTML, CSS and one small progressive-enhancement script. No npm install,
framework, external fonts, analytics or build-time network access.

```sh
python3 Tools/marketing/build-site.py
python3 -m http.server 4173 --directory build
```

Open `/site/` for a preview. The same output also works under `/Vela/`: every
internal URL is relative. Canonical and OpenGraph URLs use the repository's
case-sensitive address, `https://ralleur.github.io/Vela/`.

The GitHub Pages workflow validates and uploads **only `build/site`**. Raw film
masters, screen recordings, server data and credentials live under ignored
`build/launch`, never in the Pages artifact. Optimized public screenshot assets
are committed; re-export only when the captures change.

Publishing uses GitHub Pages with GitHub Actions. Commit and push changes to
`vela`; matching changes trigger **Project site**, which can also be dispatched
manually. The workflow is scoped to `ralleur/Vela`. Publish a versioned release
asset before updating the public download links. The current installer is
`Vela-0.9.4-macOS-universal-r3.dmg` on release `vela-0.9.4`.

Responsive image choices include a portrait library crop. The comparison uses
an intentionally scrollable full-player image on narrow screens so its controls
remain legible. The site works without JavaScript; the alternate capture is a
normal link. Motion is limited to anchor scrolling and honors reduced motion.
