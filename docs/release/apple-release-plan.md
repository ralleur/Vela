# Apple platform release plan

Scope: prepare one kurtz product for macOS, iPhone/iPad and Apple TV. Public
availability is separate from build support. The existing Mac download remains
available; iOS/iPadOS and tvOS are release candidates in development, not announced
App Store releases.

## Implementation

- [x] Share local file playback with iOS/iPadOS, including security-scoped access,
  recent files, resume, external subtitles and bounded engine recovery.
- [x] Add a mobile kurtz home and settings usable without a Jellyfin account.
- [x] Preserve the tvOS Jellyfin experience and Mac-specific window handling.
- [x] Validate logic and build iOS, tvOS and Mac Catalyst; exercise mobile layouts
  and actual playback where the available test environment permits.
- [x] Prepare archive tooling, review notes and an explicit release checklist.
- [x] Update repository and project site with platform-specific availability.

## Release gates

1. Audit the actual linked decoder artifacts for App Store distribution. The
   current native mpv artifact is GPL-enabled; Mac distribution evidence does
   not establish App Store compatibility. Do not mark this resolved by hiding a
   settings option or disabling a Swift call while still linking the binary.
2. Qualify real iPhone, iPad and Apple TV hardware, oldest supported OS versions,
   Siri Remote focus, rotation, file-provider access, interruptions and long
   playback. Distinguish simulator/build evidence from device evidence.
3. Prepare App Store Connect records, distribution profiles, privacy answers,
   screenshots and a reachable Jellyfin reviewer account with licensed media.
4. Submit only after gates are satisfied. This preparation does not upload an
   app or claim Apple approval. Preserve Swiftfin attribution and explain kurtz's
   local-file workflow and language/subtitle features in review notes.

## Upstream maintenance

The monthly automation selects the penultimate stable Swiftfin release and
integrates it in an isolated worktree. No downgrade and no rewrite of published
history. All platform builds and required runtime checks must pass before the
integration PR is merged. Missing evidence leaves the PR open.

## Evidence from the preceding Apple-platform task

The following preparation checks were performed under the previous Vela name
before rebranding. Their original results remain in the completed platform chat.

Verified on 4 October 2026 with Xcode 27.0 (27A266a):

- 46 source-independent playback/logic tests passed (35 XCTest + 11 Swift Testing).
- iOS, tvOS and Mac Catalyst Debug builds succeeded.
- Signed local iOS and tvOS Release archives were created for 0.9.6. These are
  development-signed archive candidates, not exported App Store packages.
- The iPhone 18 Pro and iPad Pro 11-inch (M5) simulators each passed 23 actual
  player checks: pause/seek/tracks, external subtitles, one-shot VLC→mpv recovery,
  session teardown, unique history, saved position and bookmark reopening.
- Mobile home screens and the responsive project-page cards were inspected.
- Bundle inspection checked the then-current Vela identity, device families, OS minimums, resources,
  URL scheme, privacy declaration, iPad sizing and removal of upstream alternate
  icons. The debug playback harness is absent from the Release executable.
- SwiftLint, changed-file SwiftFormat (preserving authorship), unused upstream
  strings, plist/YAML/script parsing and the static-site validator were checked.

The simulator fixture is synthetic local media. These checks do **not** establish
file-provider/iCloud permission persistence, oldest-OS compatibility, hardware
playback or Apple approval. No TestFlight/App Store upload was performed. The
release gates above remain open. The Mac download at that point was Vela 0.9.5; the preparation source was 0.9.6.

The subsequent kurtz rebrand rebuilt Mac Release, iOS Simulator and tvOS Simulator,
verified their new display names/resources/schemes, and inspected all three launch
surfaces. Its evidence is in [0.9.6.md](0.9.6.md). Device/store gates above remain open.

CI now targets the `kurtz` branch for all three platform builds. Formatting checks
apply to touched Swift files so that existing fork formatting does not prevent
an otherwise valid release preparation; SwiftLint and unused-string checks still
cover the whole source tree.
