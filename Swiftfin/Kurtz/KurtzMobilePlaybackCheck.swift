// kurtz additions, licensed under the Mozilla Public License 2.0.
#if DEBUG && !targetEnvironment(macCatalyst)
import Foundation

/// Opt-in simulator/device regression check. The fixture must be in this app's
/// Documents directory; no private library, network or login is required.
@MainActor
enum KurtzMobilePlaybackCheck {
    private static var started = false

    static func startIfRequested() {
        // Presenting a full-screen player cancels the home view's SwiftUI task.
        // The regression check must outlive that view transition.
        Task { await runIfRequested() }
    }

    static func runIfRequested() async {
        guard !started, let filename = UserDefaults.standard.string(forKey: "KurtzCheckFixture"),
              filename == URL(fileURLWithPath: filename).lastPathComponent else { return }
        started = true
        let documents = URL.documentsDirectory
        let files = KurtzLocalFiles.shared
        files.open(documents.appendingPathComponent(filename), using: .vlc)
        var ready = false
        for _ in 0 ..< 200 {
            try? await Task.sleep(for: .milliseconds(100))
            if !files.isOpening, let proxy = files.activeManager?.proxy as? VLCMediaPlayerProxy,
               proxy.player.state == .playing, (files.activeManager?.item.runtime ?? .zero) > .zero
            {
                ready = true
                break
            }
        }
        var results = ready ? await KurtzLocalPlaybackChecks.run(showResult: false) : [
            "FAIL Fixture did not start (opening=\(files.isOpening), manager=\(String(describing: files.activeManager?.state)), decoder=\(String(describing: (files.activeManager?.proxy as? VLCMediaPlayerProxy)?.player.state)), duration=\(String(describing: files.activeManager?.item.runtime)), seconds=\(String(describing: files.activeManager?.seconds)))"
        ]
        if ready, var manager = files.activeManager {
            let subtitlesBefore = (manager.proxy as? VLCMediaPlayerProxy)?.player.subtitleTracks.count ?? 0
            files.attachSubtitle(documents.appendingPathComponent("external.ass"))
            try? await Task.sleep(for: .seconds(2))
            let subtitlesAfter = (manager.proxy as? VLCMediaPlayerProxy)?.player.subtitleTracks.count ?? 0
            results
                .append(subtitlesAfter > subtitlesBefore ? "PASS External subtitle reaches VLC" : "FAIL External subtitle not enumerated")
            files.switchEngine()
            var retried = false
            for _ in 0 ..< 150 {
                try? await Task.sleep(for: .milliseconds(100))
                if let replacement = files.activeManager, replacement !== manager,
                   let proxy = replacement.proxy as? MPVMediaPlayerProxy, proxy.player.state == .playing
                {
                    manager = replacement
                    retried = true
                    break
                }
            }
            results.append(retried ? "PASS Compatible playback starts mpv" : "FAIL Compatible playback did not start")
            try? await Task.sleep(for: .seconds(1))
            let externalTracks = (manager.proxy as? MPVMediaPlayerProxy)?.player.mediaInformation.tracks
                .filter { $0.type == .subtitle } ?? []
            results.append(externalTracks.count >= 2 ? "PASS External subtitle survives engine retry" : "FAIL Retry lost external subtitle")
            results.append(manager.retryPlayback == nil ? "PASS Second engine retry is unavailable" : "FAIL Retry remains available")
            manager.proxy?.setSeconds(.seconds(12))
            try? await Task.sleep(for: .seconds(2))
            await manager.stop()
            try? await Task.sleep(for: .seconds(1))
            results.append(files.activeManager == nil ? "PASS Stop releases active session" : "FAIL Session remains active")
            if let recent = files.recent.first(where: { $0.url.lastPathComponent == filename }) {
                results
                    .append(files.recent.filter { $0.url == recent.url }
                        .count == 1 ? "PASS Recent identity is unique" : "FAIL Duplicate recent identity")
                results.append(recent.position > 5 ? "PASS Resume position persisted" : "FAIL Resume position missing")
                files.reopen(recent)
                var resumed = false
                for _ in 0 ..< 100 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if let active = files.activeManager, active.seconds > .seconds(5),
                       let proxy = active.proxy as? VLCMediaPlayerProxy, proxy.player.state == .playing
                    {
                        resumed = true
                        break
                    }
                }
                results.append(resumed ? "PASS Recent bookmark reopens and resumes" : "FAIL Recent reopen/resume")
                await files.activeManager?.stop()
            } else {
                results.append("FAIL Recent file missing")
            }
        }
        let report = results.joined(separator: "\n") + "\n"
        try? report.write(to: documents.appendingPathComponent("kurtz-playback-checks.txt"), atomically: true, encoding: .utf8)
        print("KURTZ_MOBILE_CHECKS \(report)")
    }
}
#endif
