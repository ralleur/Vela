//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CryptoKit
import Foundation

struct MediaTrackIndexMap {

    private var playerIndexesBySourceIndex: [Int: Int]

    init(_ playerIndexesBySourceIndex: [Int: Int] = [:]) {
        self.playerIndexesBySourceIndex = playerIndexesBySourceIndex
    }

    func playerIndex(for sourceIndex: Int?) -> Int? {
        guard let sourceIndex, sourceIndex != -1 else { return -1 }
        return playerIndexesBySourceIndex[sourceIndex]
    }

    mutating func setPlayerIndex(_ playerIndex: Int, for sourceIndex: Int) {
        playerIndexesBySourceIndex[sourceIndex] = playerIndex
    }

    /// Maps each sidecar to its loaded subtitle track.
    func resolvingSidecarSubtitles(
        _ sidecars: [(sourceIndex: Int, url: URL)],
        subtitleTracks: [(playerIndex: Int, id: String)]
    ) -> MediaTrackIndexMap {
        var resolvedMap = self

        for subtitle in sidecars {
            // Match libVLC's MD5(full URL)/spu/... track IDs in SwiftVLC 1.0.0.
            // https://github.com/videolan/vlc/blob/c833c4be0/src/input/input.c#L2742-L2765
            let urlHash = Insecure.MD5.hash(data: Data(subtitle.url.absoluteString.utf8))
                .map { String(format: "%02x", $0) }.joined()
            resolvedMap.playerIndexesBySourceIndex[subtitle.sourceIndex] = subtitleTracks.first {
                $0.playerIndex >= 0 && $0.id.hasPrefix("\(urlHash)/spu/")
            }?.playerIndex
        }

        return resolvedMap
    }
}
