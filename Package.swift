// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "IntentCraft",
    platforms: [
        // FoundationModels (Apple's on-device LLM) requires macOS 26 (Tahoe).
        .macOS("26.0")
    ],
    products: [
        // Shared core: source analysis + on-device code generation.
        // Consumed by BOTH the CLI and the SwiftUI desktop app.
        .library(name: "IntentCraftCore", targets: ["IntentCraftCore"]),
        // CLI front-end.
        .executable(name: "intentcraft", targets: ["IntentCraftCLI"]),
        // SwiftUI desktop front-end (packaged into .app by build.sh).
        .executable(name: "IntentCraftApp", targets: ["IntentCraftApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // MARK: Shared core logic
        .target(
            name: "IntentCraftCore"
        ),
        // MARK: CLI
        .executableTarget(
            name: "IntentCraftCLI",
            dependencies: [
                "IntentCraftCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        // MARK: SwiftUI desktop app
        .executableTarget(
            name: "IntentCraftApp",
            dependencies: ["IntentCraftCore"]
        ),
        // MARK: Tests
        .testTarget(
            name: "IntentCraftCoreTests",
            dependencies: ["IntentCraftCore"]
        ),
    ]
)
