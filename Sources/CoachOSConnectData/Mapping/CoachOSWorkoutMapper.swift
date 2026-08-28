import Foundation
import CoachOSConnectCore

public enum CoachOSMappingError: Error, Equatable, Sendable {
    case unsupportedBlockType(String)
    case unknownSport(String)
}

extension CoachOSMappingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedBlockType(let type):
            return "Bloktype '\(type)' heeft geen Connect-equivalent."
        case .unknownSport(let sport):
            return "Sport '\(sport)' wordt niet ondersteund."
        }
    }
}

/// Vertaalt CoachOS' eigen `UniversalWorkout` (uit `.../training-plan/workout`)
/// naar Connect's `UniversalWorkout` (`CoachOSConnectCore`). Dit is de
/// enige plek waar CoachOS-specifieke veldnamen/eenheden bekend zijn — de
/// rest van de app (Device Layer, PM5-laag) kent uitsluitend Connect's
/// eigen model.
///
/// Vastgelegde mapping-regels, uit de contract-review (28 augustus 2026):
///
/// **Bloktypen** — `hoofdblok→work`, `herstel→recovery`, `warmup→warmup`,
/// `cooldown→cooldown`, `interval→interval`. `techniek`/`cadans`/
/// `mobiliteit` hebben geen Connect-equivalent en worden expliciet
/// geweigerd (`CoachOSMappingError.unsupportedBlockType`), nooit stilzwijgend
/// als iets anders behandeld.
///
/// **Herhaling** — één CoachOS-blok met `repeat`+`rust_na_repeat_sec`
/// wordt één `RepeatGroup` met een gesynthetiseerd werk+rust-paar.
///
/// **Targets (Optie B, productbeslissing 28 augustus 2026)** — alleen
/// CoachOS-targettypen `'power'`/`'pace'` met een concrete `waarde` worden
/// naar een Connect-`WorkoutTarget` gemapt. Alle overige typen (met name
/// `'zone'`, het enige type dat de huidige Rowing Specialist daadwerkelijk
/// levert) worden BEWUST NIET gemapt naar `WorkoutTarget` — ze worden dus
/// nooit als CSAFE-hardwaredoel naar de PM5 gestuurd. In plaats daarvan
/// landt de bijbehorende `instruction`/`coachMessage`-tekst van het blok
/// in `WorkoutStep.instruction`, puur voor UI-weergave. Dit is een
/// mapping-laag-beslissing, geen wijziging aan `PM5WorkoutProgrammer` —
/// die ziet deze targets simpelweg nooit.
public enum CoachOSWorkoutMapper {

    public static func map(_ dto: CoachOSUniversalWorkoutDTO) throws -> UniversalWorkout {
        guard dto.sport == "rowing" else {
            throw CoachOSMappingError.unknownSport(dto.sport)
        }

        var blocks: [WorkoutBlock] = []
        blocks.append(contentsOf: try dto.warmup.map { .step(try mapSingleStep($0)) })
        blocks.append(contentsOf: try mapMainAndRecovery(main: dto.mainBlocks, recovery: dto.recoveryBlocks))
        blocks.append(contentsOf: try dto.cooldown.map { .step(try mapSingleStep($0)) })

        return UniversalWorkout(
            sourceId: dto.id,
            title: "CoachOS-workout",
            sport: .rowing,
            blocks: blocks
        )
    }

    // MARK: - Interne mapping

    /// `recoveryBlocks` is in de huidige `bouwWorkout()`-implementatie
    /// ALTIJD leeg (`recoveryBlocks: []`, hardcoded — geverifieerd in
    /// `builder.ts` tijdens deze sprint, niet aangenomen). Rust bij een
    /// intervalblok zit al verwerkt in `rust_na_repeat_sec` op hetzelfde
    /// hoofdblok. Deze functie ondersteunt index-gebaseerde pairing tussen
    /// `mainBlocks`/`recoveryBlocks` toch, toekomstbestendig voor het
    /// moment dat CoachOS die array ooit gaat vullen — vandaag heeft die
    /// tak simpelweg nooit effect, wat correct en verwacht is, geen bug.
    private static func mapMainAndRecovery(main: [CoachOSWorkoutBlockDTO], recovery: [CoachOSWorkoutBlockDTO]) throws -> [WorkoutBlock] {
        var result: [WorkoutBlock] = []
        for (index, mainBlock) in main.enumerated() {
            let workStep = try mapSingleStep(mainBlock, kindOverride: .work)
            let recoveryDTO = index < recovery.count ? recovery[index] : nil
            let recoveryStep = try recoveryDTO.map { try mapSingleStep($0, kindOverride: .recovery) }

            if let repeatCount = mainBlock.repeatCount, repeatCount > 1 {
                let restSeconds = mainBlock.restNaRepeatSec ?? recoveryStep.flatMap { step -> Int? in
                    if case .time(let seconds) = step.duration { return seconds }
                    return nil
                } ?? 0
                let syntheticRest = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: restSeconds))
                result.append(.repeatGroup(RepeatGroup(count: repeatCount, steps: [workStep, syntheticRest])))
            } else {
                result.append(.step(workStep))
                if let recoveryStep {
                    result.append(.step(recoveryStep))
                }
            }
        }
        return result
    }

    private static func mapSingleStep(_ dto: CoachOSWorkoutBlockDTO, kindOverride: WorkoutStepKind? = nil) throws -> WorkoutStep {
        let kind = try kindOverride ?? mapBlockType(dto.type)
        let duration: WorkoutDuration = dto.distanceM.map { .distance(meters: $0) } ?? .time(seconds: dto.durationSec)
        let targets = dto.targets.compactMap(mapTarget)
        let instruction = dto.coachMessage ?? dto.instruction

        return WorkoutStep(name: dto.id, kind: kind, duration: duration, targets: targets, instruction: instruction)
    }

    private static func mapBlockType(_ type: String) throws -> WorkoutStepKind {
        switch type {
        case "warmup": return .warmup
        case "hoofdblok": return .work
        case "interval": return .interval
        case "herstel": return .recovery
        case "cooldown": return .cooldown
        default:
            // 'techniek', 'cadans', 'mobiliteit' — geen Connect-equivalent.
            throw CoachOSMappingError.unsupportedBlockType(type)
        }
    }

    /// Optie B: alleen `.power`/`.pace` met een concrete waarde worden
    /// gemapt. Alles anders (met name `.zone`) geeft `nil` terug — geen
    /// gegokte omrekening, geen `WorkoutTarget` voor iets waar geen
    /// bevestigd CSAFE-commando voor bestaat.
    private static func mapTarget(_ dto: CoachOSWorkoutTargetDTO) -> WorkoutTarget? {
        guard let waarde = dto.waarde else { return nil }
        switch dto.type {
        case "power":
            return WorkoutTarget(metric: .power, minValue: waarde)
        case "pace":
            return WorkoutTarget(metric: .pace, minValue: waarde)
        default:
            return nil
        }
    }
}
