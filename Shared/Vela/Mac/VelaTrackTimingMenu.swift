//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela additions, licensed under the Mozilla Public License 2.0.
#if os(iOS)
import SwiftUI

struct VelaTrackTimingMenu: View {
    @EnvironmentObject
    private var manager: MediaPlayerManager
    let subtitles: Bool
    private var offset: Duration {
        subtitles ? manager.subtitleOffset : manager.audioOffset
    }

    private func set(_ value: Duration) {
        if subtitles {
            manager.subtitleOffset = value
        } else {
            manager.audioOffset = value
        }
    }

    var body: some View {
        if manager.proxy is any MediaPlayerOffsetConfigurable {
            Menu {
                Text(String(format: "%+.2f s", offset.seconds))
                Button(VelaStrings.text("Earlier (50 ms)")) { set(offset - .milliseconds(50)) }
                Button(VelaStrings.text("Later (50 ms)")) { set(offset + .milliseconds(50)) }
                Button(VelaStrings.text("Reset Timing")) { set(.zero) }.disabled(offset == .zero)
            } label: {
                Label(VelaStrings.text("Timing"), systemImage: "clock")
            }
        }
    }
}
#endif
