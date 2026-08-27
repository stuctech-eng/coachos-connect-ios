import Foundation
import CoachOSConnectCore
import CoachOSConnectBluetooth
import CoachOSConnectPM5
import CoachOSConnectDeviceLayer
import CoachOSConnectData

/// Enige plek in de app waar concrete implementaties aan protocollen worden
/// gekoppeld. Use cases, ViewModels en views kennen alleen protocollen uit
/// `CoachOSConnectCore` — nooit `RemoteWorkoutRepository`, `APIClient` of
/// andere concrete types rechtstreeks.
///
/// Nieuwe adapters registreren gebeurt hier ook (zie `registerDeviceAdapters`),
/// zodat het toevoegen van een fabrikant nooit vraagt om wijzigingen in
/// use cases of UI.
public enum AppAssembly {

    /// Bouwt de volledige dependency graph. Wordt éénmalig aangeroepen bij
    /// app-opstart (zie `App/CoachOSConnectApp.swift`).
    ///
    /// - Parameters:
    ///   - baseURL: CoachOS-backend (Next.js/Vercel), voor de
    ///     workout-/sync-endpoints in `CoachOSEndpoints`.
    ///   - supabaseProjectURL: het Supabase-project van CoachOS zelf
    ///     (overeenkomend met CoachOS' `NEXT_PUBLIC_SUPABASE_URL`) —
    ///     ANDERS dan `baseURL`, dit is Supabase's eigen adres, niet de
    ///     CoachOS-backend.
    ///   - supabaseAnonKey: de publieke Supabase-sleutel (overeenkomend
    ///     met CoachOS' `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`).
    public static func assemble(baseURL: URL, supabaseProjectURL: URL, supabaseAnonKey: String) -> DIContainer {
        let container = DIContainer()

        // Infrastructuur
        let apiClient = APIClient(baseURL: baseURL)
        let localStorage = FileLocalStorage()
        let workoutCache = WorkoutCache(storage: localStorage)
        let deviceLayer = DeviceLayer()
        let supabaseAuthClient = SupabaseAuthClient(projectURL: supabaseProjectURL, anonKey: supabaseAnonKey)
        let tokenStore = KeychainTokenStore()

        // Generieke Bluetooth-laag (Sprint 3). Puur infrastructuur: nog aan
        // geen enkele adapter gekoppeld. Dat gebeurt pas in Sprint 5 zodra
        // `PM5Adapter` bestaat en zelf een `BluetoothManagerProtocol`
        // injecteert.
        let bluetoothManager = CoreBluetoothManager()

        container.register(APIClient.self) { apiClient }
        container.register(LocalStorageProtocol.self) { localStorage }
        container.register(DeviceLayer.self) { deviceLayer }
        container.register(BluetoothManagerProtocol.self) { bluetoothManager }

        // Repositories (Data-laag, achter Core-protocollen)
        let authRepository = RemoteAuthRepository(authClient: supabaseAuthClient, tokenStore: tokenStore)
        let workoutRepository = RemoteWorkoutRepository(apiClient: apiClient, cache: workoutCache)
        let deviceRepository = LocalDeviceRepository(storage: localStorage, deviceLayer: deviceLayer)
        let syncRepository = LocalSyncRepository(storage: localStorage, apiClient: apiClient)

        container.register(AuthRepositoryProtocol.self) { authRepository }
        container.register(WorkoutRepositoryProtocol.self) { workoutRepository }
        container.register(DeviceRepositoryProtocol.self) { deviceRepository }
        container.register(SyncRepositoryProtocol.self) { syncRepository }

        // API client krijgt zijn token via de auth-repository, niet andersom.
        Task {
            await apiClient.setAccessTokenProvider {
                await authRepository.currentSession()?.accessToken
            }
        }

        // Use cases
        container.register(FetchTodaysWorkoutUseCase.self) {
            FetchTodaysWorkoutUseCase(workoutRepository: workoutRepository)
        }
        container.register(SyncPendingItemsUseCase.self) {
            SyncPendingItemsUseCase(syncRepository: syncRepository)
        }

        registerDeviceAdapters(in: deviceLayer, bluetoothManager: bluetoothManager)

        return container
    }

    /// Centrale plek om adapter-fabrieken te registreren bij de `DeviceLayer`.
    /// Sinds Sprint 5b: `PM5Adapter` wordt hier geregistreerd, exact zoals de
    /// placeholder sinds Sprint 1 al aangaf. Nieuwe fabrikanten komen hier
    /// op dezelfde manier bij, zonder dat use cases of UI hoeven te
    /// wijzigen.
    private static func registerDeviceAdapters(in deviceLayer: DeviceLayer, bluetoothManager: BluetoothManagerProtocol) {
        Task {
            await deviceLayer.register(
                { PM5Adapter(bluetooth: bluetoothManager) },
                for: PM5Adapter.descriptor
            )
        }
    }
}
