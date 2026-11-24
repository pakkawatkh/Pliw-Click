// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pliw-click",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "pliw-click",
            targets: ["PliwClick"]
        ),
        .library(
            name: "PliwClickCore",
            targets: ["PliwClickCore"]
        )
    ],
    dependencies: [],
    targets: [
        .systemLibrary(
            name: "MultitouchSupport",
            path: "Sources/MultitouchSupport"
        ),
        .target(
            name: "PliwClickCore",
            dependencies: ["MultitouchSupport"],
            path: "Sources/PliwClickCore",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        ),
        .executableTarget(
            name: "PliwClick",
            dependencies: ["PliwClickCore"],
            path: "Sources/PliwClick",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        ),
        .testTarget(
            name: "PliwClickTests",
            dependencies: ["PliwClickCore"],
            path: "Tests/PliwClickTests",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        )
    ]
)
