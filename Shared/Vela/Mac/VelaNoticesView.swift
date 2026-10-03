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

struct VelaNoticesView: View {
    var close: (() -> Void)?
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var notices = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(VelaStrings.text("Open Source Notices")).font(.title2.bold())
                Spacer()
                Button(VelaStrings.text("Done")) {
                    if let close {
                        close()
                    } else {
                        dismiss()
                    }
                }.keyboardShortcut(.defaultAction)
            }
            Text(verbatim: "Vela · \(UIApplication.appVersion ?? "") (\(UIApplication.bundleVersion ?? ""))")
            Text(VelaStrings.text("Free. Open source. No subscription. No in-app purchases."))
            Link(VelaStrings.text("Source Code"), destination: URL(string: "https://github.com/ralleur/Vela")!)
            ScrollView {
                Text(verbatim: notices).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(24)
            #if targetEnvironment(macCatalyst)
                .frame(minWidth: 620, minHeight: 520)
            #endif
            .task {
                if let url = Bundle.main.url(forResource: "VelaThirdPartyNotices", withExtension: "txt") {
                    notices = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                }
            }
    }
}
#endif
