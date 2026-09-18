// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenDockWidgets",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "OpenDockWidgets", targets: ["OpenDockWidgets"]),
    ],
    dependencies: [
        .package(path: "../OpenDockKit"),
    ],
    targets: [
        .target(
            name: "OpenDockWidgets",
            dependencies: ["OpenDockKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
