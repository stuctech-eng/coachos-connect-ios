import SwiftUI
import CoachOSConnectDI

/// Entrypoint van de native CoachOS Connect-app.
///
/// LET OP: dit bestand hoort in een Xcode App-target dat deze repository
/// als "Local Package" toevoegt (File → Add Package Dependencies → Add Local).
/// Het is bewust géén onderdeel van Package.swift zelf: Swift Package Manager
/// kan geen installeerbare iOS-app produceren zonder Xcode-App-target.
@main
struct CoachOSConnectApp: App {
    private let container: DIContainer

    init() {
        // TODO: uit configuratie/omgeving halen (dev/staging/prod),
        // niet hardcoded. Placeholder zodat de architectuur compileert en
        // aantoonbaar werkt.
        let baseURL = URL(string: "https://coach-os-tau.vercel.app")!

        // Project-URL bevestigd tijdens de contract-review (28 augustus
        // 2026, uit CoachOS' eigen .env.example — dit is CoachOS' eigen
        // Supabase-project, publiek adres, geen secret).
        let supabaseProjectURL = URL(string: "https://fabtmkrzqrrwbvgaugjm.supabase.co")!

        // BELANGRIJK, NIET DOOR MIJ IN TE VULLEN: dit is de publieke/
        // publishable Supabase-sleutel (veilig om in een clientapp te
        // zetten, vergelijkbaar met hoe de PWA 'm client-side gebruikt —
        // GEEN secret/service-role key). In CoachOS' eigen .env.example
        // stond hiervoor alleen een placeholder ("jouw_publishable_key"),
        // dus de echte waarde was niet ergens in de repository te vinden.
        // Haal 'm op uit het CoachOS Supabase-dashboard (Project
        // Settings → API → Publishable key) en vul 'm hieronder in vóór
        // het bouwen — anders faalt elke aanmeldpoging met een
        // duidelijke serverfout, geen stille verkeerde aanname.
        let supabaseAnonKey = "VUL_HIER_DE_ECHTE_PUBLISHABLE_KEY_IN"

        self.container = AppAssembly.assemble(
            baseURL: baseURL,
            supabaseProjectURL: supabaseProjectURL,
            supabaseAnonKey: supabaseAnonKey
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
