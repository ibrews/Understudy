// swift-tools-version: 5.9
//
// Monitoring-only subset of AgileLensMultiplayer. Tracks the upstream package at
// /Users/Shared/Documents/xcodeproj/AVP_Apps/WhoAmI/Packages/AgileLensMultiplayer
// but relaxes deployment targets to match Understudy's iOS 17 / visionOS 1 floor.
// The full package (GroupActivities, SpatialAlignmentManager, etc.) requires iOS 18+;
// the Monitoring slice only needs Network.framework, available from iOS 12+.
//
import PackageDescription

let package = Package(
    name: "AgileLensMultiplayer",
    platforms: [
        .iOS(.v17),
        .visionOS(.v1),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AgileLensMultiplayer",
            targets: ["AgileLensMultiplayer"]
        ),
    ],
    targets: [
        .target(
            name: "AgileLensMultiplayer",
            path: "Sources/AgileLensMultiplayer"
        ),
    ]
)
