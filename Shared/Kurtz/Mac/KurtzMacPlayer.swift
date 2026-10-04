//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

#if targetEnvironment(macCatalyst)

import ObjectiveC
import UIKit

/// Mac window behaviour while the player is on screen:
/// - the window's toolbar (title and tabs) is hidden, also in full screen,
/// - the content is locked to the video's aspect ratio and the old frame is restored on exit,
/// - the traffic-light buttons follow the visibility of the playback controls,
/// - the window can be dragged from anywhere in the player,
/// - a right click opens a menu with play/pause and "Bild in Bild".
struct KurtzMacPlayerSupport: View {

    @EnvironmentObject
    private var manager: MediaPlayerManager
    @EnvironmentObject
    private var containerState: VideoPlayerContainerState

    @Default(.Kurtz.Mac.showPlayerWindowTitle)
    private var showPlayerWindowTitle

    @State
    private var decodedVideoSize: CGSize = .zero

    private var declaredVideoSize: CGSize {
        if decodedVideoSize.width > 0, decodedVideoSize.height > 0 {
            return decodedVideoSize
        }
        guard let stream = manager.playbackItem?.videoStreams.first else { return .zero }

        if let aspectRatio = stream.aspectRatio {
            let components = aspectRatio.split(whereSeparator: { $0 == ":" || $0 == "/" })
            if components.count == 2,
               let width = Double(components[0]),
               let height = Double(components[1]),
               width > 0,
               height > 0
            {
                return CGSize(width: CGFloat(width), height: CGFloat(height))
            }
        }

        guard let width = stream.width, let height = stream.height, width > 0, height > 0 else { return .zero }
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    var body: some View {
        WindowAccessor(
            manager: manager,
            videoSize: declaredVideoSize,
            controlsVisible: containerState.isPresentingOverlay,
            showPlayerWindowTitle: showPlayerWindowTitle
        )
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive((manager.proxy as? any VideoMediaPlayerProxy)?.videoSize.$value.eraseToAnyPublisher()
            ?? Just(CGSize.zero).eraseToAnyPublisher()) { decodedVideoSize = $0 }
    }

    private struct WindowAccessor: UIViewRepresentable {

        let manager: MediaPlayerManager
        let videoSize: CGSize
        let controlsVisible: Bool
        let showPlayerWindowTitle: Bool

        func makeUIView(context: Context) -> SupportView {
            SupportView(
                manager: manager,
                videoSize: videoSize,
                controlsVisible: controlsVisible,
                showPlayerWindowTitle: showPlayerWindowTitle
            )
        }

        func updateUIView(_ uiView: SupportView, context: Context) {
            uiView.manager = manager
            uiView.update(
                videoSize: videoSize,
                controlsVisible: controlsVisible,
                showPlayerWindowTitle: showPlayerWindowTitle
            )
        }

        static func dismantleUIView(_ uiView: SupportView, coordinator: ()) {
            // SwiftUI may keep the hosting UIWindow while removing the player hierarchy,
            // so didMoveToWindow is not guaranteed to receive a final nil window.
            uiView.detachFromWindow()
        }
    }

    final class SupportView: UIView, UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {

        weak var manager: MediaPlayerManager?

        private weak var attachedWindow: UIWindow?
        private weak var menuHost: UIView?
        private var contextMenu: UIContextMenuInteraction?
        private var dragGesture: UIPanGestureRecognizer?
        private var dragOrigin: (mouse: CGPoint, frame: CGRect)?
        private var windowObservers: [NSObjectProtocol] = []
        private var isChangingFullScreen = false
        private let watermark = UIImageView(image: UIImage(named: "KurtzPlayerMark"))
        private var savedTitleVisibility: UITitlebarTitleVisibility?
        private var savedTabBarHidden: Bool?
        private var appKitWindow: NSObject?
        private var savedWindowFrame: CGRect?
        private var savedWindowTitle: String?
        private var savedAppKitTitleVisibility: Int?
        private var savedContentAspectRatio: CGSize?
        private var savedContentResizeIncrements: CGSize?
        private var savedCollectionBehavior: UInt?
        private var savedWindowButtonHidden: [UInt: Bool] = [:]
        private weak var fullScreenButton: NSObject?
        private var savedFullScreenTarget: AnyObject?
        private var savedFullScreenAction: Selector?
        private var lockedAspectRatio: CGFloat?
        private var videoSize: CGSize
        private var controlsVisible: Bool
        private var showPlayerWindowTitle: Bool

        init(
            manager: MediaPlayerManager,
            videoSize: CGSize,
            controlsVisible: Bool,
            showPlayerWindowTitle: Bool
        ) {
            self.manager = manager
            self.videoSize = videoSize
            self.controlsVisible = controlsVisible
            self.showPlayerWindowTitle = showPlayerWindowTitle
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if let window {
                attach(to: window)
            } else {
                detach()
            }
        }

        func update(videoSize: CGSize, controlsVisible: Bool, showPlayerWindowTitle: Bool) {
            self.videoSize = videoSize
            self.controlsVisible = controlsVisible
            self.showPlayerWindowTitle = showPlayerWindowTitle
            updateAppKitWindow()
        }

        func detachFromWindow() {
            detach()
        }

        // MARK: Window chrome

        private func attach(to window: UIWindow) {
            guard attachedWindow !== window else { return }
            detach()
            attachedWindow = window

            if let appKitWindow = KurtzMiniPlayer.appKitWindow(for: window) {
                self.appKitWindow = appKitWindow
                savedWindowFrame = KurtzMiniPlayer.frame(of: appKitWindow)
                let currentWindowTitle = appKitWindow.value(forKey: "title") as? String
                savedWindowTitle = currentWindowTitle?.isEmpty == false
                    ? currentWindowTitle
                    : Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                savedAppKitTitleVisibility = (appKitWindow.value(forKey: "titleVisibility") as? NSNumber)?.intValue
                savedContentAspectRatio = KurtzMiniPlayer.sizeValue("contentAspectRatio", on: appKitWindow)
                savedContentResizeIncrements = KurtzMiniPlayer.sizeValue("contentResizeIncrements", on: appKitWindow)
                for buttonType in KurtzMiniPlayer.standardWindowButtonTypes {
                    if let button = KurtzMiniPlayer.standardWindowButton(buttonType, on: appKitWindow) {
                        savedWindowButtonHidden[buttonType] = button.value(forKey: "hidden") as? Bool ?? false
                    }
                }
            }

            if let titlebar = window.windowScene?.titlebar {
                savedTitleVisibility = titlebar.titleVisibility
                titlebar.titleVisibility = .hidden
            }

            // The tab bar controller puts the tabs into the window's toolbar; hiding the
            // tab bar removes that toolbar.
            if let tabBarController = Self.tabBarController(in: window) {
                savedTabBarHidden = tabBarController.isTabBarHidden
                tabBarController.isTabBarHidden = true
            }

            // The menu goes on the player's full-size view that holds this one (a menu on the
            // window itself is requested but never shown).
            var host: UIView = self
            while let superview = host.superview, !(superview is UIWindow) {
                host = superview
                if host.bounds.size == window.bounds.size {
                    break
                }
            }
            let interaction = UIContextMenuInteraction(delegate: self)
            host.addInteraction(interaction)
            let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(dragWindow(_:)))
            dragGesture.delegate = self
            host.addGestureRecognizer(dragGesture)
            // Supplements and seeking already use pan gestures. Window dragging wins when
            // the pointer moves, while ordinary clicks still reach the player unchanged.
            for recognizer in Self.descendantPanGestures(in: host) where recognizer !== dragGesture {
                recognizer.require(toFail: dragGesture)
            }
            menuHost = host
            contextMenu = interaction
            self.dragGesture = dragGesture
            watermark.contentMode = .scaleAspectFit
            watermark.alpha = 0.35
            watermark.isUserInteractionEnabled = false
            // A discreet station-style mark anchored to the upper-left picture edge.
            watermark.frame = CGRect(x: 14, y: 24, width: 40, height: 33)
            window.addSubview(watermark)
            if let appKitWindow {
                for name in [
                    "NSWindowWillEnterFullScreenNotification",
                    "NSWindowWillExitFullScreenNotification",
                    "NSWindowDidEnterFullScreenNotification",
                    "NSWindowDidExitFullScreenNotification",
                    "NSWindowDidFailToEnterFullScreenNotification"
                ] {
                    windowObservers.append(NotificationCenter.default.addObserver(
                        forName: Notification.Name(name), object: appKitWindow, queue: .main
                    ) { [weak self] notification in
                        MainActor.assumeIsolated {
                            guard let self, let native = self.appKitWindow else { return }
                            if notification.name.rawValue.contains("Will") {
                                self.isChangingFullScreen = true
                                self.watermark.isHidden = true
                                KurtzMiniPlayer.setContentSize(
                                    CGSize(width: 1, height: 1),
                                    selector: "setContentResizeIncrements:",
                                    on: native
                                )
                            } else {
                                self.isChangingFullScreen = false
                                self.lockedAspectRatio = nil
                                self.updateAppKitWindow()
                            }
                        }
                    })
                }
                let behavior = appKitWindow.value(forKey: "collectionBehavior") as? UInt ?? 0
                savedCollectionBehavior = behavior
                appKitWindow.setValue((behavior | (1 << 7)) & ~(1 << 8), forKey: "collectionBehavior")
            }
            updateAppKitWindow()
        }

        private func detach() {
            guard let window = attachedWindow else { return }

            Self.setCursorHiddenUntilMovement(false)
            KurtzMiniPlayer.shared.exit(animated: false)
            windowObservers.forEach(NotificationCenter.default.removeObserver)
            windowObservers.removeAll()
            watermark.removeFromSuperview()
            restoreFullScreenButton()
            dragOrigin = nil

            if let appKitWindow {
                restoreResizeConstraint(on: appKitWindow)
                if let savedWindowFrame, !KurtzMiniPlayer.isFullScreen(appKitWindow) {
                    KurtzMiniPlayer.setFrame(savedWindowFrame, on: appKitWindow)
                }
                restoreWindowTitle(on: appKitWindow)
                restoreWindowButtons(on: appKitWindow)
                if let savedCollectionBehavior {
                    appKitWindow.setValue(savedCollectionBehavior, forKey: "collectionBehavior")
                }
            }

            if let savedTitleVisibility {
                window.windowScene?.titlebar?.titleVisibility = savedTitleVisibility
            }
            if let savedTabBarHidden, let tabBarController = Self.tabBarController(in: window) {
                tabBarController.isTabBarHidden = savedTabBarHidden
            }
            if let contextMenu {
                menuHost?.removeInteraction(contextMenu)
            }
            if let dragGesture {
                menuHost?.removeGestureRecognizer(dragGesture)
            }

            savedTitleVisibility = nil
            savedTabBarHidden = nil
            contextMenu = nil
            dragGesture = nil
            menuHost = nil
            attachedWindow = nil
            appKitWindow = nil
            savedWindowFrame = nil
            savedWindowTitle = nil
            savedAppKitTitleVisibility = nil
            savedContentAspectRatio = nil
            savedContentResizeIncrements = nil
            savedCollectionBehavior = nil
            savedWindowButtonHidden.removeAll()
            lockedAspectRatio = nil
        }

        private func updateAppKitWindow() {
            guard let appKitWindow else { return }
            updateWindowTitle(on: appKitWindow)
            updateWindowButtons(on: appKitWindow)
            lockWindowAspectRatio(on: appKitWindow)
            if !controlsVisible, appKitWindow.value(forKey: "keyWindow") as? Bool == true,
               let mouse = (NSClassFromString("NSEvent") as? NSObject.Type)?.value(forKey: "mouseLocation") as? NSValue,
               let frame = KurtzMiniPlayer.frame(of: appKitWindow), frame.contains(mouse.cgPointValue)
            {
                Self.setCursorHiddenUntilMovement(true)
            } else if controlsVisible {
                Self.setCursorHiddenUntilMovement(false)
            }
        }

        private static func setCursorHiddenUntilMovement(_ hidden: Bool) {
            guard let cursor = NSClassFromString("NSCursor"),
                  let method = class_getClassMethod(cursor, NSSelectorFromString("setHiddenUntilMouseMoves:")) else { return }
            typealias SetHidden = @convention(c) (AnyClass, Selector, Bool) -> Void
            unsafeBitCast(method_getImplementation(method), to: SetHidden.self)(
                cursor,
                NSSelectorFromString("setHiddenUntilMouseMoves:"),
                hidden
            )
        }

        private func lockWindowAspectRatio(on appKitWindow: NSObject) {
            guard !KurtzMiniPlayer.shared.isActive,
                  !isChangingFullScreen,
                  !KurtzMiniPlayer.isFullScreen(appKitWindow),
                  videoSize.width > 0,
                  videoSize.height > 0
            else { return }

            let aspectRatio = videoSize.width / videoSize.height
            guard aspectRatio.isFinite, aspectRatio > 0.1, aspectRatio < 10,
                  lockedAspectRatio.map({ abs($0 - aspectRatio) > 0.001 }) ?? true,
                  let frame = KurtzMiniPlayer.frame(of: appKitWindow),
                  let contentFrame = KurtzMiniPlayer.rectValue("contentLayoutRect", on: appKitWindow),
                  let visibleFrame = KurtzMiniPlayer.rectValue("screen.visibleFrame", on: appKitWindow)
            else { return }

            let horizontalChrome = max(0, frame.width - contentFrame.width)
            let verticalChrome = max(0, frame.height - contentFrame.height)
            let maximumContentSize = CGSize(
                width: max(320, visibleFrame.width - horizontalChrome),
                height: max(180, visibleFrame.height - verticalChrome)
            )
            var contentWidth = min(max(contentFrame.width, 320), maximumContentSize.width)
            var contentHeight = contentWidth / aspectRatio
            if contentHeight > maximumContentSize.height {
                contentHeight = maximumContentSize.height
                contentWidth = contentHeight * aspectRatio
            }

            let targetSize = CGSize(
                width: contentWidth + horizontalChrome,
                height: contentHeight + verticalChrome
            )
            let proposedFrame = CGRect(
                x: frame.midX - targetSize.width / 2,
                y: frame.maxY - targetSize.height,
                width: targetSize.width,
                height: targetSize.height
            )
            let targetFrame = Self.clamped(proposedFrame, to: visibleFrame)

            KurtzMiniPlayer.setContentSize(videoSize, selector: "setContentAspectRatio:", on: appKitWindow)
            KurtzMiniPlayer.setFrame(targetFrame, on: appKitWindow)
            lockedAspectRatio = aspectRatio
        }

        private static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
            CGRect(
                x: min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - frame.width),
                y: min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - frame.height),
                width: frame.width,
                height: frame.height
            )
        }

        private static func descendantPanGestures(in view: UIView) -> [UIPanGestureRecognizer] {
            let own = (view.gestureRecognizers ?? []).compactMap { $0 as? UIPanGestureRecognizer }
            return own + view.subviews.flatMap(descendantPanGestures(in:))
        }

        private func restoreResizeConstraint(on appKitWindow: NSObject) {
            if let savedContentAspectRatio,
               savedContentAspectRatio.width > 0,
               savedContentAspectRatio.height > 0
            {
                KurtzMiniPlayer.setContentSize(
                    savedContentAspectRatio,
                    selector: "setContentAspectRatio:",
                    on: appKitWindow
                )
            } else {
                KurtzMiniPlayer.setContentSize(
                    savedContentResizeIncrements ?? CGSize(width: 1, height: 1),
                    selector: "setContentResizeIncrements:",
                    on: appKitWindow
                )
            }
        }

        private func updateWindowButtons(on appKitWindow: NSObject) {
            connectFullScreenButton(on: appKitWindow)
            for buttonType in KurtzMiniPlayer.standardWindowButtonTypes {
                KurtzMiniPlayer.standardWindowButton(buttonType, on: appKitWindow)?
                    .setValue(!controlsVisible, forKey: "hidden")
            }
        }

        private func restoreWindowButtons(on appKitWindow: NSObject) {
            for (buttonType, wasHidden) in savedWindowButtonHidden {
                KurtzMiniPlayer.standardWindowButton(buttonType, on: appKitWindow)?
                    .setValue(wasHidden, forKey: "hidden")
            }
        }

        private func connectFullScreenButton(on window: NSObject) {
            guard let button = KurtzMiniPlayer.standardWindowButton(2, on: window), button !== fullScreenButton else { return }
            restoreFullScreenButton()
            fullScreenButton = button
            savedFullScreenTarget = button.value(forKey: "target") as AnyObject?
            typealias GetAction = @convention(c) (NSObject, Selector) -> Selector?
            let action = NSSelectorFromString("action")
            savedFullScreenAction = unsafeBitCast(button.method(for: action), to: GetAction.self)(button, action)
            button.perform(NSSelectorFromString("setTarget:"), with: self)
            setButtonAction(#selector(togglePlayerFullScreen(_:)), on: button)
        }

        private func restoreFullScreenButton() {
            if let button = fullScreenButton {
                button.perform(NSSelectorFromString("setTarget:"), with: savedFullScreenTarget)
                setButtonAction(savedFullScreenAction, on: button)
            }
            fullScreenButton = nil
            savedFullScreenTarget = nil
            savedFullScreenAction = nil
        }

        private func setButtonAction(_ action: Selector?, on button: NSObject) {
            typealias SetAction = @convention(c) (NSObject, Selector, Selector?) -> Void
            let setter = NSSelectorFromString("setAction:")
            unsafeBitCast(button.method(for: setter), to: SetAction.self)(button, setter, action)
        }

        @objc
        private func togglePlayerFullScreen(_ sender: Any?) {
            guard !isChangingFullScreen else { return }
            KurtzMiniPlayer.toggleFullScreen()
        }

        private func updateWindowTitle(on appKitWindow: NSObject) {
            // Account/source transitions can install the tab controller after attach.
            // Reapply the player chrome policy once it exists, retaining its original
            // state only once so browsing is restored when playback closes.
            if let window = attachedWindow, let tabs = Self.tabBarController(in: window) {
                if savedTabBarHidden == nil {
                    savedTabBarHidden = tabs.isTabBarHidden
                }
                if !tabs.isTabBarHidden {
                    tabs.isTabBarHidden = true
                }
            }
            attachedWindow?.bringSubviewToFront(watermark)
            watermark.isHidden = !showPlayerWindowTitle || controlsVisible || isChangingFullScreen || KurtzMiniPlayer
                .isFullScreen(appKitWindow)
            attachedWindow?.windowScene?.titlebar?.titleVisibility = .hidden
            appKitWindow.setValue("", forKey: "title")
            appKitWindow.setValue(NSNumber(value: 1), forKey: "titleVisibility")
        }

        private func restoreWindowTitle(on appKitWindow: NSObject) {
            if let savedWindowTitle {
                appKitWindow.setValue(savedWindowTitle, forKey: "title")
            }
            if let savedAppKitTitleVisibility {
                appKitWindow.setValue(NSNumber(value: savedAppKitTitleVisibility), forKey: "titleVisibility")
            }
        }

        // MARK: Window dragging

        @objc
        private func dragWindow(_ gesture: UIPanGestureRecognizer) {
            guard let appKitWindow,
                  !KurtzMiniPlayer.isFullScreen(appKitWindow)
            else { return }

            switch gesture.state {
            case .began:
                if let mouse = KurtzMiniPlayer.mouseLocation, let frame = KurtzMiniPlayer.frame(of: appKitWindow) {
                    dragOrigin = (mouse, frame)
                }
            case .changed:
                guard let start = dragOrigin, let mouse = KurtzMiniPlayer.mouseLocation else { return }
                // Both positions are in AppKit screen coordinates, independent of the moving view.
                let movedFrame = start.frame.offsetBy(dx: mouse.x - start.mouse.x, dy: mouse.y - start.mouse.y)
                KurtzMiniPlayer.setFrame(movedFrame, on: appKitWindow, animate: false)
            case .ended, .cancelled, .failed:
                dragOrigin = nil
            default:
                break
            }
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === dragGesture, let appKitWindow else { return true }
            return !KurtzMiniPlayer.isFullScreen(appKitWindow)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let candidate = view {
                if candidate.accessibilityIdentifier == "KurtzTimeline" || candidate is UIControl {
                    return false
                }
                view = candidate.superview
            }
            return true
        }

        private static func tabBarController(in window: UIWindow) -> UITabBarController? {
            var queue: [UIViewController] = window.rootViewController.map { [$0] } ?? []
            while !queue.isEmpty {
                let controller = queue.removeFirst()
                if let tabBarController = controller as? UITabBarController {
                    return tabBarController
                }
                queue.append(contentsOf: controller.children)
            }
            return nil
        }

        // MARK: Context menu

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                self?.menu()
            }
        }

        private func menu() -> UIMenu {
            var actions: [UIMenuElement] = []

            if let manager {
                let isPlaying = manager.playbackRequestStatus == .playing
                actions.append(
                    UIAction(
                        title: isPlaying ? L10n.pause : L10n.play,
                        image: UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
                    ) { [weak manager] _ in
                        manager?.togglePlayPause()
                    }
                )
            }

            if let window = attachedWindow {
                let miniPlayer = KurtzMiniPlayer.shared
                actions.append(
                    UIAction(
                        title: miniPlayer.isActive ? KurtzStrings.pictureInPictureStop : KurtzStrings.pictureInPicture,
                        image: UIImage(systemName: miniPlayer.isActive ? "pip.exit" : "pip.enter")
                    ) { [weak window] _ in
                        guard let window else { return }
                        miniPlayer.toggle(window: window)
                    }
                )
            }

            return UIMenu(children: actions)
        }
    }
}

/// "Bild in Bild" for the Mac: the window shrinks to a small 16:9 player in the bottom
/// right corner that floats above other windows and follows to every Space; leaving
/// restores size, position and level.
///
/// The system's Picture in Picture cannot show VLC's video in a Mac Catalyst app
/// (AVKit never reports it possible for libVLC's sample buffer output, and starting it
/// anyway does nothing), so the window itself becomes the mini player. Mac Catalyst has
/// no API for window level or frame; the AppKit window is driven through its public
/// methods at runtime.
@MainActor
final class KurtzMiniPlayer {

    static var mouseLocation: CGPoint? {
        (NSClassFromString("NSEvent") as? NSObject.Type)?.value(forKey: "mouseLocation")
            .flatMap { ($0 as? NSValue)?.cgPointValue }
    }

    static func toggleFullScreen() {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow),
            let native = appKitWindow(for: window) else { return }
        if shared.isActive {
            shared.exit(animated: false)
        }
        native.perform(NSSelectorFromString("toggleFullScreen:"), with: nil)
    }

    static func leaveFullScreen() {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow),
            let native = appKitWindow(for: window), isFullScreen(native) else { return }
        native.perform(NSSelectorFromString("toggleFullScreen:"), with: nil)
    }

    static let shared = KurtzMiniPlayer()

    private static let width: CGFloat = 480
    private static let margin: CGFloat = 24
    private static let floatingLevel = 3 // NSFloatingWindowLevel
    private static let fullScreenStyle: UInt = 1 << 14 // NSWindowStyleMaskFullScreen
    private static let joinsAllSpaces: UInt = 1 << 0 // NSWindowCollectionBehaviorCanJoinAllSpaces
    private static let fullScreenAuxiliary: UInt = 1 << 8 // NSWindowCollectionBehaviorFullScreenAuxiliary

    private(set) var isActive = false
    private var isLeavingFullScreen = false

    #if DEBUG
    /// Steps taken, for `KurtzDebugSnapshot`.
    var debugLog: [String] = []
    #endif

    private var appKitWindow: NSObject?
    private var wasFullScreen = false
    private weak var window: UIWindow?
    private var savedFrame: CGRect = .zero
    private var savedLevel = 0
    private var savedCollectionBehavior: UInt = 0
    private var savedMinimumSize: CGSize?
    private var savedContentAspectRatio: CGSize?
    private var savedContentResizeIncrements: CGSize?

    private init() {
        // Quitting in the mini player would otherwise bring the window back that small.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                KurtzMiniPlayer.shared.exit(animated: false)
            }
        }
    }

    func toggle(window: UIWindow) {
        if isActive {
            exit()
        } else {
            enter(window: window)
        }
    }

    func enter(window: UIWindow) {
        guard !isActive, !isLeavingFullScreen, let appKitWindow = Self.appKitWindow(for: window) else {
            log("enter refused: active=\(isActive) leaving=\(isLeavingFullScreen)")
            return
        }

        // Leave full screen first; the window can only shrink once that animation is over.
        if Self.isFullScreen(appKitWindow) {
            log("leaving full screen")
            isLeavingFullScreen = true
            appKitWindow.perform(NSSelectorFromString("toggleFullScreen:"), with: nil)
            waitForWindowedMode(appKitWindow, window: window, remainingChecks: 12)
            return
        }
        shrink(appKitWindow, window: window)
    }

    private func waitForWindowedMode(_ appKitWindow: NSObject, window: UIWindow, remainingChecks: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak window] in
            guard let self, let window else { return }
            if Self.isFullScreen(appKitWindow), remainingChecks > 0 {
                waitForWindowedMode(appKitWindow, window: window, remainingChecks: remainingChecks - 1)
                return
            }
            isLeavingFullScreen = false
            log("after leaving: fullScreen=\(Self.isFullScreen(appKitWindow)) checks left=\(remainingChecks)")
            guard !Self.isFullScreen(appKitWindow) else {
                log("still in full screen, giving up")
                return
            }
            // Let AppKit settle the windowed frame before reading it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.shrink(appKitWindow, window: window, wasFullScreen: true)
            }
        }
    }

    private func shrink(_ appKitWindow: NSObject, window: UIWindow, wasFullScreen: Bool = false) {
        guard let frame = (appKitWindow.value(forKey: "frame") as? NSValue)?.cgRectValue,
              let visible = (appKitWindow.value(forKeyPath: "screen.visibleFrame") as? NSValue)?.cgRectValue
        else {
            log("no frame or screen: frame=\(String(describing: appKitWindow.value(forKey: "frame"))) "
                + "screen=\(String(describing: appKitWindow.value(forKey: "screen")))")
            return
        }

        self.appKitWindow = appKitWindow
        self.window = window
        self.wasFullScreen = wasFullScreen
        savedFrame = frame
        savedLevel = appKitWindow.value(forKey: "level") as? Int ?? 0
        savedCollectionBehavior = appKitWindow.value(forKey: "collectionBehavior") as? UInt ?? 0
        savedContentAspectRatio = Self.sizeValue("contentAspectRatio", on: appKitWindow)
        savedContentResizeIncrements = Self.sizeValue("contentResizeIncrements", on: appKitWindow)

        if let restrictions = window.windowScene?.sizeRestrictions {
            savedMinimumSize = restrictions.minimumSize
            restrictions.minimumSize = CGSize(width: 240, height: 135)
        }

        let contentHeight = (appKitWindow.value(forKey: "contentLayoutRect") as? NSValue)?.cgRectValue.height ?? frame.height
        let titlebarHeight = max(0, frame.height - contentHeight)
        let size = CGSize(width: Self.width, height: Self.width * 9 / 16 + titlebarHeight)
        // AppKit coordinates: origin at the bottom left of the screen.
        let miniFrame = CGRect(
            x: visible.maxX - size.width - Self.margin,
            y: visible.minY + Self.margin,
            width: size.width,
            height: size.height
        )

        appKitWindow.setValue(Self.floatingLevel, forKey: "level")
        appKitWindow.setValue(
            savedCollectionBehavior | Self.joinsAllSpaces | Self.fullScreenAuxiliary,
            forKey: "collectionBehavior"
        )
        Self.setContentSize(CGSize(width: 16, height: 9), selector: "setContentAspectRatio:", on: appKitWindow)
        Self.setFrame(miniFrame, on: appKitWindow)
        isActive = true
        log("mini player from \(frame) to \(miniFrame)")
    }

    func exit(animated: Bool = true) {
        guard isActive, let appKitWindow else { return }
        isActive = false

        appKitWindow.setValue(savedLevel, forKey: "level")
        appKitWindow.setValue(savedCollectionBehavior, forKey: "collectionBehavior")
        // AppKit keeps only one of aspect ratio and resize increments. Restore the exact
        // constraint that was active before entering the mini player.
        if let savedContentAspectRatio,
           savedContentAspectRatio.width > 0,
           savedContentAspectRatio.height > 0
        {
            Self.setContentSize(savedContentAspectRatio, selector: "setContentAspectRatio:", on: appKitWindow)
        } else {
            Self.setContentSize(
                savedContentResizeIncrements ?? CGSize(width: 1, height: 1),
                selector: "setContentResizeIncrements:",
                on: appKitWindow
            )
        }
        if let savedMinimumSize, let restrictions = window?.windowScene?.sizeRestrictions {
            restrictions.minimumSize = savedMinimumSize
        }
        // Without animation when full screen follows: AppKit takes the frame it finds as the
        // one to return to, and a frame still animating would leave a screen-sized window.
        Self.setFrame(savedFrame, on: appKitWindow, animate: animated && !wasFullScreen)
        appKitWindow.perform(NSSelectorFromString("makeKeyAndOrderFront:"), with: nil)
        if wasFullScreen, animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appKitWindow.perform(NSSelectorFromString("toggleFullScreen:"), with: nil)
            }
        }
        log("restored \(savedFrame), full screen again: \(wasFullScreen)")

        self.appKitWindow = nil
        window = nil
        savedMinimumSize = nil
        savedContentAspectRatio = nil
        savedContentResizeIncrements = nil
    }

    #if DEBUG
    /// AppKit state of the app's windows, for `KurtzDebugSnapshot`.
    static var debugWindows: String {
        guard let application = (NSClassFromString("NSApplication") as? NSObject.Type)?
            .value(forKey: "sharedApplication") as? NSObject,
            let windows = application.value(forKey: "windows") as? [NSObject]
        else { return "no NSApplication" }
        return windows.map { window in
            let frame = (window.value(forKey: "frame") as? NSValue)?.cgRectValue ?? .zero
            let contentAspectRatio = sizeValue("contentAspectRatio", on: window) ?? .zero
            let buttonsHidden = standardWindowButtonTypes.map {
                standardWindowButton($0, on: window)?.value(forKey: "hidden") as? Bool
            }
            return "\(type(of: window)) frame=\(frame) fullScreen=\(isFullScreen(window)) "
                + "level=\(window.value(forKey: "level") ?? "?") key=\(window.value(forKey: "keyWindow") ?? "?") "
                + "main=\(window.value(forKey: "mainWindow") ?? "?") visible=\(window.value(forKey: "visible") ?? "?") "
                + "contentAspect=\(contentAspectRatio) buttonsHidden=\(buttonsHidden)"
        }.joined(separator: "; ")
    }
    #endif

    private func log(_ message: String) {
        #if DEBUG
        debugLog.append(message)
        #endif
    }

    // MARK: AppKit

    fileprivate static let standardWindowButtonTypes: [UInt] = [0, 1, 2]

    fileprivate static func isFullScreen(_ appKitWindow: NSObject) -> Bool {
        guard let styleMask = appKitWindow.value(forKey: "styleMask") as? UInt else { return false }
        return styleMask & fullScreenStyle != 0
    }

    /// The `NSWindow` that hosts a Mac Catalyst window.
    fileprivate static func appKitWindow(for window: UIWindow) -> NSObject? {
        guard let application = (NSClassFromString("NSApplication") as? NSObject.Type)?
            .value(forKey: "sharedApplication") as? NSObject,
            let windows = application.value(forKey: "windows") as? [NSObject]
        else { return nil }

        let uiWindowsSelector = NSSelectorFromString("uiWindows")
        if let match = windows.first(where: {
            $0.responds(to: uiWindowsSelector) && (($0.value(forKey: "uiWindows") as? [UIWindow])?.contains(window) ?? false)
        }) {
            return match
        }

        // Fallback: the player window is the one the right click went to.
        return application.value(forKey: "keyWindow") as? NSObject
    }

    fileprivate static func frame(of appKitWindow: NSObject) -> CGRect? {
        rectValue("frame", on: appKitWindow)
    }

    fileprivate static func rectValue(_ keyPath: String, on appKitWindow: NSObject) -> CGRect? {
        (appKitWindow.value(forKeyPath: keyPath) as? NSValue)?.cgRectValue
    }

    fileprivate static func sizeValue(_ keyPath: String, on appKitWindow: NSObject) -> CGSize? {
        (appKitWindow.value(forKeyPath: keyPath) as? NSValue)?.cgSizeValue
    }

    fileprivate static func standardWindowButton(_ buttonType: UInt, on appKitWindow: NSObject) -> NSObject? {
        typealias StandardWindowButton = @convention(c) (NSObject, Selector, UInt) -> NSObject?
        let selector = NSSelectorFromString("standardWindowButton:")
        guard appKitWindow.responds(to: selector) else { return nil }
        return unsafeBitCast(appKitWindow.method(for: selector), to: StandardWindowButton.self)(
            appKitWindow,
            selector,
            buttonType
        )
    }

    fileprivate static func setFrame(_ frame: CGRect, on appKitWindow: NSObject, animate: Bool = true) {
        typealias SetFrame = @convention(c) (NSObject, Selector, CGRect, Bool, Bool) -> Void
        let selector = NSSelectorFromString("setFrame:display:animate:")
        guard appKitWindow.responds(to: selector) else { return }
        unsafeBitCast(appKitWindow.method(for: selector), to: SetFrame.self)(appKitWindow, selector, frame, true, animate)
    }

    fileprivate static func setContentSize(_ size: CGSize, selector name: String, on appKitWindow: NSObject) {
        typealias SetSize = @convention(c) (NSObject, Selector, CGSize) -> Void
        let selector = NSSelectorFromString(name)
        guard appKitWindow.responds(to: selector) else { return }
        unsafeBitCast(appKitWindow.method(for: selector), to: SetSize.self)(appKitWindow, selector, size)
    }
}

#else

/// Only the Mac needs window handling.
struct KurtzMacPlayerSupport: View {

    var body: some View {
        EmptyView()
    }
}

#endif
