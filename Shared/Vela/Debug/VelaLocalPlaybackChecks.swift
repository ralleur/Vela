//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// On-device behavioral checks for the shared player. Licensed under MPL-2.0.
#if DEBUG && os(iOS)
import SwiftUI

@MainActor
enum VelaLocalPlaybackChecks {
    private final class WeakSession {
        weak var value: MediaPlayerManager?
        init(_ value: MediaPlayerManager?) {
            self.value = value
        }
    }

    static func runReplacementChecks() async {
        let files = VelaLocalFiles.shared
        let entries = files.recent.filter { ["long.mp4", "sample.mov", "sample.mkv"].contains($0.url.lastPathComponent) }
        guard entries.count >= 2 else { return }
        var released: [WeakSession] = []
        var failures: [String] = []
        for cycle in 0 ..< 8 {
            released.append(WeakSession(files.activeManager))
            // Coalesce bursts while the previous controller is still dismissing.
            for entry in entries {
                files.reopen(entry)
            }
            let expected = entries[cycle % entries.count]
            files.reopen(expected)
            var loaded = false
            for _ in 0 ..< 100 {
                try? await Task.sleep(for: .milliseconds(100))
                if !files.isOpening, files.activeManager?.playbackItem?.url == expected.url,
                   let proxy = files.activeManager?.proxy as? VLCMediaPlayerProxy, proxy.player.state == .playing
                {
                    loaded = true
                    proxy.setSeconds(.seconds(10))
                    break
                }
            }
            if !loaded {
                failures.append("Replacement \(cycle + 1) did not settle")
            }
        }
        await files.activeManager?.stop()
        try? await Task.sleep(for: .seconds(1))
        // UIKit caches the last hovered view (and its SwiftUI environment) until
        // the next pointer event. Programmatic replacement alone cannot flush it.
        // Check after real pointer input, without clearing UIKit internals.
        present(
            title: "Replacement Checks",
            result: "Replacement cycles finished. Move the pointer over this dialog, then click Check Cleanup.",
            actionTitle: "Check Cleanup"
        ) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                var results = failures
                let retained = released.filter { $0.value != nil }.count
                if retained > 0 {
                    results.append("\(retained) old manager references remain")
                }
                if files.activeManager != nil {
                    results.append("Active manager remains after stop")
                }
                let result = results
                    .isEmpty ? "PASS: 8 replacement cycles with rapid-open bursts; all previous managers released; stopped cleanly." :
                    results.joined(separator: "\n")
                print("VELA_REPLACEMENT_CHECKS \(result)")
                present(title: "Replacement Results", result: result)
            }
        }
    }

    @discardableResult
    static func run(showResult: Bool = true) async -> [String] {
        guard let manager = VelaLocalFiles.shared.activeManager,
              let item = manager.playbackItem as? LocalMediaPlayerItem,
              let proxy = manager.proxy as? VLCMediaPlayerProxy else { return ["FAIL Local VLC session unavailable"] }
        var results: [String] = []
        func check(_ label: String, _ passes: Bool) {
            results.append("\(passes ? "PASS" : "FAIL") \(label)")
        }
        func settle(_ seconds: Double = 0.6) async {
            try? await Task.sleep(for: .seconds(seconds))
        }
        let originalRate = manager.rate
        let originalVolume = manager.volume
        let originalMute = manager.isMuted
        let originalAudio = item.selectedAudioStreamIndex
        let originalSubtitle = item.selectedSubtitleStreamIndex
        let originalAudioOffset = manager.audioOffset
        let originalSubtitleOffset = manager.subtitleOffset

        check("Local item has no server observers", item.observers.isEmpty)
        check("Duration discovered", (manager.item.runtime ?? .zero) > .zero)
        await manager.setPlaybackRequestStatus(status: .paused)
        await settle()
        let pausedAt = manager.seconds
        await settle()
        check("Pause holds the clock", abs((manager.seconds - pausedAt).seconds) < 0.3)
        proxy.setSeconds(.seconds(10))
        await settle(1.5)
        check("Seek forward", abs(manager.seconds.seconds - 10) < 2)
        proxy.setSeconds(.seconds(3))
        await settle(1.5)
        check("Seek backward", abs(manager.seconds.seconds - 3) < 2)
        await manager.setRate(rate: 1.5)
        await settle()
        check("Playback speed", abs(proxy.player.rate - 1.5) < 0.01)
        manager.volume = 0.3
        manager.isMuted = true
        await settle()
        check("Volume and mute", abs(proxy.player.volume - 0.3) < 0.01 && proxy.player.isMuted)
        manager.audioOffset = .milliseconds(100)
        manager.subtitleOffset = .milliseconds(250)
        await settle()
        check("Audio timing reaches decoder", proxy.player.audioDelay == .milliseconds(100))
        check("Subtitle timing reaches decoder", proxy.player.subtitleDelay == .milliseconds(250))
        check("Audio tracks enumerated", item.audioStreams.count >= 2)
        if item.audioStreams.count >= 2 {
            item.selectedAudioStreamIndex = item.audioStreams[1].index
            await settle()
            check("Audio track switched", proxy.player.selectedAudioTrack == proxy.player.audioTracks[1])
        }
        check("Subtitle tracks enumerated", !item.subtitleStreams.isEmpty)
        if let subtitle = item.subtitleStreams.first {
            item.selectedSubtitleStreamIndex = subtitle.index
            await settle()
            check("Subtitle enabled", proxy.player.selectedSubtitleTrack != nil)
            item.selectedSubtitleStreamIndex = -1
            await settle()
            check("Subtitle disabled", proxy.player.selectedSubtitleTrack == nil)
        }
        await manager.setPlaybackRequestStatus(status: .playing)
        let resumeAt = manager.seconds
        await settle(1.2)
        check("Resume advances the clock", manager.seconds > resumeAt)
        manager.volume = originalVolume
        manager.isMuted = originalMute
        await manager.setRate(rate: originalRate)
        item.selectedAudioStreamIndex = originalAudio
        item.selectedSubtitleStreamIndex = originalSubtitle
        manager.audioOffset = originalAudioOffset
        manager.subtitleOffset = originalSubtitleOffset
        await manager.setPlaybackRequestStatus(status: .paused)

        print("VELA_PLAYBACK_CHECKS \(results.joined(separator: "; "))")
        if showResult {
            present(title: "Local Playback Checks", result: results.joined(separator: "\n"))
        }
        return results
    }

    private static func present(title: String, result: String, actionTitle: String = "Done", action: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: result, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in action?() })
        if var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
        {
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
}
#endif
