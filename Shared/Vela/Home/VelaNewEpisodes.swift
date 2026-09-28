//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Combine
import Defaults
import JellyfinAPI
import SwiftUI

/// Episodes that arrived after their series was last watched, as found by `VelaContinueLibrary`.
@MainActor
final class VelaNewEpisodes: ObservableObject {

    static let shared = VelaNewEpisodes()

    @Published
    private(set) var episodeIDs: Set<String> = []

    func update(_ ids: Set<String>) {
        guard ids != episodeIDs else { return }
        episodeIDs = ids
    }

    func contains(_ item: BaseItemDto) -> Bool {
        guard item.type == .episode, let id = item.id else { return false }
        return episodeIDs.contains(id)
    }
}

/// The "Neue Folge" badge in a poster's top leading corner.
struct VelaNewEpisodeBadge: View {

    @Default(.accentColor)
    private var accentColor

    @ObservedObject
    private var newEpisodes = VelaNewEpisodes.shared

    let item: BaseItemDto

    var body: some View {
        if newEpisodes.contains(item) {
            Text(VelaStrings.newEpisode)
                .font(.system(size: UIDevice.isTV ? 22 : 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, UIDevice.isTV ? 14 : 8)
                .padding(.vertical, UIDevice.isTV ? 6 : 3)
                .background(accentColor, in: .capsule)
                .padding(UIDevice.isTV ? 12 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityLabel(VelaStrings.newEpisode)
        }
    }
}
