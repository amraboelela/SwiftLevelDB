// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLevelDB",
    products: [
        .library(
            name: "SwiftLevelDB",
            targets: ["SwiftLevelDB"])
    ],
    dependencies: [
        .package(
            name: "amrleveldb",
            url: "https://github.com/amraboelela/amrleveldb",
            .branch("master")),
    ],
    targets: [
        .target(name: "SwiftLevelDB", dependencies: ["CLevelDB"]),
        .target(name: "CLevelDB", dependencies: ["amrleveldb"]),
        .testTarget(name: "SwiftLevelDBTests", dependencies: ["SwiftLevelDB"]),
    ]
)
