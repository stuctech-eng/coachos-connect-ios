import Foundation
import CoachOSConnectCore

/// Vertaalt een `UniversalWorkout` naar een geordende reeks
/// `PM5ProprietaryCommand`-blokken, één blok per PM5-interval-index (0-based,
/// bevestigd via de projectcontext).
///
/// Ondersteunde structuur — precies de bevestigde MVP-doelketen (sectie 54
/// van het masterdocument): een tijdgebaseerde intervaltraining van
/// afwisselend werk- en hersteldstappen, bijvoorbeeld 5×(4:00 werk, 2:00
/// rust), met een doel op vermogen (`.power`) en/of pace (`.pace`).
///
/// **Sprint 6b-2-correctie:** leidende `.warmup`- en afsluitende
/// `.cooldown`-stappen worden overgeslagen (niet als PM5-interval
/// geprogrammeerd), in plaats van de hele workout te weigeren zoals in
/// Sprint 5a. Reden: elke daadwerkelijke CoachOS-workout heeft een losse
/// `warmup[]`/`cooldown[]`-array (bevestigd tijdens de contract-review,
/// 28 augustus 2026) — zonder deze correctie zou letterlijk geen enkele
/// echte workout ooit geprogrammeerd kunnen worden, alleen kunstmatige
/// testgevallen zonder warmup/cooldown. De stappen zelf blijven wél
/// onderdeel van `UniversalWorkout.blocks` (voor UI-weergave); ze worden
/// alleen niet als CSAFE-commando's verstuurd.
///
/// Expliciet NIET ondersteund in deze versie — elk van deze gevallen
/// resulteert in `PM5Error.unsupportedWorkoutConfiguration`, nooit in een
/// gegokte byte-encodering:
/// - Warm-up/cooldown ergens ANDERS dan aan het begin/eind (bijv. tussen
///   twee werk/rust-paren in) — geen bevestigde betekenis daarvoor.
/// - Een werkstap zonder aansluitende hersteldstap, of andersom.
/// - Afstandgebaseerde werkstappen (`WorkoutDuration.distance`) — de
///   bevestigde MVP-keten is tijdgebaseerd; afstand-intervallen volgen later.
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

    /// Eén PM5-interval-index met zijn volledige configuratieblok,
    /// inclusief de afsluitende `CONFIGURE_WORKOUT(true)` — klaar om (in
    /// Sprint 5b) na elkaar als CSAFE-frame(s) verstuurd te worden.
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
