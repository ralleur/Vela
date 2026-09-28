//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Defaults
import Foundation
import JellyfinAPI

/// Vela's Continue row; the rules live in `VelaContinueList`.
struct VelaContinueLibrary: BaseItemKindLibrary {

    let libraryItemTypes: [BaseItemKind] = [.episode, .movie, .video]
    let parent: TitledLibraryParent = .init(displayTitle: L10n.continue, id: "vela-continue")

    func retrievePage(
        environment: Empty,
        pageState: LibraryPageState
    ) async throws -> [BaseItemDto] {
        // Everything comes in one page; the lists are small.
        guard pageState.pageOffset == 0 else { return [] }

        async let resume = resumeItems(pageState: pageState)
        async let nextUp = nextUpItems(pageState: pageState)
        async let played = seriesLastPlayed(pageState: pageState)

        let resumeItems = try await resume
        var lastPlayed = try await played

        // Episodes in progress count as watching the series, too.
        for episode in resumeItems where episode.type == .episode {
            guard let seriesID = episode.seriesID, let date = episode.userData?.lastPlayedDate else { continue }
            lastPlayed[seriesID] = max(lastPlayed[seriesID] ?? .distantPast, date)
        }

        let result = try await VelaContinueList.merge(
            resume: resumeItems,
            nextUp: nextUp,
            seriesLastPlayed: lastPlayed,
            nextUpWindow: Defaults[.Customization.Home.maxNextUp]
        )

        var newEpisodeIDs = result.newEpisodeIDs

        #if DEBUG
        // Launch with `-VelaDebugMarkNextUpNew YES` to see the badge without waiting for a new episode.
        if UserDefaults.standard.bool(forKey: "VelaDebugMarkNextUpNew") {
            let resumeIDs = Set(resumeItems.compactMap(\.id))
            newEpisodeIDs.formUnion(result.items.filter { $0.type == .episode && !resumeIDs.contains($0.id ?? "") }.compactMap(\.id))
        }
        #endif

        VelaNewEpisodes.shared.update(newEpisodeIDs)

        return result.items
    }

    private func resumeItems(pageState: LibraryPageState) async throws -> [BaseItemDto] {
        var parameters = Paths.GetResumeItemsParameters()
        parameters.enableUserData = true
        parameters.fields = PosterSubtitleField.itemFields
        parameters.limit = 50
        parameters.mediaTypes = [.video]
        parameters.userID = pageState.userSession.user.id

        let response = try await pageState.userSession.client.send(Paths.getResumeItems(parameters: parameters))
        return response.value.items ?? []
    }

    /// Without a date cutoff, so series with a new episode come back however long ago
    /// they were watched; `VelaContinueList` applies the cutoff to the others.
    private func nextUpItems(pageState: LibraryPageState) async throws -> [BaseItemDto] {
        var parameters = Paths.GetNextUpParameters()
        parameters.enableRewatching = Defaults[.Customization.Home.resumeNextUp]
        parameters.enableUserData = true
        parameters.fields = PosterSubtitleField.itemFields + [.dateCreated]
        parameters.limit = 100
        parameters.userID = pageState.userSession.user.id

        let response = try await pageState.userSession.client.send(Paths.getNextUp(parameters: parameters))
        return response.value.items ?? []
    }

    /// When each series was last watched. Jellyfin has no such date on the series,
    /// so it comes from the most recently played episodes.
    private func seriesLastPlayed(pageState: LibraryPageState) async throws -> [String: Date] {
        var parameters = Paths.GetItemsParameters()
        parameters.enableUserData = true
        parameters.filters = [.isPlayed]
        parameters.includeItemTypes = [.episode]
        parameters.isRecursive = true
        parameters.limit = 500
        parameters.sortBy = [.datePlayed]
        parameters.sortOrder = [.descending]
        parameters.userID = pageState.userSession.user.id

        let response = try await pageState.userSession.client.send(Paths.getItems(parameters: parameters))

        var lastPlayed: [String: Date] = [:]
        for episode in response.value.items ?? [] {
            guard let seriesID = episode.seriesID, let date = episode.userData?.lastPlayedDate else { continue }
            lastPlayed[seriesID] = max(lastPlayed[seriesID] ?? .distantPast, date)
        }
        return lastPlayed
    }

    func onItemUserDataChanged(
        viewModel: PagingLibraryViewModel<VelaContinueLibrary>,
        userData: UserItemDataDto
    ) {
        guard let itemID = userData.itemID else { return }

        if viewModel.elements.contains(where: { $0.id == itemID }) {
            viewModel.scheduleRefreshForItemUserData(minimumInterval: 3)
            return
        }

        let hasResumePosition = (userData.playbackPositionTicks ?? 0) > 0
        guard hasResumePosition || userData.isPlayed != nil else { return }

        viewModel.scheduleRefreshForItemUserData(minimumInterval: 30)
    }
}
