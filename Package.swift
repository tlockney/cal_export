// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "cal_export",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "cal_export",
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
        .testTarget(
            name: "cal_exportTests",
            dependencies: ["cal_export"],
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
    ]
)
