// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tiffy-click",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "tiffy-click",
            targets: ["TiffyClick"]
        ),
        .library(
            name: "TiffyClickCore",
            targets: ["TiffyClickCore"]
        )
    ],
    dependencies: [],
    targets: [
        .systemLibrary(
            name: "MultitouchSupport",
            path: "Sources/MultitouchSupport"
        ),
        .target(
            name: "TiffyClickCore",
            dependencies: ["MultitouchSupport"],
            path: "Sources/TiffyClickCore",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        ),
        .executableTarget(
            name: "TiffyClick",
            dependencies: ["TiffyClickCore"],
            path: "Sources/TiffyClick",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        ),
        .testTarget(
            name: "TiffyClickTests",
            dependencies: ["TiffyClickCore"],
            path: "Tests/TiffyClickTests",
            linkerSettings: [
                .linkedFramework("MultitouchSupport"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
            ]
        )
    ]
)
