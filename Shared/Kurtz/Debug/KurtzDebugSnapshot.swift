//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

#if DEBUG && targetEnvironment(macCatalyst)

import Foundation
import notify
import UIKit

/// Debug builds of the Mac app write a PNG of their windows on request, so the UI can be
/// checked from a script without screen recording permission:
///
///     notifyutil -p com.ralleur.vela.snapshot
///
/// The image lands in the app container's `Library/Caches/kurtz-snapshots/latest.png`, the view
/// hierarchy (class, frame, hidden/alpha) next to it in `latest.txt`.
enum KurtzDebugSnapshot {

    static var firstResponder: String?

    private static var isInstalled = false

    @MainActor
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        var token: Int32 = 0
        notify_register_dispatch("com.ralleur.vela.snapshot", &token, .main) { _ in
            MainActor.assumeIsolated { write() }
        }
    }

    @MainActor
    private static func write() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return }

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            for window in windows {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
        }

        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("kurtz-snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: directory.appendingPathComponent("latest.png"))

        var lines: [String] = []
        func describe(_ view: UIView, depth: Int) {
            let flags = (view.isHidden ? " hidden" : "") + (view.alpha < 1 ? " alpha=\(view.alpha)" : "")
                + (view.isUserInteractionEnabled ? "" : " noTouch")
            let frame = view.convert(view.bounds, to: nil)
            lines
                .append(String(repeating: "  ", count: depth) +
                    "\(type(of: view)) \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))" + flags)
            for subview in view.subviews {
                describe(subview, depth: depth + 1)
            }
        }
        if let manager = KurtzLocalFiles.shared.activeManager {
            lines
                .append(
                    "Playback: source=\(manager.playbackItem.map { String(describing: type(of: $0)) } ?? "loading") state=\(manager.state) request=\(manager.playbackRequestStatus) time=\(manager.seconds.seconds) duration=\(manager.item.runtime?.seconds ?? 0) rate=\(manager.rate) volume=\(manager.volume) muted=\(manager.isMuted)"
                )
            lines
                .append(
                    "Tracks: audio=\(manager.playbackItem?.audioStreams.count ?? 0) subtitles=\(manager.playbackItem?.subtitleStreams.count ?? 0) selectedAudio=\(manager.playbackItem?.selectedAudioStreamIndex ?? -1) selectedSubtitle=\(manager.playbackItem?.selectedSubtitleStreamIndex ?? -1)"
                )
        }
        lines.append("KurtzPlaybackPrompts: " + KurtzPlaybackPrompts.shared.debugSummary)
        lines.append("mini player: \(KurtzMiniPlayer.shared.isActive) \(KurtzMiniPlayer.shared.debugLog)")
        lines.append("AppKit windows: \(KurtzMiniPlayer.debugWindows)")
        lines.append("key window: \(windows.first(where: \.isKeyWindow).map { "\(type(of: $0))" } ?? "none"), "
            +
            "first responder: \(String(describing: UIApplication.shared.sendAction(#selector(UIResponder.kurtzReportFirstResponder), to: nil, from: nil, for: nil) ? KurtzDebugSnapshot.firstResponder : nil))")
        for window in windows {
            describe(window, depth: 0)
        }
        try? lines.joined(separator: "\n").write(to: directory.appendingPathComponent("latest.txt"), atomically: true, encoding: .utf8)
    }
}

extension UIResponder {

    @objc
    func kurtzReportFirstResponder() {
        KurtzDebugSnapshot.firstResponder = "\(type(of: self))"
    }
}

#endif
