// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenDockKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "OpenDockKit", targets: ["OpenDockKit"]),
    ],
    targets: [
        .target(
            name: "OpenDockKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "OpenDockKitTests",
            dependencies: ["OpenDockKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
