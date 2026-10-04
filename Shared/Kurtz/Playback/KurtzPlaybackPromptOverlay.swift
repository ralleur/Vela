//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import JellyfinAPI
import SwiftUI

/// The prompt in the player's bottom trailing corner: skip intro, next episode,
/// what comes after the last episode, or favorite a film.
///
/// With the controls hidden the prompt looks selected. On tvOS the select button triggers it
/// (see the hook in `VideoPlayerContainerView`); on iOS and the Mac it can be clicked, and
/// Return triggers it (see `VideoPlayer+KeyCommands`). With the controls shown it is a normal
/// button above the toolbar.
struct KurtzPlaybackPromptOverlay: View {

    @Environment(\.safeAreaInsets)
    private var safeAreaInsets

    @EnvironmentObject
    private var containerState: VideoPlayerContainerState
    @EnvironmentObject
    private var manager: MediaPlayerManager

    @ObservedObject
    private var prompts = KurtzPlaybackPrompts.shared

    private var isHidden: Bool {
        containerState.isScrubbing || containerState.isPresentingSupplement
    }

    private var bottomPadding: CGFloat {
        if UIDevice.isTV {
            containerState.isPresentingOverlay ? 200 : 60
        } else {
            (containerState.isPresentingOverlay ? 110 : 40) + safeAreaInsets.bottom
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Keeps the overlay in the hierarchy when there is no prompt (an empty view never appears).
            Color.clear
                .allowsHitTesting(false)
                .onAppear {
                    prompts.attach(to: manager)
                }

            content
                .padding(.bottom, bottomPadding)
                .padding(.trailing, UIDevice.isTV ? 0 : safeAreaInsets.trailing)
                .edgePadding(.trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(isHidden ? 0 : 1)
        .animation(.easeInOut(duration: 0.25), value: prompts.prompt)
        .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingOverlay)
    }

    @ViewBuilder
    private var content: some View {
        switch prompts.prompt {
        case let .skip(kind, _):
            PromptButton(title: title(forSkipping: kind), systemImage: "forward.fill")
        case .endOfEpisode:
            if let nextEpisode = prompts.nextEpisode {
                PromptButton(
                    title: KurtzStrings.nextEpisode,
                    subtitle: [nextEpisode.seasonEpisodeLabel, nextEpisode.name].compactMap(\.self).joined(separator: " · "),
                    systemImage: "forward.end.fill"
                )
            } else if manager.queue?.hasNextItem == true {
                PromptButton(title: KurtzStrings.nextEpisode, systemImage: "forward.end.fill")
            } else if let outlook = prompts.outlook {
                OutlookCard(message: outlook)
            }
        case .endOfMovie:
            PromptButton(
                title: prompts.isFavorite ? KurtzStrings.isFavorite : KurtzStrings.markFavorite,
                systemImage: prompts.isFavorite ? "heart.fill" : "heart"
            )
        case nil:
            EmptyView()
        }
    }

    private func title(forSkipping kind: KurtzSegmentKind) -> String {
        switch kind {
        case .intro, .outro: KurtzStrings.skipIntro
        case .recap: KurtzStrings.skipRecap
        case .preview: KurtzStrings.skipPreview
        case .commercial: KurtzStrings.skipCommercial
        }
    }
}

extension KurtzPlaybackPromptOverlay {

    private struct PromptButton: View {

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState

        let title: String
        var subtitle: String?
        let systemImage: String

        var body: some View {
            Button {
                KurtzPlaybackPrompts.shared.performPrompt()
                containerState.timer.poke()
            } label: {
                HStack(spacing: UIDevice.isTV ? 14 : 10) {
                    Image(systemName: systemImage)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: UIDevice.isTV ? 28 : 17, weight: .semibold))

                        if let subtitle, subtitle.isNotEmpty {
                            Text(subtitle)
                                .font(.system(size: UIDevice.isTV ? 20 : 13, weight: .medium))
                                .lineLimit(1)
                                .opacity(0.8)
                        }
                    }
                }
                .font(.system(size: UIDevice.isTV ? 26 : 16, weight: .semibold))
                .padding(.horizontal, UIDevice.isTV ? 30 : 18)
                .padding(.vertical, UIDevice.isTV ? 16 : 10)
                .contentShape(.capsule)
            }
            .buttonStyle(PromptButtonStyle(isArmed: !containerState.isPresentingOverlay))
            // Hidden controls on tvOS: the container's select hook triggers the prompt instead of focus.
            .disabled(UIDevice.isTV && !containerState.isPresentingOverlay)
            .frame(maxWidth: UIDevice.isTV ? 620 : 380, alignment: .trailing)
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
                        .strokeBorder(Color.white.opacity(isHighlighted ? 0 : 0.35), lineWidth: UIDevice.isTV ? 2 : 1)
                }
                .scaleEffect(configuration.isPressed ? 0.96 : (isFocused ? 1.06 : 1))
                .shadow(color: .black.opacity(0.4), radius: UIDevice.isTV ? 16 : 8, y: UIDevice.isTV ? 6 : 3)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }

    /// Shown instead of "Nächste Folge" after the last episode in the library.
    private struct OutlookCard: View {

        let message: String

        var body: some View {
            VStack(alignment: .leading, spacing: UIDevice.isTV ? 8 : 4) {
                Text(KurtzSeriesOutlook.title)
                    .font(.system(size: UIDevice.isTV ? 22 : 13, weight: .semibold))
                    .opacity(0.8)

                Text(message)
                    .font(.system(size: UIDevice.isTV ? 28 : 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, UIDevice.isTV ? 30 : 18)
            .padding(.vertical, UIDevice.isTV ? 22 : 12)
            .frame(maxWidth: UIDevice.isTV ? 640 : 380, alignment: .leading)
            .background(Color.black.opacity(0.65), in: .rect(cornerRadius: UIDevice.isTV ? 24 : 14))
            .shadow(color: .black.opacity(0.4), radius: UIDevice.isTV ? 16 : 8, y: UIDevice.isTV ? 6 : 3)
        }
    }
}
