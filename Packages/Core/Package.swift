// swift-tools-version: 6.2
import PackageDescription

// Core — saf mantık. IOKit, SwiftUI, AppKit YOK; yalnızca Foundation.
// Bu kısıt `make gate-layers` ile zorlanır (ADR 0012, değişmez M1).
// Harici bağımlılık eklenemez (ADR 0013, değişmez T4).
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
        )
    ]
)
