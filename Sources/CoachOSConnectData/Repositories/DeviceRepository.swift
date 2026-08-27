import Foundation
import CoachOSConnectCore
import CoachOSConnectDeviceLayer

/// Houdt bij welke apparaten de gebruiker heeft gekoppeld. Dit is bewust
/// bookkeeping, geen hardwarecommunicatie — dat gebeurt via de adapters die
/// door de `DeviceLayer` worden aangesproken op basis van deze lijst.
///
/// Sprint 1 levert een lokale implementatie zonder Bluetooth-scanning; het
/// daadwerkelijk ontdekken van apparaten in de buurt hoort bij een latere
/// sprint (samen met de eerste concrete adapter).
public final class LocalDeviceRepository: DeviceRepositoryProtocol, @unchecked Sendable {
    private let storage: LocalStorageProtocol
    private let deviceLayer: DeviceLayer
    private let pairedDevicesKey = "paired_devices"

    public init(storage: LocalStorageProtocol, deviceLayer: DeviceLayer) {
        self.storage = storage
        self.deviceLayer = deviceLayer
    }

    public func knownDevices() async -> [DeviceDescriptor] {
        (try? await storage.load([DeviceDescriptor].self, forKey: pairedDevicesKey)) ?? []
    }

    public func pairDevice(_ descriptor: DeviceDescriptor) async throws {
        var devices = await knownDevices()
        guard !devices.contains(where: { $0.id == descriptor.id }) else { return }
        devices.append(descriptor)
        try await storage.save(devices, forKey: pairedDevicesKey)
    }

    public func unpairDevice(id: String) async throws {
        var devices = await knownDevices()
        devices.removeAll { $0.id == id }
        try await storage.save(devices, forKey: pairedDevicesKey)
    }
}
