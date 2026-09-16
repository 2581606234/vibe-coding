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
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "VibePMCore",
            dependencies: ["ZIPFoundation"]
        ),
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
