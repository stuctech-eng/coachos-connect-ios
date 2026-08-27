import SwiftUI
import CoachOSConnectCore
import CoachOSConnectDI

/// Minimale root view voor Sprint 1. Doel is uitsluitend aantonen dat de
/// dependency graph (DI → repositories → use cases) daadwerkelijk werkt.
/// Geen live-scherm, geen device-lijst, geen workout-player — die horen bij
/// latere sprints (Fase 2 Live Coaching e.v.).
struct RootView: View {
    let container: DIContainer

    @State private var todaysWorkout: UniversalWorkout?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bolt.horizontal.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("CoachOS Connect")
                    .font(.title2.bold())

                Text("Fase 1 – Fundament")
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView()
                } else if let workout = todaysWorkout {
                    Text("Vandaag: \(workout.title)")
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Nog geen workout opgehaald.")
                        .foregroundStyle(.secondary)
                }

                Button("Haal vandaag op") {
                    Task { await loadTodaysWorkout() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("CoachOS Connect")
        }
    }

    @MainActor
    private func loadTodaysWorkout() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let useCase = container.resolve(FetchTodaysWorkoutUseCase.self)
        do {
            todaysWorkout = try await useCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RootView(container: AppAssembly.assemble(baseURL: URL(string: "https://coach-os-tau.vercel.app")!))
}
