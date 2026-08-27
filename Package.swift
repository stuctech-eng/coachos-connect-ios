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
        // withCheckedThrowingContinuation als "niet beschikbaar" worden
        // gezien. macOS 13 (Ventura) sluit aan bij de iOS 16-ondergrens en
        // ondersteunt alle gebruikte async/await-API's volledig. Raakt
        // alleen CI-builds voor macOS; de iOS-app zelf (App/) valt hier
        // niet onder, die is geen SwiftPM-target.
        .macOS(.v13)
    ],
    products: [
        // Domain: modellen, protocols, use cases. Geen dependencies.
        .library(name: "CoachOSConnectCore", targets: ["CoachOSConnectCore"]),

        // Generieke BLE-laag: CoreBluetooth. Kent geen fabrikanten/protocollen.
        .library(name: "CoachOSConnectBluetooth", targets: ["CoachOSConnectBluetooth"]),

        // Device discovery/UX-presentatielaag bovenop de Bluetooth-laag.
        // Kent, net als die laag, geen fabrikanten.
        .library(name: "CoachOSConnectDeviceDiscovery", targets: ["CoachOSConnectDeviceDiscovery"]),

        // PM5/CSAFE-encoding (Sprint 5a): pure byte-encoding, nog geen BLE.
        .library(name: "CoachOSConnectPM5", targets: ["CoachOSConnectPM5"]),

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
            name: "CoachOSConnectDeviceDiscovery",
            dependencies: ["CoachOSConnectBluetooth"]
        ),
        .target(
            name: "CoachOSConnectPM5",
            dependencies: ["CoachOSConnectCore"]
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
                "CoachOSConnectDeviceDiscovery",
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
        ),
        .testTarget(
            name: "CoachOSConnectDeviceDiscoveryTests",
            dependencies: ["CoachOSConnectDeviceDiscovery", "CoachOSConnectBluetooth"]
        ),
        .testTarget(
            name: "CoachOSConnectPM5Tests",
            dependencies: ["CoachOSConnectPM5", "CoachOSConnectCore"]
        )
    ]
)
