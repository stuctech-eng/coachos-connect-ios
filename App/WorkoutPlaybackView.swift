import SwiftUI
import CoachOSConnectCore
import CoachOSConnectWorkoutPlayback

/// Optie B: toont interval/stap, resterende tijd, SPM-instructie/
/// coachMessage en huidige fase tijdens een training. De PM5 hoeft geen
/// SPM-commando te kennen — dit scherm toont gewoon de door CoachOS
/// aangeleverde `instruction`-tekst (zie `CoachOSWorkoutMapper`, Sprint
/// 6b-2).
///
/// Bewust dun: alle logica zit in `WorkoutPlaybackController`. Nog geen
/// koppeling met daadwerkelijk PM5-hardwareverkeer hier — dit scherm telt
/// af op basis van de klok, niet op basis van PM5-telemetrie (Sprint 8).
struct WorkoutPlaybackView: View {
    @StateObject private var controller: WorkoutPlaybackController

    init(workout: UniversalWorkout) {
        _controller = StateObject(wrappedValue: WorkoutPlaybackController(workout: workout))
    }

    var body: some View {
        VStack(spacing: 24) {
            if let display = controller.display {
                Text(display.step.kind.displayLabel)
                    .font(.title.bold())

                Text("Stap \(display.stepIndex + 1) van \(display.totalSteps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let remaining = display.remainingSeconds {
                    Text(formatted(seconds: remaining))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    VStack(spacing: 8) {
                        Text(formatted(seconds: display.elapsedSeconds))
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text("Geen tijdsduur bekend — druk op 'Volgende' wanneer je klaar bent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if let instruction = display.step.instruction {
                    Text(instruction)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if display.remainingSeconds == nil {
                    Button("Volgende stap") {
                        controller.advanceManually()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if controller.isFinished {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Training voltooid")
                        .font(.title2.bold())
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle("Training")
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private func formatted(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
