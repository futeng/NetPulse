// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "NetPulse",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetPulse", targets: ["NetPulse"])
    ],
    targets: [
        .executableTarget(
            name: "NetPulse",
            path: "Sources/NetPulse"
        ),
        .testTarget(
            name: "NetPulseTests",
            dependencies: ["NetPulse"],
            path: "Tests/NetPulseTests"
        )
    ]
)
