// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Calibrex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Calibrex", targets: ["Calibrex"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Calibrex",
            dependencies: [],
            path: "Sources/Calibrex",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "CalibrexTests",
            dependencies: ["Calibrex"],
            path: "Tests/CalibrexTests"
        )
    ]
)
