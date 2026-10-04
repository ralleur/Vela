Vela — Curated Shorts v1 — 4 October 2026

Six locally delivered Shorts, English editorial copy, authentic German series
outlook cards as explicitly requested. 1080x1920, 30 fps, 10/10/10/10/13/13 sec.
Nothing uploaded, scheduled or published.

Open build/launch/exports/vela-curated-v1/INDEX.html for the gallery. Each video
has matching title/description text, SRT and a scene JSON. UPLOAD.csv contains
all six descriptions, destination links and revision names. Keep attribution
with any subsequent publication. VALIDATION.txt identifies exactly which
files and checks this delivery covers; subjective listening is unperformed.

The archive retains the original project-relative layout. Extract it, then
run from its Vela-Shorts-v1 root (macOS with Python 3, Pillow, ffmpeg/ffprobe):

  python3 marketing/video/shorts/vela-curated-v1/source/prepare.py
  python3 marketing/video/shorts/vela-curated-v1/source/render.py
  python3 marketing/video/shorts/vela-curated-v1/source/validate.py
  python3 marketing/video/shorts/vela-curated-v1/source/gallery.py

Edit source/prepare.py to change copy, shots, timing, crops and music selections.
It generates series.json, per-item JSON, SRT and matching descriptions. The
renderer supports an optional clip ID, e.g. render.py C06, for focused changes.
The validator uses the installed ralleur-shorts audit_short.py at its original
/Users/ai/.codex/skills location; adjust that path on another workstation.
Fonts are the macOS Arial/Arial Bold installation and are not redistributed.
The archive includes selected actual capture sources, music masters, Vela
wordmark, actual Jellyfin still, edit scripts and QA evidence. It excludes
rejected takes, application binaries, private server state and credentials.

C01: Actual Skip Intro click and seek; metadata-backed demonstration library.
C02: Actual next-episode click and resulting playback, number/title visible.
C03: Actual air-date card, enlarged without replacing any UI text.
C04: Actual next-season card distinguishes announcement from an unknown date.
C05: Actual controls disappear; clean film result and Saint-Exupery excerpt.
C06: Native local file open and playback, followed by a separate Jellyfin still.

Claims are scoped to demonstrated behavior. These videos do not claim universal
codec support, intro recognition, measured launch speed, a comparative benchmark,
or a changed macOS default-file association. The exact development binary version
at capture was not retained; capture-build.json explains the later inspection.
C06's library still is from the existing 0.9.4 (5) capture set. All six feature
capture sources are from 4 October 2026, Europe/Berlin.

PROVENANCE.json records source hashes. UI is real; crops/zooms are editorial
presentation of the same captured frames. C01 and C05 deliberately hold a
completed result. C03/C04 are passive information cards. C06 removes 0.9 sec of
an app/decoder flash after the opening result and does not make a speed claim.
Music comes from the existing original Ralleur production masters. Source-film
audio is removed. The older marketing/sources-and-licenses.md describes an earlier
silent series; that silence statement does not apply to this new music-backed set.
The individual descriptions are the applicable film/music/metadata credits.
