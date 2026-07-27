// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SajuKit",
    defaultLocalization: "ko",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SajuKit", targets: ["SajuKit"]),
    ],
    targets: [
        .target(
            name: "SajuKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SajuKitTests",
            dependencies: ["SajuKit"]
        ),
    ]
)
