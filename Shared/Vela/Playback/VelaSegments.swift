//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

enum VelaSegmentKind: Hashable {
    case intro
    case recap
    case outro
    case preview
    case commercial
}

/// A stretch of an item, in seconds from the start.
struct VelaSegment: Hashable {

    let kind: VelaSegmentKind
    let start: TimeInterval
    let end: TimeInterval

    var duration: TimeInterval {
        end - start
    }
}

/// Segments from chapter names ("Intro", "Opening Credits", "Previously on…", "Abspann", …)
/// for items the server has no media segments for. Server segments win per kind.
enum VelaChapterSegments {

    private static let names: [(VelaSegmentKind, [String])] = [
        (.recap, ["recap", "previously", "previously on", "zuvor", "was bisher geschah", "rückblick", "bisher bei"]),
        (.intro, [
            "intro", "opening", "opening credits", "opening titles", "title sequence", "main title", "main titles",
            "vorspann", "titelsequenz", "op",
        ]),
        (.outro, [
            "credits", "end credits", "closing credits", "ending credits", "end titles", "outro", "ending", "ed",
            "abspann", "nachspann",
        ]),
        (.preview, ["preview", "next time", "next episode", "vorschau", "nächstes mal"]),
    ]

    static func kind(forChapterName raw: String?) -> VelaSegmentKind? {
        guard let raw else { return nil }

        let name = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !name.isEmpty else { return nil }

        for (kind, candidates) in names where candidates.contains(where: { name == $0 || name.hasPrefix($0 + " ") }) {
            return kind
        }

        return nil
    }

    /// A named chapter lasts until the next chapter starts.
    static func segments(chapters: [(name: String?, start: TimeInterval)], duration: TimeInterval) -> [VelaSegment] {
        let sorted = chapters.sorted { $0.start < $1.start }
        var result: [VelaSegment] = []

        for (index, chapter) in sorted.enumerated() {
            guard let kind = kind(forChapterName: chapter.name) else { continue }

            let end = index + 1 < sorted.count ? sorted[index + 1].start : duration
            guard end > chapter.start else { continue }

            result.append(VelaSegment(kind: kind, start: chapter.start, end: end))
        }

        return result
    }

    static func merge(server: [VelaSegment], chapters: [VelaSegment]) -> [VelaSegment] {
        let known = Set(server.map(\.kind))
        return (server + chapters.filter { !known.contains($0.kind) }).sorted { $0.start < $1.start }
    }
}

/// What the player offers at a moment of playback.
enum VelaPlaybackPrompt: Equatable {

    /// Skip to the end of an intro, recap, preview or commercial.
    case skip(VelaSegmentKind, to: TimeInterval)

    /// Credits of an episode: the next episode, or what is known about it.
    case endOfEpisode

    /// Credits of a film: offer to mark it as a favorite.
    case endOfMovie
}

enum VelaPromptPolicy {

    enum Content {
        case episode
        case movie
        case other
    }

    /// Touching the Siri Remote must not steal the following Select click from
    /// a skip or next-episode button. An outlook card has no action to preserve.
    static func keepsControlsHiddenOnTouch(prompt: VelaPlaybackPrompt?, hasNextEpisode: Bool) -> Bool {
        switch prompt {
        case .skip:
            true
        case .endOfEpisode:
            hasNextEpisode
        case .endOfMovie, nil:
            false
        }
    }

    /// Shorter segments are not worth a button.
    static let minimumSkipDuration: TimeInterval = 4
    /// The button leaves this long before the segment ends.
    static let minimumRemaining: TimeInterval = 2
    /// Without credits data, episodes offer the next one this long before the end.
    static let episodeFallbackLead: TimeInterval = 30

    /// Films without credits data: 3 % of the runtime, between two and five minutes.
    static func movieFallbackLead(duration: TimeInterval) -> TimeInterval {
        min(max(duration * 0.03, 120), 300)
    }

    /// When the credits start: the last outro in the final third, or a fixed lead before the end.
    static func endWindowStart(segments: [VelaSegment], duration: TimeInterval, content: Content) -> TimeInterval? {
        guard duration > 60, content != .other else { return nil }

        if let outro = segments.last(where: { $0.kind == .outro && $0.duration >= 5 && $0.start >= duration * 2 / 3 }) {
            return outro.start
        }

        switch content {
        case .episode:
            return duration - episodeFallbackLead
        case .movie:
            return duration - movieFallbackLead(duration: duration)
        case .other:
            return nil
        }
    }

    static func prompt(
        at time: TimeInterval,
        segments: [VelaSegment],
        duration: TimeInterval,
        content: Content
    ) -> VelaPlaybackPrompt? {
        if let windowStart = endWindowStart(segments: segments, duration: duration, content: content),
           time >= windowStart, time < duration
        {
            return content == .episode ? .endOfEpisode : .endOfMovie
        }

        for segment in segments where segment.kind != .outro && segment.duration >= minimumSkipDuration {
            if time >= segment.start, time < segment.end - minimumRemaining {
                return .skip(segment.kind, to: segment.end)
            }
        }

        return nil
    }
}
