// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TypeClipboard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TypeClipboard",
            path: "Sources/TypeClipboard"
        )
    ]
)
