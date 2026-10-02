//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import JellyfinAPI
import SwiftUI

extension VelaLanguagePreset {

    @MainActor
    func streamIndexes(in item: MediaPlayerItem) -> (audio: Int, subtitle: Int)? {
        streamIndexes(audioStreams: item.audioStreams, subtitleStreams: item.subtitleStreams)
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
            VelaLanguagePreset.availablePresets(
                appLanguage: VelaLanguage.appLanguage,
                audioStreams: item.audioStreams,
                subtitleStreams: item.subtitleStreams
            )
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
                            .font(.system(size: UIDevice.isTV ? 24 : 15, weight: .semibold))
                            .padding(.horizontal, UIDevice.isTV ? 8 : 12)
                            .frame(height: VideoPlayer.PlaybackControls.Toolbar.buttonSize)
                        }
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
                .modifier(PresetButtonStyle())
            }
        }
    }

    private struct PresetButtonStyle: ViewModifier {

        func body(content: Content) -> some View {
            #if os(tvOS)
            content
                .buttonStyle(VideoPlayer.PlaybackControls.OverlayGlassButtonStyle())
                .buttonBorderShape(.capsule)
                .focusSection()
            #else
            if #available(iOS 26.0, *), UIDevice.supportsLiquidGlass {
                content
                    .buttonStyle(VideoPlayer.PlaybackControls.OverlayGlassButtonStyle())
                    .buttonBorderShape(.capsule)
            } else {
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5), in: .capsule)
            }
            #endif
        }
    }
}
