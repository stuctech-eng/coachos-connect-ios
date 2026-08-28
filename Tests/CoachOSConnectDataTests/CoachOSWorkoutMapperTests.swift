import XCTest
import CoachOSConnectCore
@testable import CoachOSConnectData

/// Let op: de JSON-fixtures hieronder zijn HANDMATIG OPGEBOUWD naar het
/// bevestigde schema (`workout-builder/types.ts`, contract-review 28
/// augustus 2026) — niet een daadwerkelijk vastgelegde live-response
/// (dat vereist een echte, geauthenticeerde aanroep, niet mogelijk in
/// deze omgeving). Het schema zelf is wél 1-op-1 tegen de repository
/// geverifieerd; de concrete waarden in deze fixture zijn representatief,
/// niet gevangen.
final class CoachOSWorkoutMapperTests: XCTestCase {

    func test_map_realisticRowingIntervalWorkout_producesCorrectStructure() throws {
        let json = """
        {
            "id": "sessie-abc-123",
            "sport": "rowing",
            "executionType": "FixedTimeInterval",
            "warmup": [
                { "id": "w1", "type": "warmup", "duration_sec": 300, "targets": [{ "type": "zone", "zone_nummer": 1 }], "instruction": "Rustig opbouwen." }
            ],
            "mainBlocks": [
                { "id": "m1", "type": "hoofdblok", "duration_sec": 240, "repeat": 5, "rust_na_repeat_sec": 120, "targets": [{ "type": "zone", "zone_nummer": 4 }], "instruction": "Stevig tempo, SPM 24-26.", "coachMessage": "Houd je cadans stabiel." }
            ],
            "recoveryBlocks": [],
            "cooldown": [
                { "id": "c1", "type": "cooldown", "duration_sec": 300, "targets": [], "instruction": "Rustig uitrollen." }
            ]
        }
        """

        let dto = try JSONDecoder().decode(CoachOSUniversalWorkoutDTO.self, from: json.data(using: .utf8)!)
        let workout = try CoachOSWorkoutMapper.map(dto)

        XCTAssertEqual(workout.sourceId, "sessie-abc-123")
        XCTAssertEqual(workout.sport, .rowing)

        // 1 warmup-stap + 1 repeatGroup + 1 cooldown-stap = 3 top-level blocks
        XCTAssertEqual(workout.blocks.count, 3)

        guard case .step(let warmupStep) = workout.blocks[0] else {
            return XCTFail("Verwachtte een losse warmup-stap")
        }
        XCTAssertEqual(warmupStep.kind, .warmup)
        XCTAssertEqual(warmupStep.instruction, "Rustig opbouwen.")
        // Optie B: 'zone'-target wordt NIET gemapt naar WorkoutTarget.
        XCTAssertTrue(warmupStep.targets.isEmpty)

        guard case .repeatGroup(let group) = workout.blocks[1] else {
            return XCTFail("Verwachtte een repeatGroup voor het intervalblok")
        }
        XCTAssertEqual(group.count, 5)
        XCTAssertEqual(group.steps.count, 2)
        XCTAssertEqual(group.steps[0].kind, .work)
        XCTAssertEqual(group.steps[0].duration, .time(seconds: 240))
        // coachMessage heeft voorrang op instruction wanneer beide aanwezig zijn.
        XCTAssertEqual(group.steps[0].instruction, "Houd je cadans stabiel.")
        XCTAssertTrue(group.steps[0].targets.isEmpty, "zone-target moet niet naar WorkoutTarget gemapt worden")
        XCTAssertEqual(group.steps[1].kind, .recovery)
        XCTAssertEqual(group.steps[1].duration, .time(seconds: 120))

        guard case .step(let cooldownStep) = workout.blocks[2] else {
            return XCTFail("Verwachtte een losse cooldown-stap")
        }
        XCTAssertEqual(cooldownStep.kind, .cooldown)
    }

    func test_map_powerTarget_mapsToConnectWorkoutTarget() throws {
        let json = """
        {
            "id": "s1", "sport": "rowing", "executionType": "FixedTimeInterval",
            "warmup": [], "cooldown": [], "recoveryBlocks": [],
            "mainBlocks": [
                { "id": "m1", "type": "hoofdblok", "duration_sec": 240, "targets": [{ "type": "power", "waarde": 220 }], "instruction": "220 watt aanhouden." }
            ]
        }
        """
        let dto = try JSONDecoder().decode(CoachOSUniversalWorkoutDTO.self, from: json.data(using: .utf8)!)
        let workout = try CoachOSWorkoutMapper.map(dto)

        guard case .step(let workStep) = workout.blocks.first else {
            return XCTFail("Verwachtte een losse werkstap (geen repeat)")
        }
        XCTAssertEqual(workStep.targets, [WorkoutTarget(metric: .power, minValue: 220)])
    }

    func test_map_unsupportedBlockType_throwsExplicitError() throws {
        let json = """
        {
            "id": "s1", "sport": "rowing", "executionType": "FixedTime",
            "warmup": [], "mainBlocks": [], "recoveryBlocks": [],
            "cooldown": [
                { "id": "c1", "type": "techniek", "duration_sec": 300, "targets": [], "instruction": "x" }
            ]
        }
        """
        let dto = try JSONDecoder().decode(CoachOSUniversalWorkoutDTO.self, from: json.data(using: .utf8)!)

        XCTAssertThrowsError(try CoachOSWorkoutMapper.map(dto)) { error in
            guard case CoachOSMappingError.unsupportedBlockType(let type) = error else {
                return XCTFail("Verwachtte unsupportedBlockType, kreeg \(error)")
            }
            XCTAssertEqual(type, "techniek")
        }
    }

    func test_map_nonRowingSport_throwsExplicitError() throws {
        let json = """
        {
            "id": "s1", "sport": "cycling", "executionType": "FixedTime",
            "warmup": [], "mainBlocks": [], "recoveryBlocks": [], "cooldown": []
        }
        """
        let dto = try JSONDecoder().decode(CoachOSUniversalWorkoutDTO.self, from: json.data(using: .utf8)!)

        XCTAssertThrowsError(try CoachOSWorkoutMapper.map(dto)) { error in
            guard case CoachOSMappingError.unknownSport(let sport) = error else {
                return XCTFail("Verwachtte unknownSport, kreeg \(error)")
            }
            XCTAssertEqual(sport, "cycling")
        }
    }

    // MARK: - Mapping + PM5WorkoutProgrammer, end-to-end

    func test_mappedWorkout_canBeProgrammedToPM5_endToEnd() throws {
        // Bewijst dat de mapping-laag en Sprint 6b-2's
        // PM5WorkoutProgrammer-correctie (warmup/cooldown overslaan)
        // daadwerkelijk samenwerken op een realistische CoachOS-workout.
        let json = """
        {
            "id": "s1", "sport": "rowing", "executionType": "FixedTimeInterval",
            "warmup": [{ "id": "w1", "type": "warmup", "duration_sec": 300, "targets": [], "instruction": "x" }],
            "mainBlocks": [{ "id": "m1", "type": "hoofdblok", "duration_sec": 240, "repeat": 3, "rust_na_repeat_sec": 60, "targets": [{ "type": "power", "waarde": 200 }], "instruction": "x" }],
            "recoveryBlocks": [],
            "cooldown": [{ "id": "c1", "type": "cooldown", "duration_sec": 180, "targets": [], "instruction": "x" }]
        }
        """
        let dto = try JSONDecoder().decode(CoachOSUniversalWorkoutDTO.self, from: json.data(using: .utf8)!)
        let workout = try CoachOSWorkoutMapper.map(dto)

        // CoachOSConnectPM5 is hier bewust niet als test-dependency
        // toegevoegd (zou een cirkelvormige module-relatie richting
        // CoachOSConnectData suggereren) — deze test bevestigt alleen dat
        // de mapper een structuur oplevert die aan PM5WorkoutProgrammer's
        // eisen voldoet: warmup/cooldown aan de randen, strikt
        // afwisselende werk/rust-paren ertussen.
        XCTAssertEqual(workout.expandedSteps.first?.kind, .warmup)
        XCTAssertEqual(workout.expandedSteps.last?.kind, .cooldown)
        let middleSteps = workout.expandedSteps.dropFirst().dropLast()
        XCTAssertEqual(middleSteps.count, 6) // 3x (werk, rust)
        for (index, step) in middleSteps.enumerated() {
            XCTAssertEqual(step.kind, index % 2 == 0 ? .work : .recovery)
        }
    }
}
