//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
@testable import KurtzLogic
import Testing

struct SegmentTests {

    @Test
    func `chapter names map to kinds`() {
        #expect(KurtzChapterSegments.kind(forChapterName: "Intro") == .intro)
        #expect(KurtzChapterSegments.kind(forChapterName: "Opening Titles") == .intro)
        #expect(KurtzChapterSegments.kind(forChapterName: "End Credits") == .outro)
        #expect(KurtzChapterSegments.kind(forChapterName: "Abspann") == .outro)
        #expect(KurtzChapterSegments.kind(forChapterName: "Was bisher geschah…") == .recap)
        #expect(KurtzChapterSegments.kind(forChapterName: "Chapter 3") == nil)
        #expect(KurtzChapterSegments.kind(forChapterName: "Operation") == nil)
    }

    @Test
    func `chapters last until the next one`() {
        let segments = KurtzChapterSegments.segments(
            chapters: [("Chapter 1", 0), ("Intro", 60), ("Chapter 3", 120), ("Credits", 2500)],
            duration: 2600
        )
        #expect(segments == [
            KurtzSegment(kind: .intro, start: 60, end: 120),
            KurtzSegment(kind: .outro, start: 2500, end: 2600),
        ])
    }

    @Test
    func `server wins per kind`() {
        let merged = KurtzChapterSegments.merge(
            server: [KurtzSegment(kind: .intro, start: 50, end: 110)],
            chapters: [KurtzSegment(kind: .intro, start: 60, end: 120), KurtzSegment(kind: .outro, start: 2500, end: 2600)]
        )
        #expect(merged == [KurtzSegment(kind: .intro, start: 50, end: 110), KurtzSegment(kind: .outro, start: 2500, end: 2600)])
    }
}

struct PromptTests {

    private let episode = [
        KurtzSegment(kind: .recap, start: 0, end: 40),
        KurtzSegment(kind: .intro, start: 90, end: 150),
        KurtzSegment(kind: .outro, start: 2400, end: 2500),
    ]

    @Test
    func `skip during intro and recap until two seconds before the end`() {
        #expect(KurtzPromptPolicy.prompt(at: 10, segments: episode, duration: 2500, content: .episode) == .skip(.recap, to: 40))
        #expect(KurtzPromptPolicy.prompt(at: 90, segments: episode, duration: 2500, content: .episode) == .skip(.intro, to: 150))
        #expect(KurtzPromptPolicy.prompt(at: 148.5, segments: episode, duration: 2500, content: .episode) == nil)
        #expect(KurtzPromptPolicy.prompt(at: 600, segments: episode, duration: 2500, content: .episode) == nil)
    }

    @Test
    func `credits offer the next episode`() {
        #expect(KurtzPromptPolicy.prompt(at: 2399, segments: episode, duration: 2500, content: .episode) == nil)
        #expect(KurtzPromptPolicy.prompt(at: 2400, segments: episode, duration: 2500, content: .episode) == .endOfEpisode)
    }

    @Test
    func `remote touch keeps next episode button ready but allows navigation for outlook`() {
        let prompt = KurtzPromptPolicy.prompt(at: 2400, segments: episode, duration: 2500, content: .episode)

        #expect(KurtzPromptPolicy.keepsControlsHiddenOnTouch(prompt: prompt, hasNextEpisode: true))
        #expect(!KurtzPromptPolicy.keepsControlsHiddenOnTouch(prompt: prompt, hasNextEpisode: false))
    }

    @Test
    func `remote touch keeps skip ready and returns to normal after the prompt disappears`() {
        let intro = KurtzPromptPolicy.prompt(at: 90, segments: episode, duration: 2500, content: .episode)
        let afterIntro = KurtzPromptPolicy.prompt(at: 150, segments: episode, duration: 2500, content: .episode)

        #expect(KurtzPromptPolicy.keepsControlsHiddenOnTouch(prompt: intro, hasNextEpisode: false))
        #expect(!KurtzPromptPolicy.keepsControlsHiddenOnTouch(prompt: afterIntro, hasNextEpisode: true))
        #expect(!KurtzPromptPolicy.keepsControlsHiddenOnTouch(prompt: .endOfMovie, hasNextEpisode: false))
    }

    @Test
    func `without credits episodes use thirty seconds`() {
        #expect(KurtzPromptPolicy.endWindowStart(segments: [], duration: 2500, content: .episode) == 2470)
    }

    @Test
    func `early outro is not the credits`() {
        let segments = [KurtzSegment(kind: .outro, start: 300, end: 400)]
        #expect(KurtzPromptPolicy.endWindowStart(segments: segments, duration: 2500, content: .episode) == 2470)
    }

    @Test
    func `movies offer favorite at credits or near the end`() {
        let credits = [KurtzSegment(kind: .outro, start: 6900, end: 7200)]
        #expect(KurtzPromptPolicy.prompt(at: 6950, segments: credits, duration: 7200, content: .movie) == .endOfMovie)
        #expect(KurtzPromptPolicy.endWindowStart(segments: [], duration: 7200, content: .movie) == 6984)
        #expect(KurtzPromptPolicy.endWindowStart(segments: [], duration: 3000, content: .movie) == 2880)
        #expect(KurtzPromptPolicy.endWindowStart(segments: [], duration: 12000, content: .movie) == 11700)
    }

    @Test
    func `other videos get nothing at the end`() {
        #expect(KurtzPromptPolicy.prompt(at: 2490, segments: [], duration: 2500, content: .other) == nil)
    }
}

struct OutlookTests {

    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let now = try! Date("2026-09-28T20:00:00Z", strategy: .iso8601)

    private func show(
        status: String,
        episodes: [(Int, Int, String?)] = [],
        seasons: [(Int, String?)] = []
    ) -> KurtzTVmazeShow {
        let json: [String: Any] = [
            "id": 1,
            "status": status,
            "_embedded": [
                "episodes": episodes.map { season, number, stamp -> [String: Any] in
                    var episode: [String: Any] = ["season": season, "number": number]
                    if let stamp {
                        episode["airstamp"] = stamp
                        episode["airdate"] = String(stamp.prefix(10))
                    }
                    return episode
                },
                "seasons": seasons.map { number, premiere -> [String: Any] in
                    var season: [String: Any] = ["number": number]
                    if let premiere {
                        season["premiereDate"] = premiere
                    }
                    return season
                },
            ],
        ]
        return try! JSONDecoder().decode(KurtzTVmazeShow.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test
    func `next episode in the same season`() {
        let show = show(status: "Running", episodes: [(1, 7, "2026-09-28T01:00:00+00:00"), (1, 8, "2026-10-05T01:00:00+00:00")])
        #expect(KurtzSeriesOutlook.message(afterSeason: 1, episode: 7, show: show, now: now, timeZone: berlin)
            == "Die nächste Folge (S1E8) kommt am Montag, 5. Oktober.")
    }

    @Test
    func `aired but missing from the library`() {
        let show = show(status: "Running", episodes: [(4, 8, nil), (4, 9, "2026-09-27T01:00:00+00:00")])
        #expect(KurtzSeriesOutlook.message(afterSeason: 4, episode: 8, show: show, now: now, timeZone: berlin)
            == "S4E9 lief am 27. September, ist aber noch nicht in deiner Bibliothek.")
    }

    @Test
    func `next season with A date`() {
        let show = show(status: "Running", episodes: [(3, 10, "2026-09-04T01:00:00+00:00"), (4, 1, "2027-07-09T01:00:00+00:00")])
        #expect(KurtzSeriesOutlook.message(afterSeason: 3, episode: 10, show: show, now: now, timeZone: berlin)
            == "Staffel 4 startet am 9. Juli 2027.")
    }

    @Test
    func `announced season without A date`() {
        let show = show(status: "Running", episodes: [(2, 8, "2026-05-12T01:00:00+00:00")], seasons: [(2, "2026-03-24"), (3, nil)])
        #expect(KurtzSeriesOutlook.message(afterSeason: 2, episode: 8, show: show, now: now, timeZone: berlin)
            == "Staffel 3 ist angekündigt, einen Termin gibt es noch nicht.")
    }

    @Test
    func `status when nothing is announced`() {
        #expect(KurtzSeriesOutlook.message(afterSeason: 1, episode: 8, show: show(status: "Ended"), now: now) == "Die Serie ist beendet.")
        #expect(KurtzSeriesOutlook.message(afterSeason: 3, episode: 8, show: show(status: "To Be Determined"), now: now)
            == "Staffel 3 ist zu Ende. Ob es weitergeht, ist noch offen.")
        #expect(KurtzSeriesOutlook.message(afterSeason: 2, episode: 8, show: show(status: "Running"), now: now)
            == "Staffel 2 ist zu Ende. Eine neue Staffel ist noch nicht angekündigt.")
    }
}
