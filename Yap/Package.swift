// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Yap",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "YapKit",
            targets: ["YapKit"]
        ),
        .executable(
            name: "Yap",
            targets: ["YapAppExecutable"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "YapKit",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
            ],
            path: "Sources/Yap",
            exclude: ["Info.plist", "Yap.entitlements", "Assets", "Resources"]
        ),
        .executableTarget(
            name: "YapAppExecutable",
            dependencies: ["YapKit"],
            path: "Sources/YapApp"
        ),
        .testTarget(
            name: "YapTests",
            dependencies: ["YapKit"],
            path: "Tests/YapTests"
        ),
    ]
)
