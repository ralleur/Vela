//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Combine
import FactoryKit
import Foundation
import Get
import JellyfinAPI
import Logging

/// Follows the playing item and decides which prompt the player shows:
/// skip intro/recap, next episode (or what is known about it), or favorite a film.
///
/// There is one player at a time, so one shared instance is enough; the view attaches it
/// to the current `MediaPlayerManager` and the select-press hook asks it to act.
@MainActor
final class VelaPlaybackPrompts: ObservableObject {

    static let shared = VelaPlaybackPrompts()

    @Published
    private(set) var prompt: VelaPlaybackPrompt?
    @Published
    private(set) var isFavorite = false
    /// The next episode in the library, if there is one.
    @Published
    private(set) var nextEpisode: BaseItemDto?
    /// Loaded once the credits of the last available episode start.
    @Published
    private(set) var outlook: String?

    private weak var manager: MediaPlayerManager?
    private var item: BaseItemDto?
    private var content: VelaPromptPolicy.Content = .other
    private var duration: TimeInterval = 0
    private var segments: [VelaSegment] = []
    private var isOutlookRequested = false

    private var cancellables: Set<AnyCancellable> = []
    private var loadTask: Task<Void, Never>?

    private let logger = Logger.swiftfin()

    func attach(to manager: MediaPlayerManager) {
        guard self.manager !== manager else { return }

        self.manager = manager
        cancellables = []

        manager.$playbackItem
            .sink { [weak self] playbackItem in
                self?.load(playbackItem)
            }
            .store(in: &cancellables)

        manager.secondsBox.$value
            .sink { [weak self] seconds in
                self?.update(time: seconds / .seconds(1))
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Performs the visible prompt's action. Returns `false` when there is nothing to do,
    /// so the press keeps its usual meaning.
    @discardableResult
    func performPrompt() -> Bool {
        guard let manager, let prompt else { return false }

        switch prompt {
        case let .skip(_, to):
            let target = Duration.seconds(to)
            manager.proxy?.setSeconds(target)
            manager.seconds = target
            return true
        case .endOfEpisode:
            return playNextEpisode(manager: manager)
        case .endOfMovie:
            toggleFavorite()
            return true
        }
    }

    private func playNextEpisode(manager: MediaPlayerManager) -> Bool {
        if let provider = manager.queue?.nextItem {
            manager.playNewItem(provider: provider)
            return true
        }

        guard let nextEpisode,
              let provider = nextEpisode.getPlaybackItemProvider(userSession: Container.shared.currentUserSession())
        else { return false }

        manager.playNewItem(provider: provider)
        return true
    }

    func toggleFavorite() {
        guard let itemID = item?.id, let userSession = Container.shared.currentUserSession() else { return }

        let newValue = !isFavorite
        isFavorite = newValue

        Task {
            do {
                let request: Request<UserItemDataDto> = newValue
                    ? Paths.markFavoriteItem(itemID: itemID, userID: userSession.user.id)
                    : Paths.unmarkFavoriteItem(itemID: itemID, userID: userSession.user.id)
                let response = try await userSession.client.send(request)
                Notifications[.itemUserDataDidChange].post(response.value)
            } catch {
                logger.error("Favorite toggle failed: \(error.localizedDescription)")
                isFavorite = !newValue
            }
        }
    }

    // MARK: - State

    private func load(_ playbackItem: MediaPlayerItem?) {
        loadTask?.cancel()
        prompt = nil
        segments = []
        nextEpisode = nil
        outlook = nil
        isOutlookRequested = false

        guard let playbackItem = playbackItem as? JellyfinMediaPlayerItem else {
            item = nil
            return
        }

        let baseItem = playbackItem.baseItem
        item = baseItem
        isFavorite = baseItem.userData?.isFavorite ?? false
        duration = Double(baseItem.runTimeTicks ?? 0) / 10_000_000
        content = switch baseItem.type {
        case .episode: .episode
        case .movie: .movie
        default: .other
        }

        let content = content
        let chapterSegments = VelaChapterSegments.segments(
            chapters: (baseItem.chapters ?? []).map { ($0.name, Double($0.startPositionTicks ?? 0) / 10_000_000) },
            duration: duration
        )
        // Chapter names only mark credits in films; "Main Title" there can be minutes of story.
        .filter { content == .episode || $0.kind == .outro }

        loadTask = Task { [weak self] in
            let serverSegments = await Self.serverSegments(for: baseItem)
            let nextEpisode = content == .episode ? await Self.nextEpisode(after: baseItem) : nil

            guard !Task.isCancelled, let self else { return }

            self.segments = VelaChapterSegments.merge(server: serverSegments, chapters: chapterSegments)
            self.nextEpisode = nextEpisode
        }
    }

    private func update(time: TimeInterval) {
        let newPrompt = VelaPromptPolicy.prompt(at: time, segments: segments, duration: duration, content: content)

        if newPrompt != prompt {
            prompt = newPrompt
        }

        if newPrompt == .endOfEpisode, nextEpisode == nil, manager?.queue?.hasNextItem != true, !isOutlookRequested {
            requestOutlook()
        }
    }

    private func requestOutlook() {
        guard let item, let seriesID = item.seriesID, let userSession = Container.shared.currentUserSession() else { return }

        isOutlookRequested = true
        let itemID = item.id

        Task { [weak self] in
            let series = try? await userSession.client.send(Paths.getItem(itemID: seriesID, userID: userSession.user.id)).value
            let show = await VelaTVmaze.show(providerIDs: series?.providerIDs ?? [:])

            let message: String = if let show, let season = item.parentIndexNumber, let episode = item.indexNumber {
                VelaSeriesOutlook.message(afterSeason: season, episode: episode, show: show)
            } else {
                VelaSeriesOutlook.fallbackMessage(jellyfinStatus: series?.status, season: item.parentIndexNumber)
            }

            guard let self, self.item?.id == itemID else { return }
            self.outlook = message
        }
    }

    // MARK: - Loading

    private static func serverSegments(for item: BaseItemDto) async -> [VelaSegment] {
        guard let itemID = item.id, let userSession = Container.shared.currentUserSession() else { return [] }

        let response = try? await userSession.client.send(Paths.getItemSegments(itemID: itemID))

        return (response?.value.items ?? []).compactMap { segment in
            guard let start = segment.startTicks, let end = segment.endTicks, end > start else { return nil }

            let kind: VelaSegmentKind? = switch segment.type {
            case .intro: .intro
            case .recap: .recap
            case .outro: .outro
            case .preview: .preview
            case .commercial: .commercial
            default: nil
            }

            return kind.map { VelaSegment(kind: $0, start: Double(start) / 10_000_000, end: Double(end) / 10_000_000) }
        }
    }

    /// The episode after this one, across seasons, from the library.
    private static func nextEpisode(after item: BaseItemDto) async -> BaseItemDto? {
        guard let itemID = item.id, let seriesID = item.seriesID,
              let userSession = Container.shared.currentUserSession()
        else { return nil }

        var parameters = Paths.GetEpisodesParameters()
        parameters.userID = userSession.user.id
        parameters.adjacentTo = itemID
        parameters.enableUserData = true

        guard let episodes = try? await userSession.client.send(Paths.getEpisodes(seriesID: seriesID, parameters: parameters))
            .value.items,
            let index = episodes.firstIndex(where: { $0.id == itemID }),
            episodes.indices.contains(index + 1)
        else { return nil }

        return episodes[index + 1]
    }
}

#if DEBUG
extension VelaPlaybackPrompts {

    /// State summary for `VelaDebugSnapshot`.
    var debugSummary: String {
        "prompt=\(String(describing: prompt)) attached=\(manager != nil) item=\(item?.name ?? "-") content=\(content) "
            + "duration=\(duration) segments=\(segments) nextEpisode=\(nextEpisode?.name ?? "-") outlook=\(outlook ?? "-") "
            + "seconds=\(manager.map { $0.seconds / .seconds(1) } ?? -1)"
    }
}
#endif
