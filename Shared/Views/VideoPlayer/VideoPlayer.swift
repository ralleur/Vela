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
import Transmission

struct VideoPlayer: View {

    @Environment(\.presentationCoordinator)
    private var presentationCoordinator

    @ObservedObject
    private var manager: MediaPlayerManager

    @LazyState
    private var proxy: any VideoMediaPlayerProxy

    @Router
    private var router

    @State
    private var isBeingDismissedByTransition = false

    // TODO: move behavior to `PlaybackProgress`?
    @State
    private var scrubbingStartTime: CFTimeInterval? = nil

    @StateObject
    private var containerState: VideoPlayerContainerState = .init()

    init(manager: MediaPlayerManager, playerType: VideoPlayerType = Defaults[.VideoPlayer.videoPlayerType]) {
        self.manager = manager
        switch playerType {
        case .mpv:
            self._proxy = .init(wrappedValue: MPVMediaPlayerProxy())
        case .native, .vlc:
            self._proxy = .init(wrappedValue: VLCMediaPlayerProxy())
        }
    }

    var body: some View {
        VideoPlayerContainerView(
            containerState: containerState,
            manager: manager
        ) {
            proxy.videoPlayerBody
                .eraseToAnyView()
        } playbackControls: {
            PlaybackControls()
        }
        .onAppear {
            manager.proxy = proxy
            manager.start()
        }
        #if targetEnvironment(macCatalyst)
        .onDisappear {
            if manager.state != .stopped {
                manager.stop()
            }
        }
        #endif
        .prefersStatusBarHidden(!containerState.isPresentingOverlay)
        .onChange(of: containerState.isAspectFilled) {
            UIView.animate(withDuration: 0.2) {
                proxy.setAspectFill(containerState.isAspectFilled)
            }
        }
        .onChange(of: containerState.isScrubbing) {
            if containerState.isScrubbing {
                scrubbingStartTime = CACurrentMediaTime()
            }

            guard let scrubbingStartTime else { return }
            let scrubbingDelta = CACurrentMediaTime() - scrubbingStartTime
            let secondsDelta = abs(manager.seconds - containerState.scrubbedSeconds.value)

            guard secondsDelta >= .seconds(1), scrubbingDelta >= 0.1 else { return }

            let scrubbedSeconds = containerState.scrubbedSeconds.value
            manager.seconds = scrubbedSeconds
            proxy.setSeconds(scrubbedSeconds)
        }
        .preference(
            key: PresentationControllerShouldDismissPreferenceKey.self,
            value: containerState.presentationControllerShouldDismiss
        )
        .onChange(of: presentationCoordinator.isPresented) {
            guard !presentationCoordinator.isPresented else { return }
            isBeingDismissedByTransition = true
            manager.stop()
        }
        .onReceive(manager.$playbackItem) { newItem in
            containerState.isAspectFilled = false

            // TODO: move to container view
            containerState.scrubbedSeconds.value = newItem?.metadata.startSeconds ?? .zero
        }
        .onReceive(manager.$state) { newState in
            if newState == .stopped, !isBeingDismissedByTransition, manager.onStop == nil {
                router.dismiss()
            }
        }

        .alert(
            L10n.error,
            isPresented: .constant(manager.error != nil)
        ) {
            if let retry = manager.retryPlayback {
                Button(VelaStrings.text("Try Compatible Playback")) { retry() }
            }
            #if targetEnvironment(macCatalyst)
            if manager.playbackItem?.discoversTracks == true {
                Button(VelaStrings.text("Choose Another Video…")) { VelaLocalFiles.shared.showPicker(subtitle: false) }
            }
            #endif
            Button(L10n.close, role: .cancel) {
                manager.stop()
                if manager.onStop == nil {
                    router.dismiss()
                }
            }
        } message: {
            Text(manager.error?.localizedDescription ?? L10n.unableToLoadThisItem)
        }
    }
}
