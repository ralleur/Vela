//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela additions, licensed under the Mozilla Public License 2.0.
import Foundation
@testable import PlaybackCore
import Testing

struct EverydayPlaybackTests {
    @Test(arguments: [LocalPlaybackAttempt.Engine.vlc, .mpv])
    func `retry offers the other engine only once`(_ engine: LocalPlaybackAttempt.Engine) {
        var attempt = LocalPlaybackAttempt(engine: engine)
        #expect(attempt.retry() != engine)
        #expect(attempt.hasRetried)
        #expect(attempt.retry() == nil)
    }

    @Test
    func `track memory survives different engine identifiers`() {
        let choice = LocalTrackChoice(track: .init(index: 7, type: .audio, displayTitle: "Commentary", language: "en"))
        let tracks: [PlaybackTrack] = [
            .init(index: 1, type: .audio, displayTitle: "English", language: "eng"),
            .init(index: 2, type: .audio, displayTitle: "Commentary", language: "eng"),
        ]
        #expect(choice.index(in: tracks) == 2)
        #expect(choice.index(in: [tracks[0]]) == 1)
        #expect(choice.index(in: []) == nil)
    }

    @Test
    func `disabled subtitles remain disabled`() throws {
        let choice = LocalTrackChoice(track: nil, disabled: true)
        let restored = try JSONDecoder().decode(LocalTrackChoice.self, from: JSONEncoder().encode(choice))
        #expect(restored.index(in: [.init(index: 4, type: .subtitle)]) == -1)
    }

    @Test
    func `labels prefer language and retain useful titles`() {
        let locale = Locale(identifier: "en")
        #expect(PlaybackTrackLabel.make(title: "Track 42", language: "eng", channels: 2, ordinal: 1, locale: locale) == "English · Stereo")
        #expect(PlaybackTrackLabel
            .make(title: "Track 1 - [German]", language: "deu", channels: 1, ordinal: 2, locale: locale) == "German · Mono")
        #expect(PlaybackTrackLabel.make(title: "Commentary", language: "en", ordinal: 2, locale: locale) == "Commentary · English")
        #expect(PlaybackTrackLabel.make(title: nil, language: "und", ordinal: 3, locale: locale) == "Track 3")
    }
}
