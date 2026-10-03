//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import PreferencesView
import SwiftUI
import UIKit

@main
struct SwiftfinApp: App {
    #if targetEnvironment(macCatalyst)
    @UIApplicationDelegateAdaptor(VelaFileMenuDelegate.self)
    private var fileMenu
    #endif

    init() {
        Self.configure()
        #if DEBUG && targetEnvironment(macCatalyst)
        VelaDebugSnapshot.install()
        #endif

        UIScrollView.appearance().keyboardDismissMode = .onDrag

        // Sometimes the tab bar won't appear properly on push, always have material background.
        UITabBar.appearance().scrollEdgeAppearance = UITabBarAppearance(idiom: .unspecified)

        SwiftfinSpotlight().addSwiftfinToSpotlight()
    }

    @ViewBuilder
    private var initialContent: some View {
        #if DEBUG && targetEnvironment(macCatalyst)
        if ProcessInfo.processInfo.arguments.contains("-VelaLocalOnly") {
            // Exercising the player before any account/store/authentication startup.
            VelaWelcomeView()
        } else {
            authenticatedContent
        }
        #else
        authenticatedContent
        #endif
    }

    private var authenticatedContent: some View {
        WithLocalUserAuthentication {
            RootView().supportedOrientations(UIDevice.isPad ? .all : .portrait)
        }
    }

    var body: some Scene {
        WindowGroup {
            OverlayToastView {
                PreferencesView {
                    initialContent
                        #if targetEnvironment(macCatalyst)
                            .modifier(VelaSettingsHost())
                        #endif
                }
            }
            .ignoresSafeArea()
            .modifier(VelaFileHost())
        }
    }
}

extension UINavigationController {

    // Remove back button text
    override open func viewWillLayoutSubviews() {
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}
