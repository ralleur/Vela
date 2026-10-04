//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz playback abstractions. Licensed under MPL-2.0.
import Foundation

/// Metadata consumed by transport controls and engines. No server identity or API model is required.
struct PlaybackMedia: Equatable, Sendable {
    var id: String?
    var displayTitle: String
    var subtitle: String?
    var runtime: Duration?
    var startSeconds: Duration?
    var isLiveStream = false
    var fullChapterInfo: [PlaybackChapter]?
}

struct PlaybackChapter: Equatable, Sendable, Identifiable {
    var id: Int
    var title: String
    var startSeconds: Duration
}

/// Indexes are source-local identities; the item maps them to engine track identifiers.
struct PlaybackTrack: Equatable, Sendable {
    enum Kind: Sendable { case audio, subtitle, video }
    var index: Int?
    var type: Kind
    var displayTitle: String?
    var language: String?
    var isForced: Bool?
    var isExternal: Bool?
    var codec: String?
    var width: Int?
    var height: Int?
    var aspectRatio: String?
    var externalURL: URL?
    var engineID: String?
    static let none = PlaybackTrack(index: -1, type: .subtitle, displayTitle: "Off")
}
