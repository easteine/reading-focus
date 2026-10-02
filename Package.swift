// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadingFocus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ReadingFocus",
            path: "Sources/ReadingFocus",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
