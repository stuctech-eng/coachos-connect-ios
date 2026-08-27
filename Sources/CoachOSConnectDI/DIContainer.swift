import Foundation

/// Lichtgewicht DI-container zonder externe dependencies. Bewust eenvoudig
/// gehouden: registreer een fabriek per type, resolve op basis van type.
/// Voor de omvang van CoachOS Connect is een third-party DI-framework niet
/// nodig (zie Package.swift: "geen externe afhankelijkheden tenzij noodzakelijk").
public final class DIContainer: @unchecked Sendable {
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let lock = NSLock()

    public init() {}

    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        factories[ObjectIdentifier(type)] = factory
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T {
        lock.lock()
        defer { lock.unlock() }
        guard let factory = factories[ObjectIdentifier(type)], let value = factory() as? T else {
            preconditionFailure("Geen registratie gevonden voor type \(String(describing: type)). Controleer AppAssembly.")
        }
        return value
    }
}
