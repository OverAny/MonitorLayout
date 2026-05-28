// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MonitorLayout",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MonitorLayout",
            path: "Sources/MonitorLayout",
            resources: [.copy("../../Resources/Info.plist")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
