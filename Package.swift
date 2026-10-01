// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Away",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AwayCore",
            targets: ["AwayCore"]
        ),
        .executable(
            name: "AwayApp",
            targets: ["AwayApp"]
        )
    ],
    targets: [
        .target(
            name: "AwayCore"
        ),
        .executableTarget(
            name: "AwayApp",
            dependencies: ["AwayCore"]
        ),
        .testTarget(
            name: "AwayTests",
            dependencies: ["AwayCore"]
        )
    ]
)
