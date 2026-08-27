import XCTest
@testable import CoachOSConnectPM5

final class PM5ProprietaryCommandTests: XCTestCase {

    func test_setWorkoutType_encodesSingleByte() {
        let command = PM5ProprietaryCommand.setWorkoutType(PM5WorkoutType.variableInterval)
        XCTAssertEqual(command.detailCommandID, 0x01)
        XCTAssertEqual(command.payload, [0x08])
    }

    func test_setWorkoutDuration_time_appliesConfirmedHundredMultiplier() {
        // 4:00 (240 seconden) → 240 * 100 = 24000, big-endian.
        let command = PM5ProprietaryCommand.setWorkoutDuration(durationType: PM5DurationType.time, value: 24000)
        XCTAssertEqual(command.detailCommandID, 0x03)
        XCTAssertEqual(command.payload, [PM5DurationType.time, 0x00, 0x00, 0x5D, 0xC0])
    }

    func test_setWorkoutDuration_distance_usesRawMetersNoMultiplier() {
        // Bevestigde correctie t.o.v. eerdere adapter-aanname: RAUWE meters, geen ×10.
        let command = PM5ProprietaryCommand.setWorkoutDuration(durationType: PM5DurationType.distance, value: 500)
        XCTAssertEqual(command.payload, [PM5DurationType.distance, 0x00, 0x00, 0x01, 0xF4])
    }

    func test_setRestDuration_usesRawSecondsTwoBytesBigEndian() {
        let command = PM5ProprietaryCommand.setRestDuration(seconds: 120)
        XCTAssertEqual(command.detailCommandID, 0x04)
        XCTAssertEqual(command.payload, [0x00, 0x78])
    }

    func test_setTargetPaceTime_matchesErgometerJSWorkingExample() {
        // Bevestigd voorbeeld: 1:40 → (1*60+40)*100 = 10000.
        let command = PM5ProprietaryCommand.setTargetPaceTime(centiseconds: 10000)
        XCTAssertEqual(command.detailCommandID, 0x06)
        XCTAssertEqual(command.payload, [0x00, 0x00, 0x27, 0x10])
    }

    func test_configureWorkout_encodesBooleanAsSingleByte() {
        XCTAssertEqual(PM5ProprietaryCommand.configureWorkout(programmingMode: true).payload, [0x01])
        XCTAssertEqual(PM5ProprietaryCommand.configureWorkout(programmingMode: false).payload, [0x00])
    }

    func test_setTargetAverageWatts_noUnitByteTwoBytesBigEndian() {
        let command = PM5ProprietaryCommand.setTargetAverageWatts(220)
        XCTAssertEqual(command.detailCommandID, 0x15)
        XCTAssertEqual(command.payload, [0x00, 0xDC])
    }

    func test_setIntervalType_encodesSingleByte() {
        let command = PM5ProprietaryCommand.setIntervalType(PM5IntervalType.time)
        XCTAssertEqual(command.detailCommandID, 0x17)
        XCTAssertEqual(command.payload, [0x00])
    }

    func test_setWorkoutIntervalCount_isZeroBased() {
        let firstInterval = PM5ProprietaryCommand.setWorkoutIntervalCount(0)
        let secondInterval = PM5ProprietaryCommand.setWorkoutIntervalCount(1)
        XCTAssertEqual(firstInterval.payload, [0x00])
        XCTAssertEqual(secondInterval.payload, [0x01])
    }

    // MARK: - PM5Frame: SETPMCFG_CMD-wrapper

    func test_frameContent_wrapsSingleCommandUnderSetPMCfgCmd() {
        let content = PM5Frame.content(for: [.setWorkoutType(PM5WorkoutType.variableInterval)])
        // [0x76 (SETPMCFG_CMD), lengte=2 (detailCmd+1 payloadbyte), 0x01 (detailCommand), 0x08 (payload)]
        XCTAssertEqual(content, [0x76, 0x02, 0x01, 0x08])
    }

    func test_frameContent_wrapsMultipleCommandsAsSeparateBlocks() {
        let content = PM5Frame.content(for: [
            .setWorkoutIntervalCount(0),
            .configureWorkout(programmingMode: true)
        ])
        XCTAssertEqual(content, [
            0x76, 0x02, 0x18, 0x00,  // SET_WORKOUTINTERVALCOUNT(0)
            0x76, 0x02, 0x14, 0x01   // CONFIGURE_WORKOUT(true)
        ])
    }

    func test_encode_producesValidCompleteCSAFEFrame() throws {
        let frame = PM5Frame.encode(.setWorkoutIntervalCount(0))
        let decodedContent = try CSAFEFrame.decode(frame)
        XCTAssertEqual(decodedContent, [0x76, 0x02, 0x18, 0x00])
    }
}
