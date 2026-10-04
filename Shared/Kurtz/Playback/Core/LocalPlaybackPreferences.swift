//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz additions, licensed under the Mozilla Public License 2.0.
import Foundation

/// Retry is offered once per open operation. It never starts a retry loop.
struct LocalPlaybackAttempt: Equatable {
    enum Engine: String { case vlc, mpv }
    var engine: Engine
    private(set) var hasRetried = false

    mutating func retry() -> Engine? {
        guard !hasRetried else { return nil }
        hasRetried = true
        engine = engine == .vlc ? .mpv : .vlc
        return engine
    }
}

/// Store semantic choices, not decoder IDs (which change between engines).
struct LocalTrackChoice: Codable, Equatable {
    var language: String?
    var title: String?
    var disabled: Bool

    init(track: PlaybackTrack?, disabled: Bool = false) {
        language = Self.normalized(track?.language)
        title = track?.displayTitle
        self.disabled = disabled
    }

    func index(in tracks: [PlaybackTrack]) -> Int? {
        if disabled {
            return -1
        }
        if let title, let match = tracks.first(where: { $0.displayTitle == title && Self.normalized($0.language) == language }) {
            return match.index
        }
        guard let language else { return nil }
        return tracks.first(where: { Self.normalized($0.language) == language })?.index
    }

    private static func normalized(_ language: String?) -> String? {
        guard let code = language?.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init),
              code != "und" else { return nil }
        return Locale.LanguageCode(code).identifier(.alpha3) ?? code
    }
}

enum PlaybackTrackLabel {
    static func make(title: String?, language: String?, channels: Int? = nil, ordinal: Int, locale: Locale = .current) -> String {
        let raw = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let generic = raw.isEmpty || raw.range(
            of: "^(Track|Audio|Subtitle) \\d+(?: - \\[[^\\]]+\\])?$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let languageName = language.flatMap { code -> String? in
            guard !["und", "unknown", ""].contains(code.lowercased()) else { return nil }
            return locale.localizedString(forLanguageCode: code) ?? code
        }
        var parts = [generic ? (languageName ?? "Track \(ordinal)") : raw]
        if !generic, let languageName, !raw.localizedCaseInsensitiveContains(languageName) {
            parts.append(languageName)
        }
        if let channels, channels > 0 {
            parts.append(channels == 1 ? "Mono" : channels == 2 ? "Stereo" : "\(channels) ch")
        }
        return parts.joined(separator: " · ")
    }
}
