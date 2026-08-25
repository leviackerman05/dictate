// swift-tools-version: 5.9
// Targets explicitly compile in Swift 6 mode with complete strict concurrency.
// The package manifest uses the minimum PackageDescription version needed by
// FluidAudio's macOS 14 platform declaration.
import PackageDescription

let package = Package(
    name: "Dictate",
    defaultLocalization: "en",
    // FluidAudio 0.15.5 requires macOS 14; the app itself requires macOS 26.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DictateCore", targets: ["DictateCore"]),
        .executable(name: "Dictate", targets: ["Dictate"])
    ],
    dependencies: [
        // v0.15.5 is the tested ModelHub/Parakeet API used by the app.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
        // WhisperKit supplies the openai_whisper CoreML model family.
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "DictateCore",
            path: "Sources/DictateCore",
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete", "-target", "arm64-apple-macosx26.0"])]
        ),
        .executableTarget(
            name: "Dictate",
            dependencies: [
                "DictateCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/Dictate",
            exclude: ["Resources/Info.plist"],
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete", "-target", "arm64-apple-macosx26.0"])]
        ),
        .testTarget(
            name: "DictateTests",
            dependencies: ["DictateCore"],
            path: "Tests/DictateTests",
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete", "-target", "arm64-apple-macosx26.0"])]
        )
    ]
)
