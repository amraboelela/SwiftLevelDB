import PackageDescription

let package = Package(
    name: "SwiftLevelDB",
    dependencies: [
        .Package(url: "https://github.com/amraboelela/CLevelDB", majorVersion: 1, minor: 0)
    ]
)
