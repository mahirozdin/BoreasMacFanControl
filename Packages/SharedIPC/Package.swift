// swift-tools-version: 6.2
import PackageDescription

// SharedIPC — the XPC contract. The shared language of app and daemon.
// The surface is limited to four methods; widening it requires an ADR
// (invariant M4).
let package = Package(
    name: "SharedIPC",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SharedIPC", targets: ["SharedIPC"])
    ],
    targets: [
        .target(
            name: "SharedIPC",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
