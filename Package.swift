// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoachOSConnect",
    platforms: [
        .iOS(.v16),
        // Toegevoegd voor CI: SwiftPM bouwt deze package op de macOS-runner
        // (geen simulator nodig). Zonder expliciete macOS-ondergrens valt
        // SPM terug op een oude standaard-deployment-target van vóór Swift
        // Concurrency, waardoor AsyncStream/CheckedContinuation/
        // withCheckedThrowingContinuation (gebruikt in CoachOSConnectBluetooth)
        // als "niet beschikbaar" worden gezien. macOS 13 (Ventura) sluit aan
        // bij de iOS 16-ondergrens en ondersteunt alle gebruikte async/await-
        // API's volledig. Raakt alleen CI-builds voor macOS; de iOS-app zelf
        // (App/) valt hier niet onder, die is geen SwiftPM-target.
        .macOS(.v13)
    ],
    products: [
        // Domain: modellen, protocols, use cases. Geen dependencies.
        .library(name: "CoachOSConnectCore", targets: ["CoachOSConnectCore"]),

        // Generieke BLE-laag: CoreBluetooth. Kent geen fabrikanten/protocollen.
        .library(name: "CoachOSConnectBluetooth", targets: ["CoachOSConnectBluetooth"]),

        // Device Layer: universele adapter-architectuur. Geen hardware-implementaties.
        .library(name: "CoachOSConnectDeviceLayer", targets: ["CoachOSConnectDeviceLayer"]),

        // Data: repository-implementaties, API client, lokale opslag.
        .library(name: "CoachOSConnectData", targets: ["CoachOSConnectData"]),

        // DI: dependency injection container en assembly.
        .library(name: "CoachOSConnectDI", targets: ["CoachOSConnectDI"])
    ],
    dependencies: [
        // Bewust leeg. Geen externe dependencies.
    ],
    targets: [
        .target(
            name: "CoachOSConnectCore",
            dependencies: []
        ),
        .target(
            name: "CoachOSConnectBluetooth",
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
                "CoachOSConnectBluetooth",
                "CoachOSConnectDeviceLayer",
                "CoachOSConnectData"
            ]
        ),
        .testTarget(
            name: "CoachOSConnectCoreTests",
            dependencies: ["CoachOSConnectCore"]
        ),
        .testTarget(
            name: "CoachOSConnectBluetoothTests",
            dependencies: ["CoachOSConnectBluetooth"]
        )
    ]
)
