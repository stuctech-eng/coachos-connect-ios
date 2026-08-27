import Foundation

/// Gedeelde foutdomeinen door de hele app heen. Concrete adapters en
/// repositories mappen hun eigen fouten naar dit type, zodat de UI-laag
/// nooit fabrikant- of transportspecifieke errors hoeft te kennen.
public enum CoachOSConnectError: Error, Equatable, Sendable {
    case notAuthenticated
    case sessionExpired
    case deviceNotConnected
    case deviceNotFound(id: String)
    case capabilityNotSupported(DeviceCapability)
    case workoutNotFound(id: String)
    case networkUnavailable
    case syncFailed(reason: String)
    case unknown(reason: String)
}

extension CoachOSConnectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Niet ingelogd bij CoachOS."
        case .sessionExpired:
            return "Sessie verlopen, opnieuw inloggen vereist."
        case .deviceNotConnected:
            return "Geen apparaat verbonden."
        case .deviceNotFound(let id):
            return "Apparaat niet gevonden: \(id)."
        case .capabilityNotSupported(let capability):
            return "Apparaat ondersteunt \(capability.rawValue) niet."
        case .workoutNotFound(let id):
            return "Workout niet gevonden: \(id)."
        case .networkUnavailable:
            return "Geen netwerkverbinding."
        case .syncFailed(let reason):
            return "Synchronisatie mislukt: \(reason)."
        case .unknown(let reason):
            return "Onbekende fout: \(reason)."
        }
    }
}
