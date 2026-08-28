import Foundation
import CoachOSConnectCore

/// Vertaalt een `UniversalWorkout` naar een geordende reeks
/// `PM5ProprietaryCommand`-blokken, klaar om na elkaar als CSAFE-frame(s)
/// verstuurd te worden.
///
/// Ondersteunt twee bevestigde structuren:
/// 1. **Intervaltraining** — afwisselende werk/hersteld-paren, bijv.
///    5×(4:00 werk, 2:00 rust). Elk paar wordt één PM5-interval-index
///    (0-based), met `SET_WORKOUTINTERVALCOUNT`/`SET_INTERVALTYPE`.
/// 2. **Continue training** (correctie, vastgesteld na Sprint 6b-3) —
///    precies één werkstap, geen herhaling/rust, bijv. "20 minuten
///    rustig roeien". Bevestigd via de gedeprecieerde maar als
///    validatiemateriaal behouden CoachOS-TypeScript-adapter
///    (`rowing-pm5-csafe-adapter.ts`, zie de architectuurbeslissing in de
///    changelog): een continue workout gebruikt GEEN
///    `SET_WORKOUTINTERVALCOUNT`/`SET_INTERVALTYPE` — bevestigd afwezig
///    in de daar aangehaalde werkende "Configure 20:00/4:00
///    splits"-voorbeelden. In plaats daarvan alleen `SET_WORKOUTTYPE`
///    (`fixedTimeNoSplits`/`fixedDistNoSplits`, afhankelijk van
///    tijd/afstand) + `SET_WORKOUTDURATION` + optionele targets +
///    `CONFIGURE_WORKOUT(true)`. Twee onafhankelijke implementaties
///    (deze en de TypeScript-versie) die tot dezelfde structuur komen is
///    sterke kruisvalidatie.
///
/// **Sprint 6b-2-correctie:** leidende `.warmup`- en afsluitende
/// `.cooldown`-stappen worden overgeslagen (niet als PM5-interval
/// geprogrammeerd), in plaats van de hele workout te weigeren zoals in
/// Sprint 5a. De stappen zelf blijven wél onderdeel van
/// `UniversalWorkout.blocks` (voor UI-weergave); ze worden alleen niet
/// als CSAFE-commando's verstuurd.
///
/// Expliciet NIET ondersteund in deze versie — elk van deze gevallen
/// resulteert in `PM5Error.unsupportedWorkoutConfiguration`, nooit in een
/// gegokte byte-encodering:
/// - Warm-up/cooldown ergens ANDERS dan aan het begin/eind.
/// - Een werkstap zonder aansluitende hersteldstap binnen een
///   intervaltraining (2+ overgebleven stappen) — bij precies 1
///   overgebleven stap geldt regel 2 hierboven, dat is geen fout meer.
/// - Afstandgebaseerde werkstappen BINNEN een intervalpaar
///   (`WorkoutDuration.distance`) — de bevestigde intervalketen is
///   tijdgebaseerd. Afstand wordt wél ondersteund bij een continue
///   (niet-interval) workout, zie regel 2.
/// - `.openEnded`-duur (undefined rest) — de `IntervalType`-enum-waarden
///   hiervoor zijn inmiddels officieel bevestigd (zie `PM5IntervalType`),
///   maar een gevalideerd werkend voorbeeld van de volledige
///   programmeersequentie ontbreekt nog. Zie sectie 29 van het
///   masterdocument.
/// - Targets op een andere metric dan `.power` of `.pace` — dit zijn de
///   enige twee bevestigde PM5-programmeercommando's (0x15, 0x06). Overige
///   targets (bijv. CoachOS' `.zone`-gebaseerde SPM-doelen) worden door de
///   CoachOS-mapping-laag bewust nooit als `WorkoutTarget` doorgegeven —
///   zie `CoachOSWorkoutMapper` — dus deze programmer ziet ze niet eens.
public enum PM5WorkoutProgrammer {

    /// Eén PM5-blok — bij een intervaltraining één per interval-index,
    /// bij een continue training het enige blok (`index` dan altijd 0).
    public struct IntervalBlock: Equatable {
        public let index: UInt8
        public let commands: [PM5ProprietaryCommand]
    }

    public static func program(_ workout: UniversalWorkout) throws -> [IntervalBlock] {
        let allSteps = workout.expandedSteps
        guard !allSteps.isEmpty else {
            throw PM5Error.unsupportedWorkoutConfiguration(reason: "Workout bevat geen stappen.")
        }

        // Leidende warmup overslaan.
        var startIndex = 0
        while startIndex < allSteps.count, allSteps[startIndex].kind == .warmup {
            startIndex += 1
        }
        // Afsluitende cooldown overslaan.
        var endIndex = allSteps.count
        while endIndex > startIndex, allSteps[endIndex - 1].kind == .cooldown {
            endIndex -= 1
        }

        let steps = Array(allSteps[startIndex..<endIndex])
        guard !steps.isEmpty else {
            throw PM5Error.unsupportedWorkoutConfiguration(
                reason: "Workout bevat na het overslaan van warmup/cooldown geen werkintervallen."
            )
        }

        // Continue (niet-interval) training: precies één overgebleven
        // werkstap, geen herhaling/rust. Zie de type-documentatie
        // hierboven voor de bron van deze correctie.
        if steps.count == 1 {
            guard steps[0].kind == .work || steps[0].kind == .interval else {
                throw PM5Error.unsupportedWorkoutConfiguration(
                    reason: "Stap '\(steps[0].name)' (\(steps[0].kind)) is geen werkstap."
                )
            }
            return [try makeContinuousBlock(steps[0])]
        }

        var blocks: [IntervalBlock] = []
        var index: UInt8 = 0
        var cursor = 0

        while cursor < steps.count {
            let workStep = steps[cursor]
            guard workStep.kind == .work || workStep.kind == .interval else {
                throw PM5Error.unsupportedWorkoutConfiguration(
                    reason: "Stap '\(workStep.name)' (\(workStep.kind)) op positie \(cursor) is geen werkstap; alleen afwisselende werk/hersteld-paren (met optionele leidende warmup/afsluitende cooldown) worden ondersteund."
                )
            }

            guard cursor + 1 < steps.count else {
                throw PM5Error.unsupportedWorkoutConfiguration(
                    reason: "Werkstap '\(workStep.name)' heeft geen aansluitende hersteldstap."
                )
            }
            let restStep = steps[cursor + 1]
            guard restStep.kind == .recovery || restStep.kind == .rest else {
                throw PM5Error.unsupportedWorkoutConfiguration(
                    reason: "Werkstap '\(workStep.name)' wordt niet direct gevolgd door een hersteldstap."
                )
            }

            let block = try makeIntervalBlock(index: index, work: workStep, rest: restStep)
            blocks.append(block)

            index += 1
            cursor += 2
        }

        return blocks
    }

    private static func makeIntervalBlock(index: UInt8, work: WorkoutStep, rest: WorkoutStep) throws -> IntervalBlock {
        guard case .time(let workSeconds) = work.duration else {
            throw PM5Error.unsupportedWorkoutConfiguration(
                reason: "Werkstap '\(work.name)': alleen tijdgebaseerde duur wordt op dit moment ondersteund (niet afstand of open einde)."
            )
        }
        guard case .time(let restSeconds) = rest.duration else {
            throw PM5Error.unsupportedWorkoutConfiguration(
                reason: "Hersteldstap '\(rest.name)': alleen tijdgebaseerde duur wordt op dit moment ondersteund (open einde/undefined rest nog niet)."
            )
        }

        var commands: [PM5ProprietaryCommand] = [
            .setWorkoutIntervalCount(index),
            .setIntervalType(PM5IntervalType.time),
            .setWorkoutDuration(durationType: PM5DurationType.time, value: UInt32(workSeconds * 100)),
            .setRestDuration(seconds: UInt16(restSeconds))
        ]

        for target in work.targets {
            commands.append(try makeTargetCommand(for: target, stepName: work.name))
        }

        commands.append(.configureWorkout(programmingMode: true))

        return IntervalBlock(index: index, commands: commands)
    }

    /// Continue (niet-interval) workout: `SET_WORKOUTTYPE` +
    /// `SET_WORKOUTDURATION` + optionele targets + `CONFIGURE_WORKOUT(true)`.
    /// Bewust GEEN `SET_WORKOUTINTERVALCOUNT`/`SET_INTERVALTYPE` — bevestigd
    /// afwezig voor dit workouttype, zie de type-documentatie hierboven.
    private static func makeContinuousBlock(_ work: WorkoutStep) throws -> IntervalBlock {
        var commands: [PM5ProprietaryCommand] = []

        switch work.duration {
        case .time(let seconds):
            commands.append(.setWorkoutType(PM5WorkoutType.fixedTimeNoSplits))
            commands.append(.setWorkoutDuration(durationType: PM5DurationType.time, value: UInt32(seconds * 100)))
        case .distance(let meters):
            commands.append(.setWorkoutType(PM5WorkoutType.fixedDistNoSplits))
            commands.append(.setWorkoutDuration(durationType: PM5DurationType.distance, value: UInt32(meters)))
        case .openEnded:
            throw PM5Error.unsupportedWorkoutConfiguration(
                reason: "Continue workout zonder vaste duur ('just row') wordt nog niet ondersteund."
            )
        }

        for target in work.targets {
            commands.append(try makeTargetCommand(for: target, stepName: work.name))
        }

        commands.append(.configureWorkout(programmingMode: true))

        return IntervalBlock(index: 0, commands: commands)
    }

    private static func makeTargetCommand(for target: WorkoutTarget, stepName: String) throws -> PM5ProprietaryCommand {
        switch target.metric {
        case .power:
            guard let watts = target.minValue ?? target.maxValue else {
                throw PM5Error.unsupportedWorkoutConfiguration(reason: "Vermogensdoel op '\(stepName)' heeft geen waarde.")
            }
            return .setTargetAverageWatts(UInt16(watts))

        case .pace:
            // Eenheid: seconden per 500m, zoals gedocumenteerd op
            // `WorkoutTarget` — ×100 voor de bevestigde CSAFE-eenheid.
            guard let secondsPer500m = target.minValue ?? target.maxValue else {
                throw PM5Error.unsupportedWorkoutConfiguration(reason: "Pace-doel op '\(stepName)' heeft geen waarde.")
            }
            return .setTargetPaceTime(centiseconds: UInt32(secondsPer500m * 100))

        default:
            throw PM5Error.unsupportedWorkoutConfiguration(
                reason: "Target-metric '\(target.metric)' op '\(stepName)' wordt niet ondersteund door de PM5-programmeercommando's (alleen .power en .pace zijn bevestigd)."
            )
        }
    }
}
