//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import JellyfinAPI
import SwiftUI

/// One-press audio and subtitle combinations for the player.
enum VelaLanguagePreset: String, CaseIterable, Identifiable {

    case englishWithEnglishSubtitles
    case englishWithGermanSubtitles
    case germanWithoutSubtitles

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .englishWithEnglishSubtitles: VelaStrings.presetEnglishEnglish
        case .englishWithGermanSubtitles: VelaStrings.presetEnglishGerman
        case .germanWithoutSubtitles: VelaStrings.presetGermanOff
        }
    }

    var audioLanguage: String {
        switch self {
        case .englishWithEnglishSubtitles, .englishWithGermanSubtitles: VelaLanguage.english
        case .germanWithoutSubtitles: VelaLanguage.german
        }
    }

    /// `nil` means subtitles off.
    var subtitleLanguage: String? {
        switch self {
        case .englishWithEnglishSubtitles: VelaLanguage.english
        case .englishWithGermanSubtitles: VelaLanguage.german
        case .germanWithoutSubtitles: nil
        }
    }

    /// The stream indexes for this preset, or `nil` when the item lacks a needed track.
    /// Unavailable presets are hidden in the player.
    @MainActor
    func streamIndexes(in item: MediaPlayerItem) -> (audio: Int, subtitle: Int)? {
        guard let audio = item.audioStreams.velaBestAudio(language: audioLanguage)?.index else { return nil }

        guard let subtitleLanguage else {
            return (audio, -1)
        }

        // Forced subtitles only cover foreign-language parts, so they never count as "with subtitles".
        guard let subtitle = item.subtitleStreams
            .filter({ $0.isForced != true })
            .velaBestSubtitle(language: subtitleLanguage)?.index
        else { return nil }

        return (audio, subtitle)
    }

    /// Whether the player currently plays this combination, judged by language so that
    /// any English track counts as English.
    @MainActor
    func isActive(in item: MediaPlayerItem) -> Bool {
        guard let audio = item.audioStreams.first(where: { $0.index == item.selectedAudioStreamIndex }),
              VelaLanguage.matches(audio, language: audioLanguage)
        else { return false }

        let subtitle = item.subtitleStreams.first { $0.index == item.selectedSubtitleStreamIndex }

        guard let subtitleLanguage else {
            return subtitle == nil
        }

        guard let subtitle else { return false }

        return VelaLanguage.matches(subtitle, language: subtitleLanguage) && subtitle.isForced != true
    }

    /// Switches both tracks at once. Changes the player cannot make in place go
    /// through a single rebuild, instead of one rebuild per track.
    @MainActor
    func apply(to manager: MediaPlayerManager) {
        guard let item = manager.playbackItem, let target = streamIndexes(in: item) else { return }

        let currentAudio = item.selectedAudioStreamIndex
        let currentSubtitle = item.selectedSubtitleStreamIndex ?? -1

        let audioChanges = target.audio != currentAudio
        let subtitleChanges = target.subtitle != currentSubtitle

        guard audioChanges || subtitleChanges else { return }

        let needsRebuild = (audioChanges && item.isRebuildRequired(type: .audio, from: currentAudio, to: target.audio))
            || (subtitleChanges && item.isRebuildRequired(type: .subtitle, from: currentSubtitle, to: target.subtitle))

        guard needsRebuild else {
            // In-place switches; VelaTrackMemoryObserver remembers them.
            if audioChanges {
                item.selectedAudioStreamIndex = target.audio
            }
            if subtitleChanges {
                item.selectedSubtitleStreamIndex = target.subtitle
            }
            return
        }

        // Explicit indexes are remembered by MediaPlayerItem.build.
        let mediaSource = item.mediaSource
        let requestedBitrate = item.requestedBitrate
        let positionTicks = manager.seconds.ticks

        let provider = MediaPlayerItemProvider(
            item: item.baseItem,
            mediaSource: mediaSource,
            audioStreamIndex: target.audio,
            subtitleStreamIndex: target.subtitle,
            requestedBitrate: requestedBitrate
        ) { baseItem, modifyItem in
            try await MediaPlayerItem.build(
                for: baseItem,
                mediaSource: mediaSource,
                audioStreamIndex: target.audio,
                subtitleStreamIndex: target.subtitle,
                requestedBitrate: requestedBitrate
            ) { item in
                if item.userData == nil {
                    item.userData = UserItemDataDto(key: "")
                }
                item.userData?.playbackPositionTicks = positionTicks
                modifyItem?(&item)
            }
        }

        manager.playNewItem(provider: provider)
    }
}

#if os(tvOS)

/// The preset buttons shown next to the player's action buttons.
struct VelaLanguagePresetButtons: View {

    @EnvironmentObject
    private var manager: MediaPlayerManager

    var body: some View {
        if let playbackItem = manager.playbackItem {
            Row(item: playbackItem)
        }
    }

    private struct Row: View {

        @EnvironmentObject
        private var manager: MediaPlayerManager

        @ObservedObject
        var item: MediaPlayerItem

        private var availablePresets: [VelaLanguagePreset] {
            VelaLanguagePreset.allCases.filter { $0.streamIndexes(in: item) != nil }
        }

        var body: some View {
            if availablePresets.isNotEmpty {
                HStack(spacing: VideoPlayer.PlaybackControls.Toolbar.buttonSpacing) {
                    ForEach(availablePresets) { preset in
                        let isActive = preset.isActive(in: item)

                        Button {
                            preset.apply(to: manager)
                        } label: {
                            HStack(spacing: 8) {
                                if isActive {
                                    Image(systemName: "checkmark")
                                }

                                Text(preset.title)
                            }
                            .font(.system(size: 24, weight: .semibold))
                            .padding(.horizontal, 8)
                            .frame(height: VideoPlayer.PlaybackControls.Toolbar.buttonSize)
                        }
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
                .buttonStyle(VideoPlayer.PlaybackControls.OverlayGlassButtonStyle())
                .buttonBorderShape(.capsule)
                .focusSection()
            }
        }
    }
}

#endif
