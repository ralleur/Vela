//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import JellyfinAPI
import SwiftUI

/// The prompt in the player's bottom trailing corner: skip intro, next episode,
/// what comes after the last episode, or favorite a film.
///
/// With the controls hidden the prompt looks selected and the select button triggers it
/// (see the hook in `VideoPlayerContainerView`). With the controls shown it is a normal
/// button above the toolbar.
struct VelaPlaybackPromptOverlay: View {

    @EnvironmentObject
    private var containerState: VideoPlayerContainerState
    @EnvironmentObject
    private var manager: MediaPlayerManager

    @ObservedObject
    private var prompts = VelaPlaybackPrompts.shared

    private var isHidden: Bool {
        containerState.isScrubbing || containerState.isPresentingSupplement
    }

    var body: some View {
        content
            .padding(.bottom, containerState.isPresentingOverlay ? 200 : 60)
            .edgePadding(.trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .opacity(isHidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.25), value: prompts.prompt)
            .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingOverlay)
            .onAppear {
                prompts.attach(to: manager)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch prompts.prompt {
        case let .skip(kind, _):
            PromptButton(title: title(forSkipping: kind), systemImage: "forward.fill")
        case .endOfEpisode:
            if let nextEpisode = prompts.nextEpisode {
                PromptButton(
                    title: VelaStrings.nextEpisode,
                    subtitle: [nextEpisode.seasonEpisodeLabel, nextEpisode.name].compactMap(\.self).joined(separator: " · "),
                    systemImage: "forward.end.fill"
                )
            } else if manager.queue?.hasNextItem == true {
                PromptButton(title: VelaStrings.nextEpisode, systemImage: "forward.end.fill")
            } else if let outlook = prompts.outlook {
                OutlookCard(message: outlook)
            }
        case .endOfMovie:
            PromptButton(
                title: prompts.isFavorite ? VelaStrings.isFavorite : VelaStrings.markFavorite,
                systemImage: prompts.isFavorite ? "heart.fill" : "heart"
            )
        case nil:
            EmptyView()
        }
    }

    private func title(forSkipping kind: VelaSegmentKind) -> String {
        switch kind {
        case .intro, .outro: VelaStrings.skipIntro
        case .recap: VelaStrings.skipRecap
        case .preview: VelaStrings.skipPreview
        case .commercial: VelaStrings.skipCommercial
        }
    }
}

extension VelaPlaybackPromptOverlay {

    private struct PromptButton: View {

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState

        let title: String
        var subtitle: String? = nil
        let systemImage: String

        var body: some View {
            Button {
                VelaPlaybackPrompts.shared.performPrompt()
                containerState.timer.poke()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 28, weight: .semibold))

                        if let subtitle, subtitle.isNotEmpty {
                            Text(subtitle)
                                .font(.system(size: 20, weight: .medium))
                                .lineLimit(1)
                                .opacity(0.8)
                        }
                    }
                }
                .font(.system(size: 26, weight: .semibold))
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
            }
            .buttonStyle(PromptButtonStyle(isArmed: !containerState.isPresentingOverlay))
            // Hidden controls: the container's select hook triggers the prompt instead of focus.
            .disabled(!containerState.isPresentingOverlay)
            .frame(maxWidth: 620, alignment: .trailing)
        }
    }

    /// White when select would trigger it (controls hidden) or when focused.
    private struct PromptButtonStyle: ButtonStyle {

        @Environment(\.isFocused)
        private var isFocused

        let isArmed: Bool

        func makeBody(configuration: Configuration) -> some View {
            let isHighlighted = isArmed || isFocused

            configuration.label
                .foregroundStyle(isHighlighted ? Color.black : Color.white)
                .background {
                    Capsule()
                        .fill(isHighlighted ? Color.white : Color.black.opacity(0.6))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(isHighlighted ? 0 : 0.35), lineWidth: 2)
                }
                .scaleEffect(configuration.isPressed ? 0.96 : (isFocused ? 1.06 : 1))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }

    /// Shown instead of "Nächste Folge" after the last episode in the library.
    private struct OutlookCard: View {

        let message: String

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(VelaSeriesOutlook.title)
                    .font(.system(size: 22, weight: .semibold))
                    .opacity(0.8)

                Text(message)
                    .font(.system(size: 28, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .frame(maxWidth: 640, alignment: .leading)
            .background(Color.black.opacity(0.65), in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        }
    }
}
