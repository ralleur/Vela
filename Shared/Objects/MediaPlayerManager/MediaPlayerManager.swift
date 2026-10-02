//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import FactoryKit
import Foundation
import Logging

typealias MediaPlayerManagerPublisher = LegacyEventPublisher<MediaPlayerManager?>

extension Scope {
    static let session = Cached()
}

extension Container {

    var mediaPlayerManagerPublisher: Factory<MediaPlayerManagerPublisher> {
        self { MediaPlayerManagerPublisher() }
            .singleton
    }

    var mediaPlayerManager: Factory<MediaPlayerManager> {
        self { @MainActor in
            .init(playbackItem: MediaPlayerItem(metadata: .init(id: nil, displayTitle: ""), url: URL(fileURLWithPath: "/")))
        }
        .scope(.session)
    }
}

import StatefulMacros

@MainActor
@Stateful
final class MediaPlayerManager: ObservableObject {
    let logger = Logger.swiftfin()
    var cancellables = Set<AnyCancellable>()
    @Published
    var volume: Float = 1 {
        didSet { proxy?.setVolume(volume) }
    }

    @Published
    var isMuted = false {
        didSet { proxy?.setMuted(isMuted) }
    }

    var preferredPlayer: VideoPlayerType?
    var onStop: (() -> Void)?
    /// Source-owned recovery. The shared player only presents this action.
    var retryPlayback: (() -> Void)?
    @Published
    var audioOffset: Duration = .zero {
        didSet { (proxy as? any MediaPlayerOffsetConfigurable)?.setAudioOffset(audioOffset) }
    }

    @Published
    var subtitleOffset: Duration = .zero {
        didSet { (proxy as? any MediaPlayerOffsetConfigurable)?.setSubtitleOffset(subtitleOffset) }
    }

    @CasePathable
    enum Action {
        case ended
        case error
        case playNewItem(provider: any PlaybackItemProviding)
        case setBitrate(bitrate: PlaybackBitrate)
        case setPlaybackRequestStatus(status: PlaybackRequestStatus)
        case setRate(rate: Float)
        case setTrack(type: PlaybackTrack.Kind, from: Int?, to: Int? = nil)
        case start
        case stop
        case togglePlayPause

        var transition: Transition {
            switch self {
            case .error:
                .to(.error)
                    .invalid(.stopped)
            case .playNewItem, .start:
                .to(.loadingItem, then: .playback)
                    .invalid(.stopped)
            case .stop:
                .to(.stopped)
            default:
                .none
                    .invalid(.stopped)
            }
        }
    }

    enum State {
        case error
        case initial
        case loadingItem
        case playback
        case stopped
    }

    /// A status indicating the player's request for media playback.
    enum PlaybackRequestStatus {

        /// The player requests media playback
        case playing

        /// The player is paused
        case paused
    }

    @Published
    var playbackItem: MediaPlayerItem? = nil {
        didSet {
            audioOffset = .zero
            subtitleOffset = .zero
            if let playbackItem {
                self.item = playbackItem.metadata
                seconds = playbackItem.metadata.startSeconds ?? .zero
                playbackItem.manager = self
                setSupplements()

                logger.info(
                    "Playing new item",
                    metadata: [
                        "itemID": .stringConvertible(playbackItem.url.isFileURL ? "local" : (playbackItem.metadata.id ?? "Unknown")),
                        "itemTitle": .stringConvertible(playbackItem.url.isFileURL ? "Local video" : playbackItem.metadata.displayTitle),
                        "url": .stringConvertible(playbackItem.url.isFileURL ? "file://(private)" : playbackItem.url.absoluteString),
                        "isTranscoding": .stringConvertible(playbackItem.canSetBitrate),
                    ]
                )

                Task { _ = await playbackItem.previewImageProvider?.image(for: seconds) }
            }
        }
    }

    @Published
    private(set) var item: PlaybackMedia
    @Published
    private(set) var playbackRequestStatus: PlaybackRequestStatus = .playing
    @Published
    var rate: Float = Defaults[.VideoPlayer.Playback.playbackRate] {
        didSet {
            Defaults[.VideoPlayer.Playback.playbackRate] = rate
        }
    }

    @Published
    var queue: AnyMediaPlayerQueue? = nil

    @Published
    var supplements: [any MediaPlayerSupplement] = []

    // TODO: replace with graph dependency package
    private func setSupplements() {
        supplements = playbackItem?.makeSupplements(queue: queue) ?? []
    }

    func updateMetadata(_ metadata: PlaybackMedia) {
        item = metadata
    }

    /// The current seconds media playback is set to.
    let secondsBox: PublishedBox<Duration> = .init(initialValue: .zero)

    var seconds: Duration {
        get { secondsBox.value }
        set { secondsBox.value = newValue }
    }

    var playbackBitrate: PlaybackBitrate {
        playbackItem?.requestedBitrate ?? Defaults[.VideoPlayer.Playback.appMaximumBitrate]
    }

    /// Holds a weak reference to the current media player proxy.
    weak var proxy: (any MediaPlayerProxy)? {
        didSet {
            if var proxy {
                proxy.manager = self
                proxy.setVolume(volume)
                proxy.setMuted(isMuted)
            }
        }
    }

    private var initialMediaPlayerItemProvider: (any PlaybackItemProviding)?

    // MARK: init

    init(
        provider: any PlaybackItemProviding,
        queue: (any MediaPlayerQueue)? = nil
    ) {
        self.item = provider.metadata
        self.queue = queue.map { AnyMediaPlayerQueue($0) }
        self.state = .loadingItem
        self.initialMediaPlayerItemProvider = provider

        self.queue?.manager = self
    }

    init(
        playbackItem: MediaPlayerItem,
        queue: (any MediaPlayerQueue)? = nil
    ) {
        self.item = playbackItem.metadata
        self.queue = queue.map { AnyMediaPlayerQueue($0) }
        self.state = .playback

        self.queue?.manager = self
        self.playbackItem = playbackItem
        self.seconds = playbackItem.metadata.startSeconds ?? .zero
        playbackItem.manager = self
        setSupplements()
    }

    @Function(\Action.Cases.ended)
    private func _ended() async throws {
        // TODO: change to observe given seconds against runtime
        //       instead of sent action?

        // Ended should represent natural ending of playback, which
        // is verifiable by given seconds being near item runtime.
        // VLC proxy will send ended early.
        guard let runtime = item.runtime else {
            await self.stop()
            return
        }
        let isNearEnd = (runtime - seconds) <= .seconds(1)

        guard isNearEnd else {
            // If not near end, ignore.
            return
        }

        if let nextItem = queue?.nextItem, playbackItem?.autoplayNextItem == true {
            await self.playNewItem(provider: nextItem)
        } else {
            await self.stop()
        }
    }

    @Function(\Action.Cases.error)
    private func onError(_ error: Error) async throws {
        if let playbackItem {
            logger.error(
                "Error while playing item",
                metadata: [
                    "error": .stringConvertible(error.localizedDescription),
                    "itemID": .stringConvertible(playbackItem.url.isFileURL ? "local" : (playbackItem.metadata.id ?? "Unknown")),
                    "itemTitle": .stringConvertible(playbackItem.url.isFileURL ? "Local video" : playbackItem.metadata.displayTitle),
                    "url": .stringConvertible(playbackItem.url.isFileURL ? "file://(private)" : playbackItem.url.absoluteString),
                ]
            )
        } else {
            logger.error(
                "Error with no playback item",
                metadata: [
                    "error": .stringConvertible(error.localizedDescription),
                    "itemID": .stringConvertible(item.id ?? "Unknown"),
                    "itemTitle": .stringConvertible(item.displayTitle),
                ]
            )
        }

        playbackItem?.finish(at: seconds)
        proxy?.stop()
        playbackItem?.manager = nil
    }

    @Function(\Action.Cases.playNewItem)
    private func _playNewItem(_ provider: any PlaybackItemProviding) async throws {
        playbackItem?.finish(at: seconds)
        proxy?.stop()
        playbackItem?.manager = nil
        item = provider.metadata
        let prepared = try await provider()
        try Task.checkCancellation()
        guard state != .stopped else { return }
        playbackItem = prepared
    }

    @Function(\Action.Cases.setBitrate)
    private func _setBitrate(_ requestedBitrate: PlaybackBitrate) async throws {
        guard let currentItem = playbackItem else { return }

        try await updateMediaPlayerItem(
            currentItem: currentItem,
            requestedBitrate: requestedBitrate
        )
    }

    @Function(\Action.Cases.setPlaybackRequestStatus)
    private func set(_ status: PlaybackRequestStatus) {
        if self.playbackRequestStatus != status {
            self.playbackRequestStatus = status

            switch status {
            case .paused:
                proxy?.pause()
            case .playing:
                proxy?.play()
            }
        }
    }

    @Function(\Action.Cases.setRate)
    private func set(_ rate: Float) {
        if self.rate != rate {
            self.rate = rate
        }
    }

    @Function(\Action.Cases.setTrack)
    private func _setTrack(_ type: PlaybackTrack.Kind, _ oldIndex: Int?, _ newIndex: Int?) async throws {
        guard let playbackItem else {
            logger.warning("MediaPlayerManager.SetTrack call with an invalid playbackItem")
            return
        }

        switch type {
        case .audio:
            guard playbackItem.audioStreams.contains(where: { $0.index == oldIndex }) else {
                logger.warning("MediaPlayerManager.SetTrack call with an invalid audio track index")
                return
            }

            if playbackItem.isRebuildRequired(type: .audio, from: oldIndex, to: newIndex) {
                try await updateMediaPlayerItem(
                    currentItem: playbackItem,
                    audioStreamIndex: newIndex
                )
            } else {
                playbackItem.switchTrack(type: .audio, index: newIndex)
            }
        case .subtitle:
            guard newIndex == -1 || playbackItem.subtitleStreams.contains(where: { $0.index == newIndex }) else {
                logger.warning("MediaPlayerManager.SetTrack call with an invalid subtitle track index")
                return
            }

            if playbackItem.isRebuildRequired(type: .subtitle, from: oldIndex, to: newIndex) {
                try await updateMediaPlayerItem(
                    currentItem: playbackItem,
                    subtitleStreamIndex: newIndex
                )
            } else {
                playbackItem.switchTrack(type: .subtitle, index: newIndex)
            }
        default:
            logger.warning("MediaPlayerManager.SetTrack called with unsupported type: \(String(describing: type))")
        }
    }

    @Function(\Action.Cases.start)
    private func _start() async throws {
        guard let initialMediaPlayerItemProvider else { return }
        self.initialMediaPlayerItemProvider = nil
        let prepared = try await initialMediaPlayerItemProvider()
        try Task.checkCancellation()
        guard state != .stopped else { return }
        playbackItem = prepared
    }

    @Function(\Action.Cases.stop)
    private func _stop() async throws {
        await self.cancel()

        playbackItem?.finish(at: seconds)
        proxy?.stop()
        playbackItem?.manager = nil
        // A disappearing view may finish after its replacement has registered.
        // Only the current session may clear global playback ownership.
        if Container.shared.mediaPlayerManager() === self {
            Container.shared.mediaPlayerManagerPublisher().send(nil)
            Container.shared.mediaPlayerManager.reset()
        }
        onStop?()
    }

    @Function(\Action.Cases.togglePlayPause)
    private func _togglePlayPause() {
        switch playbackRequestStatus {
        case .playing:
            setPlaybackRequestStatus(status: .paused)
        case .paused:
            setPlaybackRequestStatus(status: .playing)
        }
    }

    /// Asks the source to rebuild its resource while preserving the shared playback position.
    private func updateMediaPlayerItem(
        currentItem: MediaPlayerItem,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil,
        requestedBitrate: PlaybackBitrate? = nil
    ) async throws {

        // Capture the current playback position before stopping
        let currentSeconds = self.seconds

        logger.info(
            "Rebuilding Media Player Item",
            metadata: [
                "audioIndex": "\(audioStreamIndex ?? -1)",
                "subtitleIndex": "\(subtitleStreamIndex ?? -1)",
                "currentSeconds": "\(currentSeconds)",
            ]
        )

        proxy?.stop()

        let newItem = try await currentItem.rebuild(
            audio: audioStreamIndex ?? currentItem.selectedAudioStreamIndex,
            subtitle: subtitleStreamIndex ?? currentItem.selectedSubtitleStreamIndex,
            bitrate: requestedBitrate,
            position: currentSeconds
        )
        guard !Task.isCancelled, state != .stopped else { return }
        currentItem.finish(at: currentSeconds)
        currentItem.manager = nil

        self.playbackItem = newItem
        self.seconds = currentSeconds
    }
}
