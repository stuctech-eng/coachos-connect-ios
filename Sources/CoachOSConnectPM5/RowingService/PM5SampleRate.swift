import Foundation

/// Bevestigde waarden voor characteristic `0x0034` (officiële spec,
/// Table 3). `fiveHundredMs` is de PM5-standaard als deze characteristic
/// niet expliciet gezet wordt.
public enum PM5SampleRate: UInt8, Sendable {
    case oneSecond = 0
    case fiveHundredMs = 1
    case twoHundredFiftyMs = 2
    case oneHundredMs = 3
}
