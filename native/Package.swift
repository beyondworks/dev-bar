// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DevDockHelper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DevDockHelper",
            path: "Sources/DevDockHelper"
        )
    ]
)
