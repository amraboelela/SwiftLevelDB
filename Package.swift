// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLevelDB",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SwiftLevelDB",
            targets: ["SwiftLevelDB"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/amraboelela/amrleveldb",
            branch: "master"
        )
    ],
    targets: [
        .target(name: "SwiftLevelDB", dependencies: ["CLevelDB"]),
        .target(name: "CLevelDB", dependencies: ["amrleveldb"]),
        .testTarget(name: "SwiftLevelDBTests", dependencies: ["SwiftLevelDB"]),
    ]
)
