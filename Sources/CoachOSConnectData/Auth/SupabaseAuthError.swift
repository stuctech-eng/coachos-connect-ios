import Foundation

/// Foutdomein voor de Supabase Auth-laag. Zelfde discipline als overal
/// elders in dit project: expliciete, getypeerde fouten, geen gok bij
/// een onverwacht antwoord.
public enum SupabaseAuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case notAuthenticated
}

extension SupabaseAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "E-mailadres of wachtwoord onjuist."
        case .invalidResponse:
            return "Onverwacht antwoord van de authenticatieserver."
        case .serverError(let statusCode, let message):
            return "Authenticatieserver gaf status \(statusCode)\(message.map { ": \($0)" } ?? "")."
        case .decodingFailed:
            return "Kon het antwoord van de authenticatieserver niet lezen."
        case .notAuthenticated:
            return "Niet ingelogd."
        }
    }
}
