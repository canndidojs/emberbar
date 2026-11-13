// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EmberBar",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (parsing, PKCE, polling math). No UI, no network: fully unit-testable.
        .target(name: "EmberBarCore", path: "Sources/EmberBarCore"),
        .executableTarget(
            name: "EmberBar",
            dependencies: ["EmberBarCore"],
            path: "Sources/EmberBar"
        ),
        .testTarget(
            name: "EmberBarCoreTests",
            dependencies: ["EmberBarCore"],
            path: "Tests/EmberBarCoreTests"
        ),
    ]
)
