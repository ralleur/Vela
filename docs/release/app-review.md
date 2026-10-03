# Vela — Apple review preparation

Target release: 0.9.6 beta. One iOS application supports iPhone and iPad; tvOS
provides the Jellyfin experience. These are development targets, not approved
App Store listings. Do not upload until the release plan's gates are satisfied.

## Product and review notes

Vela is an independent, open-source fork of Jellyfin's Swiftfin client by
Ralleur. It does not represent or imply endorsement by Jellyfin or Swiftfin.
Upstream authorship and license notices are retained.

On iPhone and iPad, Vela opens to a local-video home. Users can select a video
from Files without creating an account or configuring a server. The app keeps
optional on-device recent files, resume positions and semantic audio/subtitle
choices. It supports external subtitle selection and audio/subtitle timing.
Users can also connect their own Jellyfin server in the same application.

On Apple TV, Vela requires a Jellyfin server. Its Vela-specific features include
language presets, per-series track memory, episode/intro prompts and Continue
rules. The local-file workflow is not available on tvOS. Review the visible tvOS
differentiation separately; iOS features do not establish tvOS differentiation.

App Review must be given a dedicated, reachable Jellyfin test server/account
with licensed test media. Supply credentials privately in App Store Connect,
not in this repository. Keep the service available throughout review. Supply an
openly licensed sample video for testing local playback on iPhone/iPad.

## Suggested review walkthrough

1. Launch iPhone/iPad with no configured server. Open Video selects a video from
   Files. Pause, seek, choose audio/subtitle tracks and add a subtitle file.
2. Close and reopen the recent video. Verify playback resumes. In Settings,
   disable history and verify the list is cleared without deleting video files.
3. Connect the reviewer Jellyfin account. Browse the library and play a title;
   demonstrate available language presets and skip/next-episode prompts.
4. On Apple TV, use the Siri Remote to browse, play, change tracks and operate
   prompts. Do not describe the Mac floating window as system Picture-in-Picture.

## Store metadata to prepare

| Field | iPhone / iPad | Apple TV |
| --- | --- | --- |
| Name | Vela | Vela |
| Subtitle draft | Your files and Jellyfin | Your Jellyfin movie night |
| Category | Entertainment | Entertainment |
| Minimum configured OS | 18.6 | 26.1 |
| Content | User-selected files and user-owned Jellyfin servers | User-owned Jellyfin servers |
| Pricing | Free; no purchases or subscriptions | Free; no purchases or subscriptions |

Do not use another app's name or icon in Vela's store identity. Screenshots must
come from the actual target app on each device class; Mac screenshots are not
iOS/tvOS screenshots. Complete age ratings and privacy answers from the actual
submitted build. Proposed privacy page: `https://ralleur.github.io/Vela/privacy.html`;
verify publication before entering it in App Store Connect. Support:
`https://github.com/ralleur/Vela/issues`.

## Native dependencies and privacy

The pinned MPVUI 0.1.1 package links `Libmpv-GPL`; its FFmpeg recipe enables GPL.
The current Mac executable distribution is documented as GPL-3.0-or-later.
An App Store distribution assessment for the actual combined binary is still
required. A possible technical route is a reproducible non-GPL mpv/FFmpeg build
with compatible transitive dependencies; changing only a wrapper's license or
hiding the engine switch does not change the linked binary. No replacement
decoder artifact has been qualified by this work.

The application privacy manifest declares app-owned UserDefaults access. Audit
the archive's dependency manifests and required-reason APIs as part of Organizer
validation; the manifest is not evidence of a complete native-binary privacy
audit. Local logs and user-configured server activity must be represented
accurately. Do not claim that local playback is a firewall against an already
connected Jellyfin session.

## Archive and upload

Run `Tools/vela/validate-apple.sh` for logic tests and all three builds. Run
`Tools/vela/archive-apple.sh ios` and `Tools/vela/archive-apple.sh tvos` to produce
local Release archives using configured signing. Neither command uploads.

The TestFlight workflow is manual-only, checks out the selected immutable commit,
and requires `releaseGatesChecked` plus the `apple-release` environment. Configure
that environment's protection and signing/API secrets in GitHub before use; the
environment name alone is not proof of reviewer protection. Its checkbox is a
human attestation, not an automated licensing check. The monthly upstream
automation is independent of TestFlight and never uploads builds.

## References

- [Apple: Copycats and minimum functionality](https://developer.apple.com/app-store/review/guidelines/#copycats)
- [Apple: Privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [mpv licensing and non-GPL build option](https://github.com/mpv-player/mpv/blob/master/Copyright)
- [Vela's current native dependency provenance](README.md)
