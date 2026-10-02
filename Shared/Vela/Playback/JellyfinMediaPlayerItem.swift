//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

// TODO: get preview image for current manager seconds?
//       - would make scrubbing image possibly ready before scrubbing

@MainActor
final class JellyfinMediaPlayerItem: MediaPlayerItem {

    let baseItem: BaseItemDto
    let deviceProfile: DeviceProfile
    let mediaSource: MediaSourceInfo
    let playSessionID: String

    let serverAudioStreams: [MediaStream]
    let serverSubtitleStreams: [MediaStream]
    let serverVideoStreams: [MediaStream]

    private let bitrate: PlaybackBitrate
    override var requestedBitrate: PlaybackBitrate {
        bitrate
    }

    override var canSetBitrate: Bool {
        true
    }

    override var discoversTracks: Bool {
        false
    }

    override var autoplayNextItem: Bool {
        Container.shared.currentUserSession()?.user.data.configuration?.enableNextEpisodeAutoPlay == true
    }

    // MARK: init

    init(
        baseItem: BaseItemDto,
        mediaSource: MediaSourceInfo,
        playSessionID: String,
        url: URL,
        requestedBitrate: PlaybackBitrate = .max,
        deviceProfile: DeviceProfile,
        initialAudioStreamIndex: Int? = nil,
        initialSubtitleStreamIndex: Int? = nil,
        previewImageProvider: (any PreviewImageProvider)? = nil,
        thumbnailProvider: ThumbnailProvider? = nil
    ) {
        self.baseItem = baseItem
        self.mediaSource = mediaSource
        self.playSessionID = playSessionID
        self.bitrate = requestedBitrate
        self.deviceProfile = deviceProfile

        let mediaStreams = mediaSource.mediaStreams
        let isTranscoding = mediaSource.transcodingURL != nil

        // TODO: Fix External Audio Tracks & Re-Enable
        self.serverAudioStreams = mediaStreams?.filter { $0.type == .audio && $0.isExternal != true } ?? []
        self.serverSubtitleStreams = mediaStreams?.filter {
            $0.type == .subtitle
                && $0.deliveryMethod != .drop
                && !(Defaults[.VideoPlayer.Playback.compatibilityMode] == .directPlay
                    && $0.isExternal == true
                    && $0.isTextSubtitleStream != true)
        } ?? []
        self.serverVideoStreams = mediaStreams?.filter { $0.type == .video } ?? []

        let resolvedAudioStreamIndex: Int = initialAudioStreamIndex
            ?? mediaSource.defaultAudioStreamIndex
            ?? mediaSource.mediaStreams?.first(where: { $0.type == .audio })?.index ?? 0

        let indexes = MediaTrackIndexMap.build(
            from: mediaStreams ?? [],
            for: isTranscoding ? .transcode : .directPlay,
            selectedAudioStreamIndex: resolvedAudioStreamIndex
        )

        super.init(metadata: PlaybackMedia(baseItem), url: url)
        self.previewImageProvider = previewImageProvider
        self.thumbnailProvider = thumbnailProvider
        self.indexMap = indexes
        self.audioStreams = serverAudioStreams.map(PlaybackTrack.init)
        self.subtitleStreams = serverSubtitleStreams.map { stream in
            var track = PlaybackTrack(stream)
            if stream.deliveryMethod == .external, stream.deliveryURL != nil, stream.isTextSubtitleStream == true,
               let client = Container.shared.currentUserSession()?.client
            {
                track.externalURL = stream.url(with: client)
            }
            return track
        }
        self.videoStreams = serverVideoStreams.map(PlaybackTrack.init)

        selectedAudioStreamIndex = resolvedAudioStreamIndex

        selectedSubtitleStreamIndex = initialSubtitleStreamIndex
            ?? mediaSource.defaultSubtitleStreamIndex
            ?? -1

        observers.append(MediaProgressObserver(item: self))
    }

    /// Decides whether a track change can be performed by the player in place, or whether the server must produce a new stream.
    override func isRebuildRequired(type: PlaybackTrack.Kind, from oldIndex: Int?, to newIndex: Int?) -> Bool {
        let isTranscoding = mediaSource.transcodingURL != nil

        // Disabling a track is ALWAYS a local-only operation.
        guard let newIndex, newIndex != -1 else { return false }

        switch type {
        case .audio:

            // Transcodes contain a single audio track and MUST rebuild.
            if isTranscoding {
                return true
            }

            guard let newStream = serverAudioStreams.first(where: { $0.index == newIndex }) else { return true }

            // TODO: When audio playback exists then get the type dynamically.
            return !deviceProfile.canPlay(
                type: .video,
                audioCodec: newStream.codec,
                container: mediaSource.container
            )

        case .subtitle:
            // Optional (do not guard) since this could be -1 for disabled.
            let oldStream = oldIndex.flatMap { idx in serverSubtitleStreams.first { $0.index == idx } }

            // Transitioning away from encoded subtitles always requires a rebuild so the server stops burning them into the video.
            if oldStream?.deliveryMethod == .encode {
                return true
            }

            // Catch if the new stream doesn't exist. If non-existent this will fallback to -1 and disable locally.
            guard let newStream = serverSubtitleStreams.first(where: { $0.index == newIndex }) else { return false }

            if newStream.isExternal == true {

                // External subtitles can only be loaded as sidecars when the profile allows external or HLS delivery for the format.
                // E.G, This should disable external PGS for VLC since VLC cannot play them.
                return !(deviceProfile.canPlay(subtitleFormat: newStream.codec, method: .external)
                    || deviceProfile.canPlay(subtitleFormat: newStream.codec, method: .hls))
            }

            // Embedded subtitles are in the source container.
            // Only reachable while direct-playing AND when the profile supports embed delivery.
            return isTranscoding || !deviceProfile.canPlay(subtitleFormat: newStream.codec, method: .embed)

        default:
            return false
        }
    }

    override func updateEngineTracks(audio: [PlaybackTrack], subtitles: [PlaybackTrack]) {
        var map = MediaTrackIndexMap()
        let audioSources = serverAudioStreams
        if mediaSource.transcodingURL != nil {
            if let index = selectedAudioStreamIndex, let player = audio.first?.index {
                map.setPlayerIndex(player, for: index)
            }
        } else {
            for (stream, track) in zip(audioSources, audio.filter { $0.isExternal != true }) {
                if let index = stream.index, let player = track.index {
                    map.setPlayerIndex(player, for: index)
                }
            }
        }
        for (stream, track) in zip(serverSubtitleStreams.filter { $0.isExternal != true }, subtitles.filter { $0.isExternal != true }) {
            if let index = stream.index, let player = track.index {
                map.setPlayerIndex(player, for: index)
            }
        }
        for sidecar in sidecarSubtitles {
            guard let index = sidecar.index, let url = sidecar.externalURL else { continue }
            if let track = subtitles.first(where: { $0.displayTitle == "swiftfin-subtitle-\(index)" }), let player = track.index {
                map.setPlayerIndex(player, for: index)
            } else {
                map = map.resolvingSidecarSubtitles([(index, url)], subtitleTracks: subtitles.compactMap {
                    guard let index = $0.index, let id = $0.engineID else { return nil }
                    return (index, id)
                })
            }
        }
        setTrackIndexes(map)
    }

    override func rebuild(audio: Int?, subtitle: Int?, bitrate: PlaybackBitrate?, position: Duration) async throws -> MediaPlayerItem {
        try await JellyfinMediaPlayerItem.build(
            for: baseItem,
            mediaSource: mediaSource,
            audioStreamIndex: audio,
            subtitleStreamIndex: subtitle,
            requestedBitrate: bitrate ?? requestedBitrate
        ) { item in
            if item.userData == nil {
                item.userData = UserItemDataDto(key: "")
            }
            item.userData?.playbackPositionTicks = position.ticks
        }
    }

    override func finish(at position: Duration) {
        for observer in observers {
            (observer as? MediaProgressObserver)?.finish(at: position)
        }
    }

    override func makeSupplements(queue: AnyMediaPlayerQueue?) -> [any MediaPlayerSupplement] {
        let item = baseItem
        var result = Defaults[.VideoPlayer.supplements].compactMap { kind -> (any MediaPlayerSupplement)? in
            switch kind {
            case .info: return MediaInfoSupplement(item: item)
            case .chapters:
                guard let chapters = item.fullChapterInfo, !chapters.isEmpty else { return nil }
                return MediaChaptersSupplement(chapters: chapters)
            case .queue: return queue
            case .people:
                guard let people = item.mergedPeople?.filter({ $0.type?.isSupported == true }), !people.isEmpty else { return nil }
                return MediaPeopleSupplement(people: people)
            case .playbackInformation:
                guard let id = item.id else { return nil }
                return PlaybackInformationSupplement(itemID: id)
            }
        }
        if item.isLiveStream, Defaults[.Experimental.videoPlayerEPG] {
            result.append(EPGSupplement())
        }
        return result
    }
}
