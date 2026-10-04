# kurtz

Good videos go further. A free, independent Swiftfin fork by Ralleur for Mac,
iPhone/iPad and Apple TV. The product name is always lowercase.

The Mac app opens local video files and Jellyfin libraries. It includes recent
files/resume, audio/subtitle selection, external subtitles, speed, fullscreen,
a floating mini player, language presets and metadata-based episode prompts.
VLC is the default local engine; mpv is available as an alternative. Compatibility
depends on the media and platform. Episode prompts require server metadata.

The current Mac beta is **0.9.6 (8)**. Mobile/TV source builds remain release
preparation, without a public App Store or TestFlight release.

- [Build, install and validate](docs/BUILDING.md)
- [Release, license and matching-source record](docs/release/README.md)
- [Verified product status](docs/product-audit.md)
- [Apple release gates](docs/release/apple-release-plan.md)
- [Brand masters, colors and Sora licensing](marketing/brand/README.md)
- [Upgrade compatibility](docs/rebranding-kurtz.md)
- [Historical engineering notes](docs/history/VELA.md), preserved as Vela history;
  their version claims and old commands are not the current release procedure.

`com.ralleur.vela` and `com.ralleur.vela.mac`, existing preference/keychain keys
and `vela://` are retained so the rename keeps installations and sign-ins intact.
New links use `kurtz://`. The Mac installer contains `kurtz.app` on volume `kurtz`.

## Maintenance

Owned additions live in `Shared/Kurtz`, `Swiftfin/Kurtz` and `Swiftfin tvOS/Kurtz`.
`Tools/kurtz` contains build/release tools; `Tools/KurtzLogicTests` contains the
46 focused playback and product-logic tests. The Xcode project and schemes keep
Swiftfin's engineering names. The active local checkout keeps its compatibility
path; the public repository is `ralleur/kurtz`.

The existing monthly integration automation retains its schedule and permissions.
It selects the penultimate stable Swiftfin release, works in a separate worktree,
and requires all original build/runtime checks before merging its PR.
