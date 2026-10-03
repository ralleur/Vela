// Vela additions, licensed under the Mozilla Public License 2.0.
#if os(tvOS)
import SwiftUI

struct VelaTVNoticesView: View {
    @State
    private var notices = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(verbatim: "Vela").font(.largeTitle.bold())
                Text(VelaStrings.text("Built on Swiftfin. An independent app by Ralleur."))
                Text(verbatim: "github.com/ralleur/Vela").foregroundStyle(.secondary)
                Text(verbatim: notices).font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(60)
        }
        .focusable()
        .navigationTitle(VelaStrings.text("Open Source Notices"))
        .task {
            if let url = Bundle.main.url(forResource: "VelaThirdPartyNotices", withExtension: "txt") {
                notices = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
        }
    }
}
#endif
