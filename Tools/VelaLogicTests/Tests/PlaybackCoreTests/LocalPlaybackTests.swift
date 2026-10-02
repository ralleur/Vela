//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
@testable import PlaybackCore
import Testing

struct LocalPlaybackTests {
    @Test
    func `metadata requires no server models`() {
        let media = PlaybackMedia(id: nil, displayTitle: "Vacation", runtime: .seconds(60))
        #expect(media.displayTitle == "Vacation")
        #expect(media.startSeconds == nil)
        #expect(!media.isLiveStream)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, -2, 0, 5, 51, 60, 100])
    func `invalid or completed positions start at beginning`(_ position: Double) {
        #expect(LocalPlaybackPolicy.resumePosition(position, duration: 60) == 0)
    }

    @Test
    func `resume keeps unfinished position`() {
        #expect(LocalPlaybackPolicy.resumePosition(20, duration: 60) == 20)
        #expect(LocalPlaybackPolicy.resumePosition(20, duration: nil) == 20)
    }

    @Test
    func `sidecars match exact stem or language suffix`() {
        let base = URL(fileURLWithPath: "/Movies")
        let urls = ["Film.srt", "Film.de.ass", "Film.vtt", "Filmmaker.srt", "Film.mp4", "Other.srt"].map { base.appendingPathComponent($0) }
        let matches = LocalPlaybackPolicy.subtitleCandidates(for: base.appendingPathComponent("Film.mkv"), directory: urls)
        #expect(Set(matches.map(\.lastPathComponent)) == ["Film.srt", "Film.de.ass", "Film.vtt"])
    }

    @Test
    func `track mapping can represent independent audio and subtitle identities`() {
        var map = MediaTrackIndexMap()
        map.setPlayerIndex(0, for: 0)
        map.setPlayerIndex(0, for: 10000)
        map.setPlayerIndex(3, for: 10001)
        #expect(map.playerIndex(for: 0) == 0)
        #expect(map.playerIndex(for: 10000) == 0)
        #expect(map.playerIndex(for: 10001) == 3)
        #expect(map.playerIndex(for: -1) == -1)
        #expect(map.playerIndex(for: 123) == nil)
    }

    @Test
    func `file access rejects remote addresses and missing files`() throws {
        #expect(throws: (any Error).self) { try LocalFileAccess(url: #require(URL(string: "https://example.com/movie.mp4"))) }
        #expect(throws: (any Error).self) { try LocalFileAccess(url: URL(fileURLWithPath: "/missing-vela-\(UUID()).mp4")) }
    }

    @Test
    func `file access reads user selected files and rejects directories`() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("test.mp4")
        try Data([0, 1, 2]).write(to: file)
        let access = try LocalFileAccess(url: file)
        #expect(access.url == file)
        #expect(throws: (any Error).self) { try LocalFileAccess(url: folder) }
    }
}
