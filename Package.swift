// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WindowSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WindowSwitcher", targets: ["WindowSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "WindowSwitcher",
            path: "WindowSwitcher",
            exclude: ["App/Info.plist"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-import-objc-header", "WindowSwitcher/WindowSwitcher-Bridging-Header.h"])
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "WindowSwitcherTests",
            dependencies: ["WindowSwitcher"],
            path: "WindowSwitcherTests"
        )
    ]
)
