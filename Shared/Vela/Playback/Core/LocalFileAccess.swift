//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela narrow filesystem access. Licensed under MPL-2.0.
#if os(macOS) || targetEnvironment(macCatalyst)
import Foundation

enum LocalMediaError: LocalizedError {
    case notAFile
    case unreadable
    var errorDescription: String? {
        switch self {
        case .notAFile: "Choose a video on your Mac."
        case .unreadable: "This file cannot be read. Choose it again with File → Open."
        }
    }
}

/// Keeps a user-granted URL accessible until the last decoder has released the item.
final class LocalFileAccess {
    let url: URL
    private var scoped: Bool

    init(url: URL) throws {
        guard url.isFileURL else { throw LocalMediaError.notAFile }
        self.url = url
        scoped = url.startAccessingSecurityScopedResource()
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
            guard values.isRegularFile == true, values.isReadable != false else {
                throw LocalMediaError.unreadable
            }
            // Verify actual access without reading a large movie into memory.
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
        } catch {
            if scoped {
                url.stopAccessingSecurityScopedResource()
                scoped = false
            }
            throw LocalMediaError.unreadable
        }
    }

    deinit {
        if scoped {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

#endif
