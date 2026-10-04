//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

enum AppIcon: String, CaseIterable, Displayable, Identifiable {
    case graphite
    case ivory

    var iconName: String {
        self == .graphite ? "AppIcon-kurtz" : "AppIcon-kurtz-light"
    }

    var id: String {
        rawValue
    }

    var alternateIconName: String? {
        self == .graphite ? nil : iconName
    }

    // Fixed palette names from the owner’s brand guide, identical in every locale.
    // swiftlint:disable:next hard_coded_display_string
    var displayTitle: String {
        self == .graphite ? "Graphite" : "Ivory"
    }

    static func resolve(alternateIconName: String?) -> Self {
        alternateIconName == "AppIcon-kurtz-light" ? .ivory : .graphite
    }
}
