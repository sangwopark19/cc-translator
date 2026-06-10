// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCTransCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CCTransCore", targets: ["CCTransCore"]),
    ],
    targets: [
        .target(name: "CCTransCore"),
        .testTarget(name: "CCTransCoreTests", dependencies: ["CCTransCore"]),
    ]
)
