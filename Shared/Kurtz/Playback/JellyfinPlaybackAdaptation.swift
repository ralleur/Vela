//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz playback abstractions. Licensed under MPL-2.0.
import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

extension PlaybackMedia {
    init(_ item: BaseItemDto) {
        self.init(
            id: item.id,
            displayTitle: item.displayTitle,
            subtitle: item.type == .episode ? item.seasonEpisodeLabel : nil,
            runtime: item.runtime,
            startSeconds: item.startSeconds,
            isLiveStream: item.isLiveStream,
            fullChapterInfo: item.chapters?.enumerated().map {
                PlaybackChapter(id: $0.offset, title: $0.element.name ?? "", startSeconds: $0.element.startSeconds ?? .zero)
            }
        )
        if item.type == .episode, let title = item.parentTitle {
            displayTitle = title
        }
    }
}

extension PlaybackTrack {
    init(_ stream: MediaStream) {
        self.init(
            index: stream.index,
            type: stream.type == .audio ? .audio : stream.type == .video ? .video : .subtitle,
            displayTitle: stream.displayTitle,
            language: stream.language,
            isForced: stream.isForced,
            isExternal: stream.isExternal,
            codec: stream.codec,
            width: stream.width,
            height: stream.height,
            aspectRatio: stream.aspectRatio
        )
    }
}

extension MediaTrackIndexMap {
    /// Maps Jellyfin stream indexes to positions in each player track array.
    /// Embedded tracks keep their order; transcoding exposes only the selected audio track.
    /// Sidecar subtitles are resolved after loading.
    static func build(
        from mediaStreams: [MediaStream],
        for playMethod: PlayMethod,
        selectedAudioStreamIndex: Int
    ) -> MediaTrackIndexMap {
        var indexMap = MediaTrackIndexMap()

        if playMethod == .transcode {
            let audioStreams = mediaStreams.filter { $0.type == .audio && $0.isExternal != true }

            if let jellyfinIndex = audioStreams.first(where: { $0.index == selectedAudioStreamIndex })?.index {
                indexMap.setPlayerIndex(0, for: jellyfinIndex)
            }
        } else {
            let embeddedAudioStreams = mediaStreams.filter { $0.type == .audio && $0.isExternal != true }
            let embeddedSubtitleStreams = mediaStreams.filter { $0.type == .subtitle && $0.isExternal != true }

            for (playerIndex, stream) in embeddedAudioStreams.enumerated() {
                guard let jellyfinIndex = stream.index else { continue }
                indexMap.setPlayerIndex(playerIndex, for: jellyfinIndex)
            }

            for (playerIndex, stream) in embeddedSubtitleStreams.enumerated() {
                guard let jellyfinIndex = stream.index else { continue }
                indexMap.setPlayerIndex(playerIndex, for: jellyfinIndex)
            }
        }

        return indexMap
    }
}

extension MediaPlayerManager {
    var userSession: UserSession? {
        Container.shared.currentUserSession()
    }

    var jellyfinItem: BaseItemDto? {
        (playbackItem as? JellyfinMediaPlayerItem)?.baseItem
    }

    nonisolated static func getMaxBitrate(
        for requestedBitrate: PlaybackBitrate,
        testSize: PlaybackBitrateTestSize = Defaults[.VideoPlayer.appMaximumBitrateTest]
    ) async throws -> Int {

        guard requestedBitrate == .auto else { return requestedBitrate.rawValue }

        guard let userSession = Container.shared.currentUserSession() else {
            throw UserSessionError.missingCurrentSession
        }

        let testStartTime = Date()
        let _ = try await userSession.client.send(Paths.getBitrateTestBytes(size: testSize.rawValue))
        let testDuration = Date().timeIntervalSince(testStartTime)
        let testSizeBits = Double(testSize.rawValue * 8)
        let testBitrate = testSizeBits / testDuration

        return clamp(
            Int(testBitrate),
            min: PlaybackBitrate.kbps420.rawValue,
            max: Int(Int32.max)
        )
    }
}
