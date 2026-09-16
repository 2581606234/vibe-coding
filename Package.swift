// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VibePM",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VibePMCore", targets: ["VibePMCore"]),
        .executable(name: "VibePM", targets: ["VibePM"])
    ],
    targets: [
        .target(name: "VibePMCore"),
        .executableTarget(
            name: "VibePM",
            dependencies: ["VibePMCore"]
        ),
        .testTarget(
            name: "VibePMCoreTests",
            dependencies: ["VibePMCore"]
        )
    ]
)

