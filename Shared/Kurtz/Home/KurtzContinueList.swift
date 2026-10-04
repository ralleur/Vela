//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import JellyfinAPI

/// Builds kurtz's "Continue" row from Jellyfin's resume and next-up lists.
///
/// - Films show up only if they were played within the last 7 days.
/// - Series stay: the episode in progress, or the next episode.
/// - A next episode added after the series was last watched counts as new;
///   it moves to the front and gets the "Neue Folge" badge.
/// - Series without new episodes leave after Swiftfin's "Next Up" limit
///   (Settings → Customize → Home, one year by default).
enum KurtzContinueList {

    static let movieWindow: TimeInterval = 7 * 86400

    struct Result {
        let items: [BaseItemDto]
        let newEpisodeIDs: Set<String>
    }

    static func merge(
        resume: [BaseItemDto],
        nextUp: [BaseItemDto],
        seriesLastPlayed: [String: Date],
        now: Date = .now,
        movieWindow: TimeInterval = movieWindow,
        nextUpWindow: TimeInterval
    ) -> Result {
        var entries: [(item: BaseItemDto, date: Date)] = []
        var seriesInResume: Set<String> = []
        var newEpisodeIDs: Set<String> = []

        for item in resume {
            let lastPlayed = item.userData?.lastPlayedDate

            if item.type == .episode {
                if let seriesID = item.seriesID {
                    seriesInResume.insert(seriesID)
                }
                entries.append((item, lastPlayed ?? .distantPast))
            } else {
                guard let lastPlayed, now.timeIntervalSince(lastPlayed) <= movieWindow else { continue }
                entries.append((item, lastPlayed))
            }
        }

        var seenSeries = seriesInResume

        for episode in nextUp {
            guard let seriesID = episode.seriesID, !seenSeries.contains(seriesID) else { continue }

            let lastPlayed = seriesLastPlayed[seriesID]
            let added = episode.dateCreated

            let isNew: Bool = if let lastPlayed, let added {
                added > lastPlayed
            } else {
                false
            }

            // Like Jellyfin's own cutoff: a series nobody has a play date for is not being watched.
            let isRecent: Bool = if let lastPlayed {
                nextUpWindow <= 0 || now.timeIntervalSince(lastPlayed) <= nextUpWindow
            } else {
                false
            }

            guard isNew || isRecent else { continue }

            seenSeries.insert(seriesID)

            if isNew, let id = episode.id {
                newEpisodeIDs.insert(id)
            }

            let activity = [lastPlayed, isNew ? added : nil].compactMap(\.self).max() ?? .distantPast
            entries.append((episode, activity))
        }

        let items = entries
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.date == rhs.element.date ? lhs.offset < rhs.offset : lhs.element.date > rhs.element.date
            }
            .map(\.element.item)

        return Result(items: items, newEpisodeIDs: newEpisodeIDs)
    }
}
