//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela local playback policy. Licensed under MPL-2.0.
import Foundation

enum LocalPlaybackPolicy {
    static func resumePosition(_ position: Double, duration: Double?) -> Double {
        guard position.isFinite, position > 5 else { return 0 }
        if let duration, duration.isFinite, duration > 0, position >= duration - 10 {
            return 0
        }
        return position
    }

    static func subtitleCandidates(for video: URL, directory: [URL]) -> [URL] {
        let stem = video.deletingPathExtension().lastPathComponent.lowercased()
        return directory.filter { url in
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            return ["srt", "ass", "ssa", "vtt"].contains(url.pathExtension.lowercased())
                && (name == stem || name.hasPrefix(stem + "."))
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
