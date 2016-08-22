import PackageDescription

let package = Package(
    name: "SwiftLevelDB",
    dependencies: [
        .Package(url: "../CLevelDB", majorVersion: 1)
    ]
)
