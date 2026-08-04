// swift-tools-version: 6.2
import PackageDescription

// Core — pure logic. NO IOKit, SwiftUI or AppKit; Foundation only.
// The constraint is enforced by `make gate-layers` (ADR 0012, invariant M1).
// No external dependency can be added (ADR 0013, invariant T4).
let package = Package(
    name: "Core",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
