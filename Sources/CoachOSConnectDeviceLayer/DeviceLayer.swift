import Foundation
import CoachOSConnectCore

/// De Device Layer is het enige punt waarlangs de rest van de app apparaten
/// aanspreekt. Hij kent zelf geen fabrikanten — alleen adapters die
/// `DeviceAdapterProtocol` implementeren, geregistreerd in de
/// `DeviceAdapterRegistry`.
///
/// Sprint 1 bevat geen concrete adapters (geen PM5, geen Bluetooth). Deze
/// laag is de "lege stekkerdoos": het contract en de coördinatie staan vast,
/// de stekkers (adapters) volgen in latere sprints.
public actor DeviceLayer {
    private let registry: DeviceAdapterRegistry

    public init(registry: DeviceAdapterRegistry = DeviceAdapterRegistry()) {
        self.registry = registry
    }

    /// Registreert een adapter-fabriek voor een bepaalde `manufacturer`+`model`
    /// combinatie. Wordt aangeroepen tijdens app-opstart (zie `AppAssembly`),
    /// niet tijdens runtime-ontdekking.
    public func register(_ factory: @escaping DeviceAdapterFactory, for descriptor: DeviceDescriptor) async {
        await registry.register(factory, for: descriptor)
    }

    /// Geeft alle adapters terug die een gegeven capability ondersteunen.
    /// Dit is de manier waarop de rest van de app apparaten selecteert:
    /// nooit op naam, altijd op vaardigheid.
    public func adapters(supporting capability: DeviceCapability) async -> [DeviceAdapterProtocol] {
        await registry.allAdapters().filter { $0.capabilities().contains(capability) }
    }

    public func adapter(for descriptorId: String) async -> DeviceAdapterProtocol? {
        await registry.adapter(for: descriptorId)
    }

    public func allKnownDescriptors() async -> [DeviceDescriptor] {
        await registry.allDescriptors()
    }
}

/// Fabriekssignatuur waarmee een concrete adapter later wordt aangemaakt.
/// Adapters worden nooit direct geïnstantieerd door de rest van de app —
/// altijd via deze fabrieksfunctie, geregistreerd bij de `DeviceLayer`.
public typealias DeviceAdapterFactory = @Sendable () -> DeviceAdapterProtocol
