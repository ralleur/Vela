//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela playback abstractions. Licensed under MPL-2.0.
import Combine
import Foundation
import SwiftUI

/// A playable resource plus source-specific policy hooks. Engine control, selection and
/// metadata are shared; a source owns its access lease, progress observer and rebuild policy.
@MainActor
class MediaPlayerItem: ObservableObject, MediaPlayerObserver {
    typealias ThumbnailProvider = () async -> UIImage?
    @Published
    var metadata: PlaybackMedia
    @Published
    var audioStreams: [PlaybackTrack] = []
    @Published
    var subtitleStreams: [PlaybackTrack] = []
    @Published
    var videoStreams: [PlaybackTrack] = []
    @Published
    var selectedAudioStreamIndex: Int? {
        didSet {
            guard selectedAudioStreamIndex != oldValue else { return }
            manager?.setTrack(type: .audio, from: oldValue, to: selectedAudioStreamIndex)
        }
    }

    @Published
    var selectedSubtitleStreamIndex: Int? = -1 {
        didSet {
            guard selectedSubtitleStreamIndex != oldValue else { return }
            manager?.setTrack(type: .subtitle, from: oldValue, to: selectedSubtitleStreamIndex)
        }
    }

    weak var manager: MediaPlayerManager? {
        didSet { for var observer in observers {
            observer.manager = manager
        } }
    }

    var retainedResources: [AnyObject] = []
    var observers: [any MediaPlayerObserver] = []
    var indexMap = MediaTrackIndexMap()
    let url: URL
    var previewImageProvider: (any PreviewImageProvider)?
    var thumbnailProvider: ThumbnailProvider?
    var sidecarSubtitles: [PlaybackTrack] {
        subtitleStreams.filter { $0.externalURL != nil }
    }

    var requestedBitrate: PlaybackBitrate {
        .max
    }

    var canSetBitrate: Bool {
        false
    }

    var autoplayNextItem: Bool {
        false
    }

    var discoversTracks: Bool {
        true
    }

    init(metadata: PlaybackMedia, url: URL) {
        self.metadata = metadata
        self.url = url
    }

    func isRebuildRequired(type: PlaybackTrack.Kind, from: Int?, to: Int?) -> Bool {
        false
    }

    func rebuild(audio: Int?, subtitle: Int?, bitrate: PlaybackBitrate?, position: Duration) async throws -> MediaPlayerItem {
        self
    }

    func makeSupplements(queue: AnyMediaPlayerQueue?) -> [any MediaPlayerSupplement] {
        []
    }

    /// Called before replacement or teardown, while the final position is still available.
    func finish(at position: Duration) {}

    func switchTrack(type: PlaybackTrack.Kind, index: Int?) {
        let mapped = indexMap.playerIndex(for: index)
        switch type {
        case .audio: (manager?.proxy as? any MediaPlayerAudioTrackConfigurable)?.setAudioStream(index: mapped)
        case .subtitle: (manager?.proxy as? any MediaPlayerSubtitleTrackConfigurable)?.setSubtitleStream(index: mapped)
        case .video: break
        }
    }

    func setTrackIndexes(_ indexes: MediaTrackIndexMap) {
        indexMap = indexes
        switchTrack(type: .audio, index: selectedAudioStreamIndex)
        switchTrack(type: .subtitle, index: selectedSubtitleStreamIndex)
    }

    /// Engine discovery uses per-kind identifiers. Offset subtitle identities to avoid collisions.
    func updateEngineTracks(audio: [PlaybackTrack], subtitles: [PlaybackTrack]) {
        var map = MediaTrackIndexMap()
        audioStreams = audio.map { track in
            if let index = track.index {
                map.setPlayerIndex(index, for: index)
            }
            return track
        }
        subtitleStreams = subtitles.map { track in
            var track = track
            if let index = track.index {
                track.index = index + 10000
                map.setPlayerIndex(index, for: index + 10000)
            }
            return track
        }
        if selectedAudioStreamIndex == nil {
            selectedAudioStreamIndex = audioStreams.first?.index
        }
        setTrackIndexes(map)
        manager?.objectWillChange.send()
    }

    func updateDuration(_ duration: Duration?) {
        guard let duration, duration > .zero, metadata.runtime != duration else { return }
        metadata.runtime = duration
        manager?.updateMetadata(metadata)
    }
}

protocol PlaybackItemProviding {
    var metadata: PlaybackMedia { get }
    func callAsFunction() async throws -> MediaPlayerItem
}
