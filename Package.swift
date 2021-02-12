// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLevelDB",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftLevelDB",
            targets: ["SwiftLevelDB"])
    ],
    dependencies: [
        .package(url: "https://github.com/amraboelela/CLevelDB", .branch("xcframework")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "SwiftLevelDB", dependencies: ["CLevelDB"]),
        //.target(name: "CLevelDB", dependencies: ["leveldb"]),
        .testTarget(name: "SwiftLevelDBTests", dependencies: ["SwiftLevelDB"]),
    ]
)
#if os(Linux)
package.targets.append(.target(
                        name: "leveldb",
                        dependencies: ["leveldb_linux"],
                        exclude: ["README"]))
package.targets.append(.target(
                        name: "leveldb_linux",
                        dependencies: [],
                        exclude: ["README"]))
#else
/*package.targets.append(.target(
                        name: "leveldb",
                        dependencies: ["leveldb_macos"],
                        exclude: ["README"]))
package.targets.append(.target(name: "leveldb_macos", dependencies: []))*/
#endif
