//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

/// kurtz's home screen: Continue on top, then recently added and newest films and series.
struct KurtzHomeContentGroupProvider: ContentGroupProvider {

    @Injected(\.currentUserSession)
    var userSession: UserSession?

    let displayTitle: String = L10n.home
    let id: String = "kurtz-home-content-group-provider"

    func makeGroups(environment: Empty) async throws -> [any ContentGroup] {
        #if DEBUG && targetEnvironment(macCatalyst)
        await KurtzDebugSnapshot.install()
        #endif

        guard userSession != nil else { return [] }
        return _makeGroups()
    }

    @ContentGroupBuilder
    private func _makeGroups() -> [any ContentGroup] {

        #if os(tvOS)
        KurtzContinueContentGroup()
        #else
        PosterGroup(
            id: "kurtz-continue",
            library: KurtzContinueLibrary(),
            posterDisplayType: .landscape,
            posterSize: .medium,
            _viewContext: .isInResume
        )
        #endif

        itemRow(
            id: "kurtz-recently-added-movies",
            title: KurtzStrings.recentlyAddedMovies,
            itemType: .movie,
            sortBy: .dateCreated
        )

        itemRow(
            id: "kurtz-recently-added-series",
            title: KurtzStrings.recentlyAddedSeries,
            itemType: .series,
            sortBy: .dateLastContentAdded
        )

        itemRow(
            id: "kurtz-newest-movies",
            title: KurtzStrings.newestMovies,
            itemType: .movie,
            sortBy: .premiereDate
        )

        itemRow(
            id: "kurtz-newest-series",
            title: KurtzStrings.newestSeries,
            itemType: .series,
            sortBy: .premiereDate
        )

        if Defaults[.Customization.Home.showRecentlyPlayed] {
            PosterGroup(
                id: "kurtz-recently-played",
                library: ItemLibrary(
                    parent: BaseItemDto(name: L10n.recentlyPlayed.localizedCapitalized),
                    filters: .init(
                        itemTypes: [.movie, .series],
                        sortBy: [.datePlayed],
                        sortOrder: [.descending],
                        traits: [.isPlayed]
                    )
                )
            )
        }

        PosterGroup(
            id: "programs-recommended",
            library: RecommendedProgramsLibrary(),
            posterDisplayType: .landscape,
            posterSize: .small
        )
    }

    private func itemRow(
        id: String,
        title: String,
        itemType: BaseItemKind,
        sortBy: ItemSortBy
    ) -> PosterGroup<ItemLibrary> {
        PosterGroup(
            id: id,
            library: ItemLibrary(
                parent: BaseItemDto(name: title),
                filters: .init(
                    itemTypes: [itemType],
                    sortBy: [sortBy],
                    sortOrder: [.descending]
                )
            )
        )
    }
}

#if os(tvOS)

/// The large Continue selector at the top of the home screen, fed by `KurtzContinueLibrary`.
///
/// Mirrors Swiftfin's `CinematicSelectionContentGroup`, which is tied to its own resume library.
struct KurtzContinueContentGroup: ContentGroup {

    let id = "kurtz-continue"
    let viewModel: PagingLibraryViewModel<KurtzContinueLibrary>

    var _shouldBeResolved: Bool {
        viewModel.elements.isNotEmpty
    }

    init() {
        self.viewModel = PagingLibraryViewModel(library: KurtzContinueLibrary(), pageSize: 50)
    }

    func body(with viewModel: PagingLibraryViewModel<KurtzContinueLibrary>) -> some View {
        SelectionView(viewModel: viewModel)
    }

    private struct SelectionView: View {

        @ObservedObject
        var viewModel: PagingLibraryViewModel<KurtzContinueLibrary>

        @Router
        private var router

        private static let logoMaxHeight: CGFloat = 100
        private static let logoMaxWidth: CGFloat = 450

        private func logoSource(for item: BaseItemDto) -> ImageSource? {
            let options = ImageSourceOptions(maxWidth: Self.logoMaxWidth, maxHeight: Self.logoMaxHeight)

            if item.type == .episode {
                return item.imageSource(.logo, itemID: item.parentLogoItemID, tag: item.parentLogoImageTag, environment: options)
            }

            return item.imageSource(.logo, itemID: item.id, environment: options)
        }

        var body: some View {
            CinematicItemSelector(items: viewModel.elements.elements) { item in
                router.route(to: .item(item: item))
            } topContent: { item in
                ImageView(logoSource(for: item))
                    .placeholder { _ in
                        EmptyView()
                    }
                    .failure {
                        Text(item.displayTitle)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                    }
                    .edgePadding(.leading)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: Self.logoMaxHeight, alignment: .bottomLeading)
                    .frame(maxWidth: Self.logoMaxWidth)
            }
            .preference(
                key: ContentGroupCustomizationKey.self,
                value: .ignoreSafeAreaTop
            )
        }
    }
}

#endif
