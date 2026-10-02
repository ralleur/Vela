//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import JellyfinAPI
import Testing
@testable import VelaLogic

private func audio(_ index: Int, _ language: String?, title: String? = nil, channels: Int = 2, isDefault: Bool = false) -> MediaStream {
    MediaStream(channels: channels, index: index, isDefault: isDefault, language: language, title: title, type: .audio)
}

private func subtitle(_ index: Int, _ language: String?, forced: Bool = false, sdh: Bool = false, isDefault: Bool = false) -> MediaStream {
    MediaStream(index: index, isDefault: isDefault, isForced: forced, isHearingImpaired: sdh, language: language, type: .subtitle)
}

@Suite
struct LanguageTests {

    @Test
    func germanTagsAreEqual() {
        #expect(VelaLanguage.normalize("ger") == "deu")
        #expect(VelaLanguage.normalize("deu") == "deu")
        #expect(VelaLanguage.normalize("de") == "deu")
        #expect(VelaLanguage.normalize("de-DE") == "deu")
        #expect(VelaLanguage.normalize("GER") == "deu")
    }

    @Test
    func englishAndOthers() {
        #expect(VelaLanguage.normalize("en") == "eng")
        #expect(VelaLanguage.normalize("eng") == "eng")
        #expect(VelaLanguage.normalize("fre") == "fra")
        #expect(VelaLanguage.normalize("jpn") == "jpn")
    }

    @Test
    func appLanguageFollowsTheAppsLocalizationBeforeTheSystemFallback() {
        #expect(VelaLanguage.preferredAppLanguage(
            preferredLocalizations: ["fr"],
            preferredLanguages: ["de-DE"]
        ) == "fra")
        #expect(VelaLanguage.preferredAppLanguage(
            preferredLocalizations: [],
            preferredLanguages: ["de-DE"]
        ) == "deu")
    }

    @Test
    func undeterminedIsNil() {
        #expect(VelaLanguage.normalize(nil) == nil)
        #expect(VelaLanguage.normalize("") == nil)
        #expect(VelaLanguage.normalize("und") == nil)
    }
}

@Suite
struct LanguagePresetTests {

    @Test
    func germanPresetsKeepTheirExistingTitles() {
        let presets = VelaLanguagePreset.presets(appLanguage: "de-DE")

        #expect(presets.map(\.title) == ["EN + EN UT", "EN + DE UT", "DE ohne UT"])
    }

    @Test
    func frenchReplacesTheGermanTrackChoices() {
        let presets = VelaLanguagePreset.presets(appLanguage: "fr-FR")

        #expect(presets.map(\.title) == ["EN + EN ST", "EN + FR ST", "FR sans ST"])
        #expect(presets[1].subtitleLanguage == "fra")
        #expect(presets[2].audioLanguage == "fra")
    }

    @Test
    func englishDoesNotCreateDuplicatePresets() {
        #expect(VelaLanguagePreset.presets(appLanguage: "en").map(\.title) == ["EN + EN SUB", "EN no SUB"])
    }

    @Test
    func titleWithoutFullSubtitleSelectionHasNoQuickButtons() {
        let audios = [audio(1, "eng"), audio(2, "ger")]

        #expect(VelaLanguagePreset.availablePresets(
            appLanguage: "de",
            audioStreams: audios,
            subtitleStreams: []
        ).isEmpty)
        #expect(VelaLanguagePreset.availablePresets(
            appLanguage: "de",
            audioStreams: audios,
            subtitleStreams: [subtitle(3, "ger", forced: true)]
        ).isEmpty)
    }

    @Test
    func onlyPresetsWithAvailableTracksAreShown() {
        let presets = VelaLanguagePreset.availablePresets(
            appLanguage: "fr",
            audioStreams: [audio(1, "eng"), audio(2, "fre")],
            subtitleStreams: [subtitle(3, "eng"), subtitle(4, "fre")]
        )

        #expect(presets.map(\.title) == ["EN + EN ST", "EN + FR ST", "FR sans ST"])
    }
}

@Suite
struct TrackPickingTests {

    @Test
    func audioSkipsCommentaryAndPrefersDefaultThenChannels() {
        let streams = [
            audio(1, "eng", title: "Director's Commentary", channels: 2, isDefault: true),
            audio(2, "ger", channels: 6),
            audio(3, "eng", channels: 2),
            audio(4, "eng", channels: 6),
        ]

        #expect(streams.velaBestAudio(language: "eng")?.index == 4)
        #expect(streams.velaBestAudio(language: "de")?.index == 2)
        #expect(streams.velaBestAudio(language: "fra") == nil)
    }

    @Test
    func audioDefaultBeatsChannels() {
        let streams = [audio(1, "eng", channels: 6), audio(2, "eng", channels: 2, isDefault: true)]
        #expect(streams.velaBestAudio(language: "eng")?.index == 2)
    }

    @Test
    func subtitlePrefersFullOverForcedAndMatchesRememberedFlags() {
        let streams = [
            audio(1, "eng"),
            subtitle(2, "ger", forced: true),
            subtitle(3, "ger"),
            subtitle(4, "eng", sdh: true),
            subtitle(5, "eng"),
        ]

        #expect(streams.velaBestSubtitle(language: "deu")?.index == 3)
        #expect(streams.velaBestSubtitle(language: "deu", isForced: true)?.index == 2)
        #expect(streams.velaBestSubtitle(language: "eng")?.index == 5)
        #expect(streams.velaBestSubtitle(language: "eng", isHearingImpaired: true)?.index == 4)
    }

    @Test
    func subtitleFlagsAreOnlyPreferences() {
        let streams = [subtitle(7, "eng", sdh: true)]
        #expect(streams.velaBestSubtitle(language: "eng")?.index == 7)
        #expect(streams.velaBestSubtitle(language: "deu") == nil)
    }
}

@Suite
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
    func moviesLeaveAfterSevenDays() {
        let result = VelaContinueList.merge(
            resume: [movie("fresh", playedDaysAgo: 1), movie("edge", playedDaysAgo: 6.9), movie("old", playedDaysAgo: 8)],
            nextUp: [],
            seriesLastPlayed: [:],
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["fresh", "edge"])
    }

    @Test
    func episodesInProgressStayRegardlessOfAge() {
        let result = VelaContinueList.merge(
            resume: [episode("e1", series: "s1", playedDaysAgo: 90)],
            nextUp: [],
            seriesLastPlayed: [:],
            now: now,
            nextUpWindow: year
        )

        #expect(result.items.map(\.id) == ["e1"])
    }

    @Test
    func resumeEpisodeWinsOverNextUpOfSameSeries() {
        let result = VelaContinueList.merge(
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
    func episodeAddedAfterLastWatchIsNewAndMovesUp() {
        let result = VelaContinueList.merge(
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
    func stalledSeriesLeaveButComeBackWithNewEpisode() {
        let result = VelaContinueList.merge(
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
    func noCutoffWhenWindowDisabled() {
        let result = VelaContinueList.merge(
            resume: [],
            nextUp: [episode("stalled", series: "s1", addedDaysAgo: 800)],
            seriesLastPlayed: lastPlayed(["s1": 500]),
            now: now,
            nextUpWindow: 0
        )

        #expect(result.items.map(\.id) == ["stalled"])
    }
}
