//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import JellyfinAPI
@testable import KurtzLogic
import Testing

private func audio(_ index: Int, _ language: String?, title: String? = nil, channels: Int = 2, isDefault: Bool = false) -> MediaStream {
    MediaStream(channels: channels, index: index, isDefault: isDefault, language: language, title: title, type: .audio)
}

private func subtitle(_ index: Int, _ language: String?, forced: Bool = false, sdh: Bool = false, isDefault: Bool = false) -> MediaStream {
    MediaStream(index: index, isDefault: isDefault, isForced: forced, isHearingImpaired: sdh, language: language, type: .subtitle)
}

struct LanguageTests {

    @Test
    func `german tags are equal`() {
        #expect(KurtzLanguage.normalize("ger") == "deu")
        #expect(KurtzLanguage.normalize("deu") == "deu")
        #expect(KurtzLanguage.normalize("de") == "deu")
        #expect(KurtzLanguage.normalize("de-DE") == "deu")
        #expect(KurtzLanguage.normalize("GER") == "deu")
    }

    @Test
    func `english and others`() {
        #expect(KurtzLanguage.normalize("en") == "eng")
        #expect(KurtzLanguage.normalize("eng") == "eng")
        #expect(KurtzLanguage.normalize("fre") == "fra")
        #expect(KurtzLanguage.normalize("jpn") == "jpn")
    }

    @Test
    func `app language follows the apps localization before the system fallback`() {
        #expect(KurtzLanguage.preferredAppLanguage(
            preferredLocalizations: ["fr"],
            preferredLanguages: ["de-DE"]
        ) == "fra")
        #expect(KurtzLanguage.preferredAppLanguage(
            preferredLocalizations: [],
            preferredLanguages: ["de-DE"]
        ) == "deu")
    }

    @Test
    func `undetermined is nil`() {
        #expect(KurtzLanguage.normalize(nil) == nil)
        #expect(KurtzLanguage.normalize("") == nil)
        #expect(KurtzLanguage.normalize("und") == nil)
    }
}

struct LanguagePresetTests {

    @Test
    func `german presets keep their existing titles`() {
        let presets = KurtzLanguagePreset.presets(appLanguage: "de-DE")

        #expect(presets.map(\.title) == ["EN + EN UT", "EN + DE UT", "DE ohne UT"])
    }

    @Test
    func `french replaces the german track choices`() {
        let presets = KurtzLanguagePreset.presets(appLanguage: "fr-FR")

        #expect(presets.map(\.title) == ["EN + EN ST", "EN + FR ST", "FR sans ST"])
        #expect(presets[1].subtitleLanguage == "fra")
        #expect(presets[2].audioLanguage == "fra")
    }

    @Test
    func `english does not create duplicate presets`() {
        #expect(KurtzLanguagePreset.presets(appLanguage: "en").map(\.title) == ["EN + EN SUB", "EN no SUB"])
    }

    @Test
    func `title without full subtitle selection has no quick buttons`() {
        let audios = [audio(1, "eng"), audio(2, "ger")]

        #expect(KurtzLanguagePreset.availablePresets(
            appLanguage: "de",
            audioStreams: audios,
            subtitleStreams: []
        ).isEmpty)
        #expect(KurtzLanguagePreset.availablePresets(
            appLanguage: "de",
            audioStreams: audios,
            subtitleStreams: [subtitle(3, "ger", forced: true)]
        ).isEmpty)
    }

    @Test
    func `only presets with available tracks are shown`() {
        let presets = KurtzLanguagePreset.availablePresets(
            appLanguage: "fr",
            audioStreams: [audio(1, "eng"), audio(2, "fre")],
            subtitleStreams: [subtitle(3, "eng"), subtitle(4, "fre")]
        )

        #expect(presets.map(\.title) == ["EN + EN ST", "EN + FR ST", "FR sans ST"])
    }
}

struct TrackPickingTests {

    @Test
    func `audio skips commentary and prefers default then channels`() {
        let streams = [
            audio(1, "eng", title: "Director's Commentary", channels: 2, isDefault: true),
            audio(2, "ger", channels: 6),
            audio(3, "eng", channels: 2),
            audio(4, "eng", channels: 6),
        ]

        #expect(streams.kurtzBestAudio(language: "eng")?.index == 4)
        #expect(streams.kurtzBestAudio(language: "de")?.index == 2)
        #expect(streams.kurtzBestAudio(language: "fra") == nil)
    }

    @Test
    func `audio default beats channels`() {
        let streams = [audio(1, "eng", channels: 6), audio(2, "eng", channels: 2, isDefault: true)]
        #expect(streams.kurtzBestAudio(language: "eng")?.index == 2)
    }

    @Test
    func `subtitle prefers full over forced and matches remembered flags`() {
        let streams = [
            audio(1, "eng"),
            subtitle(2, "ger", forced: true),
            subtitle(3, "ger"),
            subtitle(4, "eng", sdh: true),
            subtitle(5, "eng"),
        ]

        #expect(streams.kurtzBestSubtitle(language: "deu")?.index == 3)
        #expect(streams.kurtzBestSubtitle(language: "deu", isForced: true)?.index == 2)
        #expect(streams.kurtzBestSubtitle(language: "eng")?.index == 5)
        #expect(streams.kurtzBestSubtitle(language: "eng", isHearingImpaired: true)?.index == 4)
    }

    @Test
    func `subtitle flags are only preferences`() {
        let streams = [subtitle(7, "eng", sdh: true)]
        #expect(streams.kurtzBestSubtitle(language: "eng")?.index == 7)
        #expect(streams.kurtzBestSubtitle(language: "deu") == nil)
    }
}

struct ContinueListTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86400
    private let year: TimeInterval = 366 * 86400

    private func movie(_ id: String, playedDaysAgo: Double) -> BaseItemDto {
        BaseItemDto(id: id, type: .movie, userData: UserItemDataDto(key: "", lastPlayedDate: now.addingTimeInterval(-playedDaysAgo * day)))
    }

    private func episode(_ id: String, series: String, playedDaysAgo: Double? = nil, addedDaysAgo: Double? = nil) -> BaseItemDto {
        BaseItemDto(
            dateCreated: addedDaysAgo.map { now.addingTimeInterval(-$0 * day) },
            id: id,
            seriesID: series,
            type: .episode,
            userData: UserItemDataDto(key: "", lastPlayedDate: playedDaysAgo.map { now.addingTimeInterval(-$0 * day) })
        )
    }

    private func lastPlayed(_ pairs: [String: Double]) -> [String: Date] {
        pairs.mapValues { now.addingTimeInterval(-$0 * day) }
    }

    @Test
    func `movies leave after seven days`() {
        let result = KurtzContinueList.merge(
            resume: [movie("fresh", playedDaysAgo: 1), movie("edge", playedDaysAgo: 6.9), movie("old", playedDaysAgo: 8)],
            nextUp: [],
            seriesLastPlayed: [:],
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["fresh", "edge"])
    }

    @Test
    func `episodes in progress stay regardless of age`() {
        let result = KurtzContinueList.merge(
            resume: [episode("e1", series: "s1", playedDaysAgo: 90)],
            nextUp: [],
            seriesLastPlayed: [:],
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["e1"])
    }

    @Test
    func `resume episode wins over next up of same series`() {
        let result = KurtzContinueList.merge(
            resume: [episode("e3", series: "s1", playedDaysAgo: 2)],
            nextUp: [episode("e4", series: "s1", addedDaysAgo: 1)],
            seriesLastPlayed: lastPlayed(["s1": 2]),
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["e3"])
        #expect(result.newEpisodeIDs.isEmpty)
    }

    @Test
    func `episode added after last watch is new and moves up`() {
        let result = KurtzContinueList.merge(
            resume: [movie("m", playedDaysAgo: 3)],
            nextUp: [
                episode("old-next", series: "s1", addedDaysAgo: 100),
                episode("new-next", series: "s2", addedDaysAgo: 1),
            ],
            seriesLastPlayed: lastPlayed(["s1": 5, "s2": 40]),
            now: now,
            nextUpWindow: year
        )

        #expect(result.newEpisodeIDs == ["new-next"])
        #expect(result.items.map(\.id) == ["new-next", "m", "old-next"])
    }

    @Test
    func `stalled series leave but come back with new episode`() {
        let result = KurtzContinueList.merge(
            resume: [],
            nextUp: [
                episode("stalled", series: "s1", addedDaysAgo: 800),
                episode("returning", series: "s2", addedDaysAgo: 2),
                episode("unknown", series: "s3", addedDaysAgo: 2),
            ],
            seriesLastPlayed: lastPlayed(["s1": 500, "s2": 500]),
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["returning"])
        #expect(result.newEpisodeIDs == ["returning"])
    }

    @Test
    func `no cutoff when window disabled`() {
        let result = KurtzContinueList.merge(
            resume: [],
            nextUp: [episode("stalled", series: "s1", addedDaysAgo: 800)],
            seriesLastPlayed: lastPlayed(["s1": 500]),
            now: now,
            nextUpWindow: 0
        )

        #expect(result.items.map(\.id) == ["stalled"])
    }
}
