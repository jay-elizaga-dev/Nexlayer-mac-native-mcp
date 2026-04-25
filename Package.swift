// swift-tools-version: 5.9
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
    ]
)
