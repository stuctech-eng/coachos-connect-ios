import Foundation
import os.log

/// Injecteerbare logging-abstractie voor de Bluetooth-laag. Losstaand van
/// een specifiek logframework, zodat de `CoreBluetoothManager` niet
/// rechtstreeks afhankelijk is van `os.log`, `print`, of een toekomstig
/// in-app debug-paneel — die keuze hoort bij de aanroepende laag
/// (`AppAssembly`), niet hier.
public protocol BluetoothLogging: Sendable {
    func log(_ level: BluetoothLogLevel, _ message: String)
}

public enum BluetoothLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// Standaardimplementatie via `os.log`, zichtbaar in Console.app en Xcode.
public struct OSBluetoothLogger: BluetoothLogging {
    private let logger: Logger

    public init(subsystem: String = "coachos.connect", category: String = "bluetooth") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func log(_ level: BluetoothLogLevel, _ message: String) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}

/// Stille implementatie voor unit tests, zodat testoutput niet vervuild
/// raakt met Bluetooth-logregels.
public struct NoOpBluetoothLogger: BluetoothLogging {
    public init() {}
    public func log(_ level: BluetoothLogLevel, _ message: String) {}
}
