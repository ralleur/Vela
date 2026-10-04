// swift-tools-version: 6.0
//
// Unit tests for the kurtz additions that do not depend on the app:
// language matching, track picking and the Continue row rules.
// The sources are symlinks into Shared/Kurtz; run with `swift test`.
//

import PackageDescription

let package = Package(
    name: "KurtzLogicTests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "3.2.0"),
    ],
    targets: [
        .target(name: "PlaybackCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PlaybackCoreTests", dependencies: ["PlaybackCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(
            name: "KurtzLogic",
            dependencies: [.product(name: "JellyfinAPI", package: "jellyfin-sdk-swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KurtzLogicTests",
            dependencies: ["KurtzLogic", .product(name: "JellyfinAPI", package: "jellyfin-sdk-swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
