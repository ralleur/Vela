//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import MPVUI
import SwiftUI

@MainActor
class MPVMediaPlayerProxy: @MainActor VideoMediaPlayerProxy,
    @MainActor MediaPlayerOffsetConfigurable
{

    let isBuffering: PublishedBox<Bool> = .init(initialValue: false)
    let videoSize: PublishedBox<CGSize> = .init(initialValue: .zero)
    // MPVUI does not currently expose frame statistics.
    let droppedFrames: PublishedBox<Int> = .init(initialValue: 0)
    let corruptedFrames: PublishedBox<Int> = .init(initialValue: 0)
    let player = MPVPlayer()
    private var isStopping = false

    weak var manager: MediaPlayerManager? {
        didSet {
            for var observer in observers {
                observer.manager = manager
            }
        }
    }

    var observers: [any MediaPlayerObserver] = [
        NowPlayableObserver(),
    ]

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        isStopping = true
        player.stop()
    }

    func jumpForward(_ seconds: Duration) {
        setSeconds(player.position + seconds)
    }

    func jumpBackward(_ seconds: Duration) {
        setSeconds(player.position - seconds)
    }

    func setSeconds(_ seconds: Duration) {
        player.seek(to: seconds)
    }

    private var pendingExternalSelection = false

    func attachSubtitle(_ url: URL) throws {
        pendingExternalSelection = true
        player.command("sub-add", arguments: [url.absoluteString, "select"])
    }

    func setVolume(_ volume: Float) {
        player.setVolume(Double(volume) * 100)
    }

    func setMuted(_ muted: Bool) {
        player.setMuted(muted)
    }

    func setRate(_ rate: Float) {
        player.setPlaybackRate(Double(rate))
    }

    func setAudioStream(index: Int?) {
        setTrack(index, type: .audio)
    }

    func setSubtitleStream(index: Int?) {
        setTrack(index, type: .subtitle)
    }

    private func setTrack(_ index: Int?, type: MPVTrackType) {
        let tracks = player.mediaInformation.tracks.filter { $0.type == type }

        guard let index, index >= 0 else {
            if tracks.contains(where: \.isSelected) {
                player.disableTrack(type)
            }
            return
        }

        if let track = tracks.first(where: { $0.mpvID == index }), !track.isSelected {
            player.selectTrack(track)
        }
    }

    func setAspectFill(_ aspectFill: Bool) {
        player.setProperty("panscan", to: aspectFill ? "1" : "0")
    }

    func setAudioOffset(_ seconds: Duration) {
        player.setAudioDelay(seconds)
    }

    func setSubtitleOffset(_ seconds: Duration) {
        player.setSubtitleDelay(seconds)
    }

    var videoPlayerBody: some View {
        MPVPlayerView()
            .environmentObject(self)
    }
}

extension MPVMediaPlayerProxy {

    struct MPVPlayerView: View {

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager
        @EnvironmentObject
        private var proxy: MPVMediaPlayerProxy

        @State
        private var loadedItem: MediaPlayerItem?
        @State
        private var loadedSubtitleIndexes: Set<Int> = []
        @State
        private var textSubtitles = TextSubtitlePresentation()

        private var player: MPVPlayer {
            proxy.player
        }

        private var subtitleVideoSize: CGSize? {
            guard let dimensions = player.mediaInformation.dimensions else { return nil }
            var width = CGFloat(dimensions.effectiveWidth)
            var height = CGFloat(dimensions.effectiveHeight)
            let rotation = ((player.mediaInformation.rotation % 360) + 360) % 360
            if rotation == 90 || rotation == 270 {
                swap(&width, &height)
            }
            return CGSize(width: width, height: height)
        }

        private func load(_ item: MediaPlayerItem) {
            guard loadedItem !== item else { return }
            loadedItem = item
            proxy.isStopping = false
            loadedSubtitleIndexes.removeAll()
            item.setTrackIndexes(.init())
            proxy.isBuffering.value = true

            let start = max(.zero, (item.metadata.startSeconds ?? .zero) - .seconds(Defaults[.VideoPlayer.resumeOffset]))
            #if targetEnvironment(macCatalyst)
            let encoding = UserDefaults.standard.string(forKey: "vela.subtitle.encoding") ?? ""
            player.setProperty("sub-codepage", to: encoding.isEmpty ? "auto" : encoding)
            #endif
            player.load(item.url, autoPlay: manager.playbackRequestStatus == .playing, startTime: item.metadata.isLiveStream ? nil : start)
            proxy.setRate(manager.rate)
            proxy.setAspectFill(false)
        }

        private func updateTracks(for item: MediaPlayerItem) {
            guard player.mediaInformation.sourceURL == item.url, player.mediaInformation.tracks.isNotEmpty else { return }

            switch player.state {
            case .idle, .loading, .ended, .stopped, .failed:
                return
            default:
                break
            }

            func tracks(_ type: MPVTrackType, kind: PlaybackTrack.Kind) -> [PlaybackTrack] {
                player.mediaInformation.tracks.filter { $0.type == type }.map { track in
                    PlaybackTrack(
                        index: track.mpvID,
                        type: kind,
                        displayTitle: PlaybackTrackLabel.make(title: track.title, language: track.language, ordinal: track.mpvID),
                        language: track.language,
                        isExternal: track.isExternal
                    )
                }
            }
            item.updateEngineTracks(audio: tracks(.audio, kind: .audio), subtitles: tracks(.subtitle, kind: .subtitle))
            if proxy.pendingExternalSelection, item.discoversTracks,
               let selected = player.mediaInformation.tracks.last(where: { $0.type == .subtitle && $0.isExternal })
            {
                proxy.pendingExternalSelection = false
                item.selectedSubtitleStreamIndex = selected.mpvID + 10000
            }
            for stream in item.sidecarSubtitles {
                guard let index = stream.index, item.indexMap.playerIndex(for: index) == nil,
                      let url = stream.externalURL, loadedSubtitleIndexes.insert(index).inserted else { continue }
                player.command(
                    "sub-add",
                    arguments: [url.absoluteString, "auto", item.discoversTracks ? url.lastPathComponent : "swiftfin-subtitle-\(index)"]
                )
            }
        }

        private func updateState(_ state: MPVPlaybackState) {
            guard !proxy.isStopping else { return }
            proxy.isBuffering.value = state.isTransient

            switch state {
            case .loading:
                loadedSubtitleIndexes.removeAll()
            case .playing:
                manager.setPlaybackRequestStatus(status: .playing)
                proxy.setAudioOffset(manager.audioOffset)
                proxy.setSubtitleOffset(manager.subtitleOffset)
            case .paused:
                manager.setPlaybackRequestStatus(status: .paused)
            case .ended:
                guard manager.playbackItem?.metadata.isLiveStream == false else { return }
                manager.seconds = player.position
                manager.ended()
            case let .failed(error):
                manager.logger.error("Alternative playback failed: \(error)")
                manager
                    .error(manager.playbackItem?
                        .discoversTracks == true ?
                        ErrorMessage(VelaStrings.text("This video could not be played. It may be damaged or use an unsupported format.")) :
                        error)
            case .idle, .ready, .buffering, .seeking, .stopped:
                break
            }
        }

        var body: some View {
            if let item = manager.playbackItem, manager.state != .stopped {
                MPVVideoPlayer(player: player)
                    .overlay {
                        TextSubtitleOverlay(
                            snapshot: loadedItem === item ? textSubtitles.snapshot : TextSubtitleSnapshot(),
                            videoSize: subtitleVideoSize,
                            isAspectFilled: containerState.isAspectFilled
                        )
                    }
                    .task(id: ObjectIdentifier(item)) {
                        await textSubtitles.observe(player) {
                            load(item)
                        }
                    }
                    .onDisappear {
                        textSubtitles.clear()
                    }
                    .onChange(of: player.position) {
                        if !containerState.isScrubbing {
                            containerState.scrubbedSeconds.value = player.position
                        }
                        manager.seconds = player.position
                        item.updateDuration(player.duration)
                    }
                    .onChange(of: player.state) {
                        updateState(player.state)
                        if player.state == .ready || player.state == .playing || player.state == .paused {
                            updateTracks(for: item)
                        }
                    }
                    .onChange(of: player.mediaInformation.tracks) {
                        updateTracks(for: item)
                    }
                    .onChange(of: player.mediaInformation.dimensions) {
                        let dimensions = player.mediaInformation.dimensions
                        proxy.videoSize.value = CGSize(width: dimensions?.effectiveWidth ?? 0, height: dimensions?.effectiveHeight ?? 0)
                    }
                    .onChange(of: manager.rate) {
                        proxy.setRate(manager.rate)
                    }
            }
        }
    }
}
