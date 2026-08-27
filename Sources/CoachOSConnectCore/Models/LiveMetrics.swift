import Foundation

/// De metrieken die een `DeviceAdapter` tijdens uitvoering kan leveren.
///
/// Belangrijk: dit is uitsluitend een datamodel. CoachOS Connect verwerkt,
/// analyseert of interpreteert deze data niet — dat gebeurt in CoachOS zelf.
/// Connect streamt alleen door wat het apparaat rapporteert.
public enum MetricType: String, Codable, Sendable, CaseIterable {
    case heartRate
    case power
    case cadence
    case strokeRate
    case speed
    case distance
    case pace
    case calories
    case elevation
    case temperature
    case batteryLevel
    case signalStrength
}

/// Eén meetpunt op een gegeven moment. Adapters sturen deze door naar CoachOS
/// Connect; er wordt geen aggregatie, filtering of interpretatie toegepast.
public struct LiveMetricSample: Codable, Equatable, Sendable {
    public let metric: MetricType
    public let value: Double
    public let timestamp: Date

    public init(metric: MetricType, value: Double, timestamp: Date = Date()) {
        self.metric = metric
        self.value = value
        self.timestamp = timestamp
    }
}

/// Een verzameling samples zoals gerapporteerd door één adapter/apparaat
/// binnen één update-cyclus.
public struct LiveMetricsBatch: Codable, Equatable, Sendable {
    public let deviceId: String
    public let samples: [LiveMetricSample]

    public init(deviceId: String, samples: [LiveMetricSample]) {
        self.deviceId = deviceId
        self.samples = samples
    }
}
