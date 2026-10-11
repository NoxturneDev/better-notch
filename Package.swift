// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchClone",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NotchClone",
            targets: ["NotchClone"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NotchClone",
            path: "Sources/NotchClone"
        )
    ],
    swiftLanguageModes: [.v5]
)
