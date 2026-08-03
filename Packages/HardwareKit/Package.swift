// swift-tools-version: 6.2
import PackageDescription

// HardwareKit — IOKit sarmalayıcıları ve donanım protokolleri.
// Her protokolün Live + Mock uygulaması olmak zorundadır (değişmez M2).
let package = Package(
    name: "HardwareKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HardwareKit", targets: ["HardwareKit"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "HardwareKit",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HardwareKitTests",
            dependencies: ["HardwareKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
