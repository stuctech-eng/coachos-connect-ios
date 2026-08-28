import Foundation
import Combine
import CoachOSConnectCore

/// Weergave-informatie voor de huidige stap tijdens een training.
public struct WorkoutStepDisplay: Equatable, Sendable {
    public let step: WorkoutStep
    public let stepIndex: Int
    public let totalSteps: Int
    /// Resterende seconden — alleen bekend voor tijdgebaseerde stappen.
    /// `nil` voor afstandgebaseerde of open-einde-stappen: zonder live
    /// PM5-telemetrie (Sprint 8) is er geen betrouwbare manier om te
    /// weten wanneer zo'n stap eindigt.
    public let remainingSeconds: Int?
    public let elapsedSeconds: Int
    public let isLastStep: Bool
}

/// Toont, puur op basis van verstreken tijd sinds start, welke stap van
/// een `UniversalWorkout` actief is — Optie B (productbeslissing 28
/// augustus 2026): de PM5 hoeft geen SPM-commando te kennen, Connect
/// toont gewoon de door CoachOS aangeleverde `instruction`/`coachMessage`
/// tekst tijdens de training.
///
/// Bewust GEEN koppeling aan echte PM5-telemetrie hier — dat is Sprint 8.
/// Deze controller telt af op basis van de klok, niet op basis van wat
/// de PM5 daadwerkelijk meet. Voor tijdgebaseerde stappen (de bevestigde
/// MVP-keten, zie `PM5WorkoutProgrammer`) is dat betrouwbaar genoeg;
/// voor afstand-/open-einde-stappen kan de gebruiker handmatig
/// doorgaan via `advanceManually()`.
@MainActor
public final class WorkoutPlaybackController: ObservableObject {
    @Published public private(set) var display: WorkoutStepDisplay?
    @Published public private(set) var isFinished: Bool = false
    @Published public private(set) var isRunning: Bool = false

    private let steps: [WorkoutStep]
    private let now: () -> Date
    private var stepIndex = 0
    private var stepStartedAt: Date
    private var tickTask: Task<Void, Never>?

    /// - Parameter now: injecteerbaar voor tests — standaard de systeemklok.
    public init(workout: UniversalWorkout, now: @escaping () -> Date = Date.init) {
        self.steps = workout.expandedSteps
        self.now = now
        self.stepStartedAt = now()
    }

    deinit {
        tickTask?.cancel()
    }

    public func start() {
        guard !steps.isEmpty else {
            isFinished = true
            return
        }
        stepIndex = 0
        stepStartedAt = now()
        isRunning = true
        isFinished = false
        updateDisplay()

        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self.tick()
            }
        }
    }

    public func stop() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
    }

    /// Voor afstand-/open-einde-stappen, waar geen automatische
    /// tijdsafloop bestaat — de gebruiker beslist zelf wanneer door te gaan.
    public func advanceManually() {
        advance()
    }

    /// Publiek zodat tests de klok kunnen "verzetten" zonder echt te
    /// hoeven wachten — geen verborgen, ongeteste timinglogica.
    public func tick() {
        guard isRunning, stepIndex < steps.count else { return }
        let step = steps[stepIndex]
        let elapsed = Int(now().timeIntervalSince(stepStartedAt))

        if case .time(let seconds) = step.duration, elapsed >= seconds {
            advance()
        } else {
            updateDisplay()
        }
    }

    private func advance() {
        stepIndex += 1
        stepStartedAt = now()

        if stepIndex >= steps.count {
            isFinished = true
            display = nil
            stop()
        } else {
            updateDisplay()
        }
    }

    private func updateDisplay() {
        guard stepIndex < steps.count else { return }
        let step = steps[stepIndex]
        let elapsed = Int(now().timeIntervalSince(stepStartedAt))

        let remaining: Int?
        if case .time(let seconds) = step.duration {
            remaining = max(0, seconds - elapsed)
        } else {
            remaining = nil
        }

        display = WorkoutStepDisplay(
            step: step,
            stepIndex: stepIndex,
            totalSteps: steps.count,
            remainingSeconds: remaining,
            elapsedSeconds: elapsed,
            isLastStep: stepIndex == steps.count - 1
        )
    }
}
