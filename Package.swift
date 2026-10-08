// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HexyThing",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0")
    ],
    targets: [
        .target(name: "HexyCore", path: "Sources/HexyCore"),
        .executableTarget(
            name: "HexyThing",
            dependencies: ["HexyCore", "KeyboardShortcuts"],
            path: "Sources/HexyThing"
        ),
        .testTarget(
            name: "HexyCoreTests",
            dependencies: ["HexyCore"],
            path: "Tests/HexyCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
