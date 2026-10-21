// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ZeldaMacStudio", platforms: [.macOS(.v14)], products: [
    .library(name: "StudioCore", targets: ["StudioCore"]),
    .executable(name: "ZeldaMacStudio", targets: ["StudioApp"])
], targets: [
    .target(name: "CZip", linkerSettings: [.linkedLibrary("z")]),
    .target(name: "StudioCore", dependencies: ["CZip"]),
    .executableTarget(name: "StudioApp", dependencies: ["StudioCore"]),
    .testTarget(name: "StudioCoreTests", dependencies: ["StudioCore"])
])
