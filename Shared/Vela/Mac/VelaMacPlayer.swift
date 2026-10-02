//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI

#if targetEnvironment(macCatalyst)

import UIKit

/// Mac window behaviour while the player is on screen:
/// - the window's toolbar (title and tabs) is hidden, also in full screen,
/// - a right click opens a menu with play/pause and "Bild in Bild".
struct VelaMacPlayerSupport: View {

    @EnvironmentObject
    private var manager: MediaPlayerManager

    var body: some View {
        WindowAccessor(manager: manager)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct WindowAccessor: UIViewRepresentable {

        let manager: MediaPlayerManager

        func makeUIView(context: Context) -> SupportView {
            SupportView(manager: manager)
        }

        func updateUIView(_ uiView: SupportView, context: Context) {
            uiView.manager = manager
        }
    }

    final class SupportView: UIView, UIContextMenuInteractionDelegate {

        weak var manager: MediaPlayerManager?

        private weak var attachedWindow: UIWindow?
        private weak var menuHost: UIView?
        private var contextMenu: UIContextMenuInteraction?
        private var savedTitleVisibility: UITitlebarTitleVisibility?
        private var savedTabBarHidden: Bool?

        init(manager: MediaPlayerManager) {
            self.manager = manager
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

        // MARK: Window chrome

        private func attach(to window: UIWindow) {
            guard attachedWindow !== window else { return }
            detach()
            attachedWindow = window

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
                if host.bounds.size == window.bounds.size { break }
            }
            let interaction = UIContextMenuInteraction(delegate: self)
            host.addInteraction(interaction)
            menuHost = host
            contextMenu = interaction
        }

        private func detach() {
            guard let window = attachedWindow else { return }

            VelaMiniPlayer.shared.exit()

            if let savedTitleVisibility {
                window.windowScene?.titlebar?.titleVisibility = savedTitleVisibility
            }
            if let savedTabBarHidden, let tabBarController = Self.tabBarController(in: window) {
                tabBarController.isTabBarHidden = savedTabBarHidden
            }
            if let contextMenu {
                menuHost?.removeInteraction(contextMenu)
            }

            savedTitleVisibility = nil
            savedTabBarHidden = nil
            contextMenu = nil
            menuHost = nil
            attachedWindow = nil
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
                let miniPlayer = VelaMiniPlayer.shared
                actions.append(
                    UIAction(
                        title: miniPlayer.isActive ? VelaStrings.pictureInPictureStop : VelaStrings.pictureInPicture,
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
final class VelaMiniPlayer {

    static let shared = VelaMiniPlayer()

    private static let width: CGFloat = 480
    private static let margin: CGFloat = 24
    private static let floatingLevel = 3 // NSFloatingWindowLevel
    private static let fullScreenStyle: UInt = 1 << 14 // NSWindowStyleMaskFullScreen
    private static let joinsAllSpaces: UInt = 1 << 0 // NSWindowCollectionBehaviorCanJoinAllSpaces
    private static let fullScreenAuxiliary: UInt = 1 << 8 // NSWindowCollectionBehaviorFullScreenAuxiliary

    private(set) var isActive = false
    private var isLeavingFullScreen = false

    #if DEBUG
    /// Steps taken, for `VelaDebugSnapshot`.
    var debugLog: [String] = []
    #endif

    private var appKitWindow: NSObject?
    private var wasFullScreen = false
    private weak var window: UIWindow?
    private var savedFrame: CGRect = .zero
    private var savedLevel = 0
    private var savedCollectionBehavior: UInt = 0
    private var savedMinimumSize: CGSize?

    private init() {
        // Quitting in the mini player would otherwise bring the window back that small.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                VelaMiniPlayer.shared.exit(animated: false)
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
        // Resize increments of one point replace the aspect constraint (AppKit keeps only one
        // of the two); a zero aspect ratio instead leaves full screen with a screen-sized window.
        Self.setContentSize(CGSize(width: 1, height: 1), selector: "setContentResizeIncrements:", on: appKitWindow)
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
    }

    #if DEBUG
    /// AppKit state of the app's windows, for `VelaDebugSnapshot`.
    static var debugWindows: String {
        guard let application = (NSClassFromString("NSApplication") as? NSObject.Type)?
            .value(forKey: "sharedApplication") as? NSObject,
            let windows = application.value(forKey: "windows") as? [NSObject]
        else { return "no NSApplication" }
        return windows.map { window in
            let frame = (window.value(forKey: "frame") as? NSValue)?.cgRectValue ?? .zero
            return "\(type(of: window)) frame=\(frame) fullScreen=\(isFullScreen(window)) "
                + "level=\(window.value(forKey: "level") ?? "?") key=\(window.value(forKey: "keyWindow") ?? "?") "
                + "main=\(window.value(forKey: "mainWindow") ?? "?") visible=\(window.value(forKey: "visible") ?? "?")"
        }.joined(separator: "; ")
    }
    #endif

    private func log(_ message: String) {
        #if DEBUG
        debugLog.append(message)
        #endif
    }

    // MARK: AppKit

    private static func isFullScreen(_ appKitWindow: NSObject) -> Bool {
        guard let styleMask = appKitWindow.value(forKey: "styleMask") as? UInt else { return false }
        return styleMask & fullScreenStyle != 0
    }

    /// The `NSWindow` that hosts a Mac Catalyst window.
    private static func appKitWindow(for window: UIWindow) -> NSObject? {
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

    private static func setFrame(_ frame: CGRect, on appKitWindow: NSObject, animate: Bool = true) {
        typealias SetFrame = @convention(c) (NSObject, Selector, CGRect, Bool, Bool) -> Void
        let selector = NSSelectorFromString("setFrame:display:animate:")
        guard appKitWindow.responds(to: selector) else { return }
        unsafeBitCast(appKitWindow.method(for: selector), to: SetFrame.self)(appKitWindow, selector, frame, true, animate)
    }

    private static func setContentSize(_ size: CGSize, selector name: String, on appKitWindow: NSObject) {
        typealias SetSize = @convention(c) (NSObject, Selector, CGSize) -> Void
        let selector = NSSelectorFromString(name)
        guard appKitWindow.responds(to: selector) else { return }
        unsafeBitCast(appKitWindow.method(for: selector), to: SetSize.self)(appKitWindow, selector, size)
    }
}

#else

/// Only the Mac needs window handling.
struct VelaMacPlayerSupport: View {

    var body: some View {
        EmptyView()
    }
}

#endif
