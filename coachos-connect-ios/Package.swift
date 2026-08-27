// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoachOSConnect",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Domain: modellen, protocols, use cases. Geen dependencies.
        .library(name: "CoachOSConnectCore", targets: ["CoachOSConnectCore"]),

        // Device Layer: universele adapter-architectuur. Geen hardware-implementaties.
        .library(name: "CoachOSConnectDeviceLayer", targets: ["CoachOSConnectDeviceLayer"]),

        // Data: repository-implementaties, API client, lokale opslag.
        .library(name: "CoachOSConnectData", targets: ["CoachOSConnectData"]),

        // DI: dependency injection container en assembly.
        .library(name: "CoachOSConnectDI", targets: ["CoachOSConnectDI"])
    ],
    dependencies: [
        // Bewust leeg. Geen externe dependencies in Sprint 1.
    ],
    targets: [
        .target(
            name: "CoachOSConnectCore",
            dependencies: []
        ),
        .target(
            name: "CoachOSConnectDeviceLayer",
            dependencies: ["CoachOSConnectCore"]
        ),
        .target(
            name: "CoachOSConnectData",
            dependencies: ["CoachOSConnectCore", "CoachOSConnectDeviceLayer"]
        ),
        .target(
            name: "CoachOSConnectDI",
            dependencies: [
                "CoachOSConnectCore",
                "CoachOSConnectDeviceLayer",
                "CoachOSConnectData"
            ]
        ),
        .testTarget(
            name: "CoachOSConnectCoreTests",
            dependencies: ["CoachOSConnectCore"]
        )
    ]
)
