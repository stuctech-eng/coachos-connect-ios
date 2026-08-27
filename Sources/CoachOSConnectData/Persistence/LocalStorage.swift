import Foundation

/// Generieke lokale key-value opslag. Sprint 1 levert een bestandsgebaseerde
/// implementatie (`FileLocalStorage`) die voldoet voor de architectuur; een
/// eventuele latere migratie naar bijvoorbeeld SwiftData of Core Data raakt
/// alleen deze ene implementatie, niet de rest van de app — dat is precies
/// het doel van het protocol.
public protocol LocalStorageProtocol: Sendable {
    func save<T: Encodable>(_ value: T, forKey key: String) async throws
    func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
}

public actor FileLocalStorage: LocalStorageProtocol {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = base.appendingPathComponent("CoachOSConnect", isDirectory: true)
        }
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, forKey key: String) async throws {
        let data = try encoder.encode(value)
        let url = fileURL(for: key)
        try data.write(to: url, options: .atomic)
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    public func delete(forKey key: String) async throws {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }
}
