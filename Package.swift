// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DevBar",
            path: "Sources/DevBar",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
