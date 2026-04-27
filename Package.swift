// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacNativeMCP",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacNativeMCP",
            path: "Sources/MacNativeMCP"
        ),
        .testTarget(
            name: "MacNativeMCPTests",
            dependencies: ["MacNativeMCP"],
            path: "Tests/MacNativeMCPTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
