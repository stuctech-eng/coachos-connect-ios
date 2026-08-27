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
        // TODO Sprint 2: baseURL uit configuratie/omgeving halen (dev/staging/prod),
        // niet hardcoded. Placeholder zodat de architectuur compileert en
        // aantoonbaar werkt.
        let baseURL = URL(string: "https://coach-os-tau.vercel.app")!
        self.container = AppAssembly.assemble(baseURL: baseURL)
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
