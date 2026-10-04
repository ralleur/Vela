# Current product verification

The kurtz rebrand was checked on 4 October 2026. Historical Vela findings remain
in [the original audit](history/product-audit-vela.md) with their original names.

| Area | Evidence | Limit |
| --- | --- | --- |
| Mac | Universal Release build 0.9.6 (8), arm64 + x86_64; strict code-signature and sandbox inspection | Runtime exercised on Apple silicon, not Intel hardware |
| iPhone/iPad | iOS Simulator build and unsigned device archive 0.9.6 (8); resources, bundle metadata, launch and home-screen inspection | No App Store release or real-device qualification claimed |
| Apple TV | tvOS Simulator build and unsigned device archive 0.9.6 (74); bundle/asset checks and launch-screen inspection | No Siri Remote/hardware qualification or Store approval claimed |
| Logic | Existing 46 playback/logic tests passed locally and in GitHub CI | Not a substitute for device playback qualification |
| Mac playback | Native local file opening, pause/seek, subtitle menu, fullscreen, return to window and logo inspected | Demo uses licensed Sintel media |
| Upgrade | Existing accounts and preferences visible under the retained bundle IDs | Existing persistent identifiers remain intentional |
| Brand | Custom vector masters, local Sora, two app icons, tvOS tile/Top Shelf, app/settings/player/DMG/site | Native OS menus keep system styling |
| Media | New Mac screenshots; six kurtz Shorts editions checked from final exports | Shorts reuse accurately documented original footage; listening limitations in validation record |

Release signature/notarization, DMG hash and public publication evidence are
recorded with the [0.9.6 release](release/0.9.6.md). See the
[Apple release plan](release/apple-release-plan.md) for remaining Store gates.

The supplementary [GitHub CI run](https://github.com/ralleur/kurtz/actions/runs/37168517078)
passed all four jobs on 4 October 2026: Mac Catalyst, 46 logic tests, and iOS/tvOS
archives using installed Xcode 26.6. Both downloaded unsigned IPAs contain
`Payload/kurtz.app`; their GitHub artifact digests, ZIP integrity, version,
retained bundle ID, fonts and URL schemes were verified. The later CI commit
contains the same application sources and resources as the published 0.9.6
release. The [publication record](release/publication-kurtz-0.9.6.json) records
the artifact hashes and earlier CI configuration failures. These archives do
not establish device playback qualification or distribution/Store approval.
