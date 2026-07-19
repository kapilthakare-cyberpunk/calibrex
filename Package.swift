// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Calibrex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "calibrex", targets: ["Calibrex"]),
        .library(name: "CalibrexCore", targets: ["CalibrexCore"])
    ],
    dependencies: [
        // ArgyllCMS wrapper will be added
    ],
    targets: [
        .executableTarget(
            name: "Calibrex",
            dependencies: ["CalibrexCore"],
            path: "Sources/Calibrex"
        ),
        .target(
            name: "CalibrexCore",
            dependencies: [],
            path: "Sources/Calibrex/Core"
        ),
        .testTarget(
            name: "CalibrexTests",
            dependencies: ["CalibrexCore"],
            path: "Tests/CalibrexTests"
        )
    ]
)
