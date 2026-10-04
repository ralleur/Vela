//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import SwiftUI

struct UserSessionRootView: View {

    @Environment(\.localUserAuthenticationAction)
    private var authenticationAction

    @InjectedObject(\.userSessionManager)
    private var userSessionManager

    var body: some View {
        ZStack {
            switch userSessionManager.state {
            case .initial:
                ProgressView()
            case .signedOut:
                #if targetEnvironment(macCatalyst)
                KurtzWelcomeView()
                #elseif os(iOS)
                NavigationStack { KurtzMobileHomeView() }
                #else
                NavigationInjectionView(coordinator: .init()) { SelectUserView() }
                #endif
            case .signedIn:
                PosterPreferencesEnvironment {
                    MainTabView()
                }
                .id(userSessionManager.currentSession?.user.id)
            }
        }
        .animation(.linear(duration: 0.1), value: userSessionManager.state)
        .task {
            #if os(iOS)
            // Let a cold-launch document event reach the file host before restoring
            // any server connection. Browse Jellyfin normally after the file closes.
            try? await Task.sleep(for: .milliseconds(200))
            while KurtzLocalFiles.shared.isOpeningOrPlaying, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }
            #endif
            await userSessionManager.start()
        }
        .onOpenURL { url in
            guard !url.isFileURL, let authenticationAction else { return }

            Task {
                await userSessionManager.handleOpenURL(
                    url,
                    authenticationAction: authenticationAction
                )
            }
        }
    }
}

private struct PosterPreferencesEnvironment<Content: View>: View {

    @Default(.Customization.Poster.configuration)
    private var posterConfiguration

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.posterConfiguration, posterConfiguration)
    }
}
