// kurtz additions, licensed under the Mozilla Public License 2.0.
import SwiftUI

enum KurtzBrand {
    static let yellow = Color(red: 1, green: 230 / 255, blue: 0)
    static let graphite = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
    static let ivory = Color(red: 250 / 255, green: 248 / 255, blue: 241 / 255)

    static var body: Font {
        #if os(tvOS)
        .custom("Sora-Regular", size: 29, relativeTo: .body)
        #else
        .custom("Sora-Regular", size: 17, relativeTo: .body)
        #endif
    }

    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Sora-Bold", size: size, relativeTo: style)
    }
}

extension Color {
    static let kurtzAccent = KurtzBrand.yellow
}
