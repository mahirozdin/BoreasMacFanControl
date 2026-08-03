// swift-tools-version: 6.2
import PackageDescription

// SharedIPC — XPC sözleşmesi. Uygulama ve daemon'un ortak dili.
// Yüzey dört metotla sınırlıdır; genişletmek ADR gerektirir (değişmez M4).
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
