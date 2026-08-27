import Foundation
import CoachOSConnectCore

/// Interne registry van de `DeviceLayer`. Houdt bij welke
/// descriptor→adapter-fabriek combinaties bekend zijn en cachet
/// geïnstantieerde adapters zodat dezelfde adapter-instantie hergebruikt
/// wordt zolang het apparaat "bekend" is.
public actor DeviceAdapterRegistry {
    private var factories: [String: DeviceAdapterFactory] = [:]
    private var descriptors: [String: DeviceDescriptor] = [:]
    private var activeAdapters: [String: DeviceAdapterProtocol] = [:]

    public init() {}

    public func register(_ factory: @escaping DeviceAdapterFactory, for descriptor: DeviceDescriptor) {
        factories[descriptor.id] = factory
        descriptors[descriptor.id] = descriptor
    }

    public func adapter(for descriptorId: String) -> DeviceAdapterProtocol? {
        if let existing = activeAdapters[descriptorId] {
            return existing
        }
        guard let factory = factories[descriptorId] else { return nil }
        let created = factory()
        activeAdapters[descriptorId] = created
        return created
    }

    public func allAdapters() -> [DeviceAdapterProtocol] {
        factories.keys.compactMap { adapter(for: $0) }
    }

    public func allDescriptors() -> [DeviceDescriptor] {
        Array(descriptors.values)
    }
}
