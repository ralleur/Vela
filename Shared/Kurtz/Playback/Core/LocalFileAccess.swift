//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz narrow filesystem access. Licensed under MPL-2.0.
#if os(macOS) || os(iOS)
import Foundation

enum LocalMediaError: LocalizedError {
    case notAFile
    case unreadable
    var errorDescription: String? {
        switch self {
        case .notAFile: NSLocalizedString("Choose a video on your device.", tableName: "kurtz", comment: "Invalid local video URL")
        case .unreadable: NSLocalizedString(
                "This file cannot be read. Choose it again using Open Video.",
                tableName: "kurtz",
                comment: "File access failed"
            )
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
