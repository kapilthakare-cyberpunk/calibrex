// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Calibrex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Calibrex", targets: ["Calibrex"]),
        .library(name: "CalibrexCore", targets: ["CalibrexCore"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Calibrex",
            dependencies: ["CalibrexCore"],
            path: "Sources/Calibrex",
            exclude: ["Adaptation", "Calibration", "Core", "MenuBar", "Platform", "Profiles", "Sensors", "Utils"]
        ),
        .target(
            name: "CalibrexCore",
            dependencies: [],
            path: "Sources/Calibrex",
            exclude: ["main.swift"]
        ),
        .testTarget(
            name: "CalibrexTests",
            dependencies: ["CalibrexCore"],
            path: "Tests/CalibrexTests"
        )
    ]
)
