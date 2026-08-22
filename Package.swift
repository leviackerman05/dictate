// swift-tools-version: 5.7
// Targets explicitly compile in Swift 6 mode with complete strict concurrency.
// The older manifest header keeps the package consumable by the macOS runner's
// PackageDescription runtime while the application itself requires macOS 26.
import PackageDescription

let package = Package(
    name: "Dictate",
    // PackageDescription shipped with the available Command Line Tools does
    // not expose the macOS 26 enum yet. The app bundle sets LSMinimumSystemVersion
    // to 26.0; this lower manifest floor keeps swift package test usable on the
    // matching SDK without weakening the product requirement.
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DictateCore", targets: ["DictateCore"]),
        .executable(name: "Dictate", targets: ["Dictate"])
    ],
    targets: [
        .target(
            name: "DictateCore",
            path: "Sources/DictateCore",
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete"])]
        ),
        .executableTarget(
            name: "Dictate",
            dependencies: ["DictateCore"],
            path: "Sources/Dictate",
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete"])]
        ),
        .testTarget(
            name: "DictateTests",
            dependencies: ["DictateCore"],
            path: "Tests/DictateTests",
            swiftSettings: [.unsafeFlags(["-swift-version", "6", "-strict-concurrency=complete"])]
        )
    ]
)
