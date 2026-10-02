//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela Mac file integration. Licensed under MPL-2.0.
#if targetEnvironment(macCatalyst)
import Combine
import Defaults
import FactoryKit
import PreferencesView
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VelaLocalFiles: NSObject, ObservableObject, UIDocumentPickerDelegate {
    static let shared = VelaLocalFiles()
    static let openFile = Notification.Name("VelaOpenFile")
    static let openSubtitle = Notification.Name("VelaOpenSubtitle")
    static let videoExtensions = ["mp4", "m4v", "mov", "mkv", "webm", "avi", "ts", "mts", "m2ts", "mpeg", "mpg", "wmv", "flv", "ogv"]
    static let subtitleExtensions = ["srt", "ass", "ssa", "vtt", "sub"]
    static var videoTypes: [UTType] {
        [.movie, .video] + videoExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static var subtitleTypes: [UTType] {
        subtitleExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    struct Recent: Codable, Identifiable {
        var url: URL
        var bookmark: Data?
        var position: Double = 0
        var audio: LocalTrackChoice?
        var subtitle: LocalTrackChoice?
        var id: String {
            url.absoluteString
        }
    }

    @Published
    private(set) var recent: [Recent] = []
    @Published
    var message: String? {
        didSet {
            if let message {
                showError(message)
            }
        }
    }

    @Published
    private(set) var activeManager: MediaPlayerManager?
    private var observer: AnyCancellable?
    private struct OpenRequest {
        let url: URL
        let attempt: LocalPlaybackAttempt
        var previous: LocalMediaPlayerItem?
        var position: Duration?
        var oldRecentURL: URL?
        var volume: Float = 1
        var muted = false
        var audioOffset: Duration = .zero
        var subtitleOffset: Duration = .zero
    }

    @Published
    private(set) var isOpening = false
    var isOpeningOrPlaying: Bool {
        // Account restoration must also wait for the player controller to finish
        // dismissing, after the stopped manager has left the playback publisher.
        isOpening || localController != nil || activeManager?.playbackItem is LocalMediaPlayerItem
    }

    private var pending: OpenRequest?
    private var opening: Task<Void, Never>?
    private var dismissal: Task<Void, Never>?
    private weak var localController: UIViewController?
    private let defaults = UserDefaults.standard
    private let recentKey = "vela.local.recent"

    override private init() {
        super.init()
        if let data = defaults.data(forKey: recentKey), let saved = try? JSONDecoder().decode([Recent].self, from: data) {
            recent = saved
        }
        observer = Container.shared.mediaPlayerManagerPublisher().sink { [weak self] manager in
            self?.activeManager = manager
            UIMenuSystem.main.setNeedsRebuild()
        }
    }

    private func showError(_ message: String) {
        guard var presenter = Self.rootController else { return }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        guard !(presenter is UIAlertController) else { return }
        let alert = UIAlertController(title: VelaStrings.text("Unable to Open Media"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.message = nil })
        alert.addAction(UIAlertAction(title: VelaStrings.text("Choose Another Video…"), style: .default) { [weak self] _ in
            self?.message = nil
            self?.showPicker(subtitle: false)
        })
        presenter.present(alert, animated: true)
    }

    func savePosition(
        _ position: Duration,
        duration: Duration?,
        for url: URL,
        audio: LocalTrackChoice? = nil,
        subtitle: LocalTrackChoice? = nil
    ) {
        guard defaults.object(forKey: "vela.local.history") as? Bool != false else { return }
        guard let index = recent.firstIndex(where: { $0.url == url }) else { return }
        let seconds = position.seconds
        recent[index].position = LocalPlaybackPolicy.resumePosition(seconds, duration: duration?.seconds)
        if let audio {
            recent[index].audio = audio
        }
        if let subtitle {
            recent[index].subtitle = subtitle
        }
        persist()
    }

    func removeRecent(_ entry: Recent) {
        recent.removeAll { $0.id == entry.id }
        persist()
        UIMenuSystem.main.setNeedsRebuild()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: recentKey)
        }
    }

    func reopen(_ entry: Recent) {
        var stale = false
        let resolved = entry.bookmark.flatMap {
            try? URL(resolvingBookmarkData: $0, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        // Refresh the bookmark on open and carry history across a Finder move.
        enqueue(.init(url: resolved ?? entry.url, attempt: preferredAttempt, oldRecentURL: entry.url))
    }

    func clearRecent() {
        recent = []
        persist()
        UIMenuSystem.main.setNeedsRebuild()
    }

    private var preferredAttempt: LocalPlaybackAttempt {
        .init(engine: defaults.string(forKey: "vela.local.engine") == "mpv" ? .mpv : .vlc)
    }

    func open(_ url: URL, using player: VideoPlayerType? = nil) {
        if Self.subtitleExtensions.contains(url.pathExtension.lowercased()) {
            attachSubtitle(url)
            return
        }
        enqueue(.init(url: url, attempt: player.map { .init(engine: $0 == .mpv ? .mpv : .vlc) } ?? preferredAttempt))
    }

    private func enqueue(_ request: OpenRequest) {
        pending = request
        isOpening = true
        processPending()
    }

    /// A single worker owns teardown/presentation. New requests replace pending work,
    /// never cancel an in-flight UIKit dismissal continuation.
    func processPending() {
        guard opening == nil, Self.rootController != nil, pending != nil else { return }
        opening = Task { @MainActor in
            while let request = pending {
                pending = nil
                await openRequest(request)
            }
            opening = nil
            isOpening = false
        }
    }

    private func openRequest(_ request: OpenRequest) async {
        do {
            let access = try LocalFileAccess(url: request.url)
            let previous = activeManager
            await previous?.stop()
            await dismissal?.value
            if let controller = localController {
                await dismiss(controller)
            } else if previous != nil, let controller = Self.rootController?.presentedViewController {
                await dismiss(controller)
            }
            guard pending == nil else { return }
            let saved = recent.first { $0.url == (request.oldRecentURL ?? request.url) }
            let position = request.position ?? .seconds(saved?.position ?? 0)
            let item = LocalMediaPlayerItem(
                access: access,
                start: position,
                audio: request.previous?.currentAudioChoice ?? saved?.audio,
                subtitle: request.previous?.currentSubtitleChoice ?? saved?.subtitle,
                carrying: request.previous
            )
            if defaults.object(forKey: "vela.local.history") as? Bool != false {
                let bookmark = try? request.url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                recent.removeAll { $0.url == request.url || $0.url == request.oldRecentURL }
                recent.insert(Recent(
                    url: request.url,
                    bookmark: bookmark,
                    position: position.seconds,
                    audio: saved?.audio,
                    subtitle: saved?.subtitle
                ), at: 0)
                recent = Array(recent.prefix(20))
                persist()
            }
            let manager = MediaPlayerManager(playbackItem: item)
            manager.preferredPlayer = request.attempt.engine == .mpv ? .mpv : .vlc
            manager.volume = request.volume
            manager.isMuted = request.muted
            manager.audioOffset = request.audioOffset
            manager.subtitleOffset = request.subtitleOffset
            let attempt = request.attempt
            if !request.attempt.hasRetried {
                manager.retryPlayback = { [weak self, weak manager] in
                    guard let manager else { return }
                    self?.retry(manager, attempt: attempt)
                }
            }
            await present(manager)
        } catch {
            if pending == nil {
                message = error.localizedDescription
            }
        }
        UIMenuSystem.main.setNeedsRebuild()
    }

    private func dismiss(_ controller: UIViewController) async {
        guard controller.presentingViewController != nil else { return }
        await withCheckedContinuation { continuation in
            controller.dismiss(animated: false) { continuation.resume() }
        }
    }

    private func retry(_ manager: MediaPlayerManager, attempt: LocalPlaybackAttempt) {
        guard activeManager === manager, let item = manager.playbackItem as? LocalMediaPlayerItem else { return }
        var next = attempt
        guard next.retry() != nil else { return }
        manager.retryPlayback = nil
        enqueue(.init(
            url: item.url,
            attempt: next,
            previous: item,
            position: manager.seconds,
            volume: manager.volume,
            muted: manager.isMuted,
            audioOffset: manager.audioOffset,
            subtitleOffset: manager.subtitleOffset
        ))
    }

    func switchEngine() {
        activeManager?.retryPlayback?()
    }

    private func present(_ manager: MediaPlayerManager) async {
        guard let root = Self.rootController else {
            message = "The player window is not ready. Try opening the file again."
            return
        }
        Container.shared.mediaPlayerManager.register { manager }
        Container.shared.mediaPlayerManagerPublisher().send(manager)
        let controller = UIPreferencesHostingController {
            OverlayToastView {
                NavigationInjectionView(coordinator: .init()) {
                    VideoPlayerViewShim(manager: manager)
                        .modifier(VelaFileDrop())
                }
            }
        }
        controller.modalPresentationStyle = .fullScreen
        controller.isModalInPresentation = true
        localController = controller
        manager.onStop = { [weak self, weak controller] in
            guard let self, let controller else { return }
            dismissal = Task { @MainActor [weak self] in
                await withCheckedContinuation { continuation in
                    controller.dismiss(animated: false) { continuation.resume() }
                }
                if self?.localController === controller {
                    self?.localController = nil
                }
            }
        }
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        await withCheckedContinuation { continuation in
            presenter.present(controller, animated: false) { continuation.resume() }
        }
    }

    private static var rootController: UIViewController? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    }

    private var choosingSubtitle = false
    func showPicker(subtitle: Bool) {
        guard var presenter = Self.rootController else { return }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        if presenter is UIAlertController {
            presenter.dismiss(animated: true) { [weak self] in self?.showPicker(subtitle: subtitle) }
            return
        }
        choosingSubtitle = subtitle
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: subtitle ? Self.subtitleTypes : Self.videoTypes, asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let subtitle = choosingSubtitle
        let selected: () -> Void = { [weak self] in
            if subtitle {
                self?.attachSubtitle(url)
            } else {
                self?.open(url)
            }
        }
        // Catalyst may have already dismissed its native panel before this callback.
        if let transition = controller.transitionCoordinator, controller.isBeingDismissed {
            transition.animate(alongsideTransition: nil) { _ in selected() }
        } else if controller.presentingViewController != nil {
            controller.dismiss(animated: false, completion: selected)
        } else {
            selected()
        }
    }

    func attachSubtitle(_ url: URL) {
        do {
            guard let manager = activeManager, let item = manager.playbackItem,
                  let proxy = manager.proxy as? any MediaPlayerSubtitleTrackConfigurable
            else {
                throw ErrorMessage("Open a video before adding subtitles.")
            }
            guard item.discoversTracks else {
                throw ErrorMessage("This playback source does not support attaching subtitle files.")
            }
            let access = try LocalFileAccess(url: url)
            try proxy.attachSubtitle(url)
            // Keep the subtitle lease with the media item for the complete playback session.
            if let local = item as? LocalMediaPlayerItem {
                local.retainSubtitle(access)
            } else {
                item.retainedResources.append(access)
            }
        } catch { message = error.localizedDescription }
    }
}

struct VelaFileDrop: ViewModifier {
    @ObservedObject
    private var files = VelaLocalFiles.shared
    @State
    private var targeted = false
    func body(content: Content) -> some View {
        content.onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                if let url {
                    Task { @MainActor in files.open(url) }
                }
            }
            return true
        }
        .overlay {
            if targeted {
                RoundedRectangle(cornerRadius: 12).stroke(.orange, lineWidth: 3).allowsHitTesting(false)
            }
        }
    }
}

struct VelaFileHost: ViewModifier {
    @ObservedObject
    private var files = VelaLocalFiles.shared
    func body(content: Content) -> some View {
        content
            .modifier(VelaFileDrop())
            .onAppear { files.processPending()
                UIMenuSystem.main.setNeedsRebuild()
            }
            .onOpenURL {
                url in if url.isFileURL {
                    files.open(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: VelaLocalFiles.openFile)) { _ in files.showPicker(subtitle: false) }
            .onReceive(NotificationCenter.default.publisher(for: VelaLocalFiles.openSubtitle)) { _ in files.showPicker(subtitle: true) }
    }
}

struct VelaWelcomeView: View {
    @State
    private var showServers = false
    @ObservedObject
    private var files = VelaLocalFiles.shared
    var body: some View {
        VStack(spacing: 24) {
            Image("VelaWatermark").resizable().scaledToFit().frame(width: 100, height: 100).accessibilityHidden(true)
            Text(VelaStrings.text("Open a video.")).font(.largeTitle.bold())
            Text(VelaStrings.text("Drop a video anywhere in this window, or choose a file.")).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button(VelaStrings.text("Open Video…")) { NotificationCenter.default.post(name: VelaLocalFiles.openFile, object: nil) }
                    .buttonStyle(.borderedProminent)
                Button(VelaStrings.text("Connect Jellyfin")) { showServers = true }.buttonStyle(.bordered)
            }
            if !files.recent.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(VelaStrings.text("Recently Opened")).font(.headline)
                    ForEach(files.recent.prefix(5)) { entry in
                        Button { files.reopen(entry) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.rectangle").font(.title2).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.url.lastPathComponent).lineLimit(1)
                                    Text(entry.url.deletingLastPathComponent().lastPathComponent).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if entry.position > 5 {
                                    Text(Duration.seconds(entry.position), format: .minuteSecondsNarrow).font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .contextMenu {
                                Button(VelaStrings.text("Start Over")) {
                                    files.savePosition(.zero, duration: nil, for: entry.url)
                                    files.reopen(entry)
                                }
                                Button(VelaStrings.text("Remove from Recent")) { files.removeRecent(entry) }
                            }
                    }
                }.frame(maxWidth: 480, alignment: .leading).padding(.top)
            }
            Text(VelaStrings.text("No account needed for local videos.")).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
            .sheet(isPresented: $showServers) {
                NavigationInjectionView(coordinator: .init()) { SelectUserView() }
            }
    }
}
#endif
