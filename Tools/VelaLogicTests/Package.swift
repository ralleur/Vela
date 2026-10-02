// swift-tools-version: 6.0
//
// Unit tests for the Vela additions that do not depend on the app:
// language matching, track picking and the Continue row rules.
// The sources are symlinks into Shared/Vela; run with `swift test`.
//

import PackageDescription

let package = Package(
    name: "VelaLogicTests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "3.2.0"),
    ],
    targets: [
        .target(name: "PlaybackCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PlaybackCoreTests", dependencies: ["PlaybackCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(
            name: "VelaLogic",
            dependencies: [.product(name: "JellyfinAPI", package: "jellyfin-sdk-swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VelaLogicTests",
            dependencies: ["VelaLogic", .product(name: "JellyfinAPI", package: "jellyfin-sdk-swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
