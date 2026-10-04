//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz local media source. Licensed under MPL-2.0.
#if os(iOS)
import Combine
import Foundation

@MainActor
final class LocalMediaPlayerItem: MediaPlayerItem {
    private let access: LocalFileAccess
    private var audioChoice: LocalTrackChoice?
    private var subtitleChoice: LocalTrackChoice?
    private var restoredAudio = false
    private var restoredSubtitle = false
    private var discoveredSubtitles: [PlaybackTrack] = []
    override var sidecarSubtitles: [PlaybackTrack] {
        discoveredSubtitles
    }

    private var lastSaved = Date.distantPast
    private var positionObserver: AnyCancellable?

    init(
        access: LocalFileAccess,
        start: Duration = .zero,
        audio: LocalTrackChoice? = nil,
        subtitle: LocalTrackChoice? = nil,
        carrying previous: LocalMediaPlayerItem? = nil
    ) {
        audioChoice = audio
        subtitleChoice = subtitle
        self.access = access
        super.init(
            metadata: .init(
                id: access.url.absoluteString,
                displayTitle: access.url.deletingPathExtension().lastPathComponent,
                startSeconds: start
            ),
            url: access.url
        )
        if let previous {
            retainedResources = previous.retainedResources
            discoveredSubtitles = previous.discoveredSubtitles
        }
        // A sandbox may deny sibling enumeration; automatic discovery is best-effort,
        // while explicit subtitle selection always grants its own access lease.
        let directory = (try? FileManager.default.contentsOfDirectory(
            at: access.url.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )) ?? []
        for candidate in LocalPlaybackPolicy.subtitleCandidates(for: access.url, directory: directory) {
            guard let lease = try? LocalFileAccess(url: candidate) else { continue }
            retainSubtitle(lease)
        }
    }

    func retainSubtitle(_ lease: LocalFileAccess) {
        guard !discoveredSubtitles.contains(where: { $0.externalURL == lease.url }) else { return }
        retainedResources.append(lease)
        discoveredSubtitles.append(.init(
            index: 100_000 + discoveredSubtitles.count,
            type: .subtitle,
            displayTitle: lease.url.lastPathComponent,
            isExternal: true,
            externalURL: lease.url
        ))
    }

    var currentAudioChoice: LocalTrackChoice? {
        audioStreams.first(where: { $0.index == selectedAudioStreamIndex }).map { LocalTrackChoice(track: $0) }
    }

    var currentSubtitleChoice: LocalTrackChoice? {
        guard !subtitleStreams.isEmpty else { return subtitleChoice }
        return LocalTrackChoice(
            track: subtitleStreams.first(where: { $0.index == selectedSubtitleStreamIndex }),
            disabled: selectedSubtitleStreamIndex == -1
        )
    }

    override func updateEngineTracks(audio: [PlaybackTrack], subtitles: [PlaybackTrack]) {
        super.updateEngineTracks(audio: audio, subtitles: subtitles)
        if !restoredAudio, let index = audioChoice?.index(in: audioStreams) {
            restoredAudio = true
            selectedAudioStreamIndex = index
        }
        if !restoredSubtitle, let index = subtitleChoice?.index(in: subtitleStreams) {
            restoredSubtitle = true
            selectedSubtitleStreamIndex = index
        }
    }

    override func updateDuration(_ duration: Duration?) {
        super.updateDuration(duration)
        if positionObserver == nil, let manager {
            positionObserver = manager.secondsBox.$value.sink { [weak self] position in
                guard let self, Date().timeIntervalSince(lastSaved) > 5 else { return }
                lastSaved = Date()
                KurtzLocalFiles.shared.savePosition(
                    position,
                    duration: metadata.runtime,
                    for: url,
                    audio: currentAudioChoice,
                    subtitle: currentSubtitleChoice
                )
            }
        }
    }

    override func finish(at position: Duration) {
        KurtzLocalFiles.shared.savePosition(
            position,
            duration: metadata.runtime,
            for: url,
            audio: currentAudioChoice,
            subtitle: currentSubtitleChoice
        )
        positionObserver = nil
        // The item retains file leases until its engine view has been removed.
    }
}
#endif
