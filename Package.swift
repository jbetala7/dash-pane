// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DashPane",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DashPane", targets: ["DashPane"])
    ],
    targets: [
        .executableTarget(
            name: "DashPane",
            path: "DashPane",
            exclude: ["App/Info.plist"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-import-objc-header", "DashPane/DashPane-Bridging-Header.h"])
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "DashPaneTests",
            dependencies: ["DashPane"],
            path: "DashPaneTests"
        )
    ]
)
