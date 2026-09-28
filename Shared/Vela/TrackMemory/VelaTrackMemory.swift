//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Combine
import Defaults
import Foundation
import JellyfinAPI

/// The audio and subtitle choice remembered for one film or one series.
///
/// Stored by language rather than by stream index, because episodes of a
/// series rarely share the same stream layout.
struct VelaTrackChoice: Storable, Hashable {

    enum Subtitle: Codable, Hashable {
        case off
        case track(language: String, isForced: Bool, isHearingImpaired: Bool)
    }

    var audioLanguage: String?
    var subtitle: Subtitle?
}

/// Remembers audio and subtitle choices per film and per series.
///
/// Playback starts with the remembered choice unless a track was picked
/// explicitly before starting. Every change in the player updates the memory.
enum VelaTrackMemory {

    /// Per signed-in user, like Swiftfin's other user settings.
    private static var storageKey: Defaults.Key<[String: VelaTrackChoice]> {
        .init("velaTrackMemory", default: [:], suite: .currentUserSuite)
    }

    /// Episodes share their series' memory; everything else is remembered by itself.
    static func memoryKey(for item: BaseItemDto) -> String? {
        guard !item.isLiveStream else { return nil }

        if item.type == .episode {
            return item.seriesID
        }

        return item.id
    }

    static func choice(for item: BaseItemDto) -> VelaTrackChoice? {
        guard let key = memoryKey(for: item) else { return nil }
        return Defaults[storageKey][key]
    }

    /// Fills in the remembered tracks where the caller did not ask for specific ones.
    static func resolve(
        for item: BaseItemDto,
        streams: [MediaStream],
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?
    ) -> (audio: Int?, subtitle: Int?) {
        guard let choice = choice(for: item) else {
            return (audioStreamIndex, subtitleStreamIndex)
        }

        var audio = audioStreamIndex
        var subtitle = subtitleStreamIndex

        if audio == nil, let language = choice.audioLanguage {
            audio = streams.velaBestAudio(language: language)?.index
        }

        if subtitle == nil {
            switch choice.subtitle {
            case .off:
                subtitle = -1
            case let .track(language, isForced, isHearingImpaired):
                subtitle = streams.velaBestSubtitle(
                    language: language,
                    isForced: isForced,
                    isHearingImpaired: isHearingImpaired
                )?.index
            case nil:
                break
            }
        }

        return (audio, subtitle)
    }

    /// Remembers explicitly requested stream indexes (-1 turns subtitles off).
    static func remember(
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?,
        streams: [MediaStream],
        for item: BaseItemDto
    ) {
        if let audioStreamIndex {
            remember(audio: streams.first { $0.type == .audio && $0.index == audioStreamIndex }, for: item)
        }

        if let subtitleStreamIndex {
            if subtitleStreamIndex == -1 {
                remember(subtitle: nil, for: item)
            } else if let stream = streams.first(where: { $0.type == .subtitle && $0.index == subtitleStreamIndex }) {
                remember(subtitle: stream, for: item)
            }
        }
    }

    static func remember(audio stream: MediaStream?, for item: BaseItemDto) {
        guard let language = VelaLanguage.normalize(stream?.language) else { return }

        update(item) { $0.audioLanguage = language }
    }

    /// `nil` means subtitles off.
    static func remember(subtitle stream: MediaStream?, for item: BaseItemDto) {
        guard let stream else {
            update(item) { $0.subtitle = .off }
            return
        }

        guard let language = VelaLanguage.normalize(stream.language) else { return }

        update(item) {
            $0.subtitle = .track(
                language: language,
                isForced: stream.isForced ?? false,
                isHearingImpaired: stream.isHearingImpaired ?? false
            )
        }
    }

    private static func update(_ item: BaseItemDto, _ change: (inout VelaTrackChoice) -> Void) {
        guard let key = memoryKey(for: item) else { return }

        var memory = Defaults[storageKey]
        var choice = memory[key] ?? VelaTrackChoice()
        change(&choice)

        guard memory[key] != choice else { return }

        memory[key] = choice
        Defaults[storageKey] = memory
    }
}

/// Records every audio or subtitle change made while an item plays.
@MainActor
final class VelaTrackMemoryObserver: MediaPlayerObserver {

    weak var manager: MediaPlayerManager?

    private var cancellables: Set<AnyCancellable> = []

    init(item: MediaPlayerItem) {
        let baseItem = item.baseItem

        // The first value is the starting selection, not a choice.
        item.$selectedAudioStreamIndex
            .dropFirst()
            .removeDuplicates()
            .sink { [weak item] index in
                guard let item, let index else { return }
                VelaTrackMemory.remember(audio: item.audioStreams.first { $0.index == index }, for: baseItem)
            }
            .store(in: &cancellables)

        item.$selectedSubtitleStreamIndex
            .dropFirst()
            .removeDuplicates()
            .sink { [weak item] index in
                guard let item else { return }

                guard let index, index != -1 else {
                    VelaTrackMemory.remember(subtitle: nil, for: baseItem)
                    return
                }

                if let stream = item.subtitleStreams.first(where: { $0.index == index }) {
                    VelaTrackMemory.remember(subtitle: stream, for: baseItem)
                }
            }
            .store(in: &cancellables)
    }
}
