//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

/// Texts for the kurtz additions. Kept out of Swiftfin's generated strings so
/// upstream translation updates never conflict with them.
enum KurtzStrings {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Kurtz")
    }

    static let newEpisode = text("New Episode")

    static let recentlyAddedMovies = text("Recently Added: Movies")
    static let recentlyAddedSeries = text("Recently Added: Series")
    static let newestMovies = text("Newest Movies")
    static let newestSeries = text("Newest Series")

    static let skipIntro = text("Skip Intro")
    static let skipRecap = text("Skip Recap")
    static let skipPreview = text("Skip Preview")
    static let skipCommercial = text("Skip Commercial")
    static let nextEpisode = text("Next Episode")
    static let markFavorite = text("Mark as Favorite")
    static let isFavorite = text("Favorite")
    static let promptKeyCommand = text("Perform Playback Prompt")
    static let pictureInPicture = text("Mini Player")
    static let pictureInPictureStop = text("Exit Mini Player")
    static let macWindow = text("Mac Window")
    static let showPlayerWindowTitle = text("Show kurtz Logo in Window")
    static let showPlayerWindowTitleDescription =
        text("Subtle logo at the top left. Always hidden in fullscreen.")
}
