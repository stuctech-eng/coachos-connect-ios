import Foundation
import CoachOSConnectCore
import CoachOSConnectBluetooth
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
    public static func assemble(baseURL: URL) -> DIContainer {
        let container = DIContainer()

        // Infrastructuur
        let apiClient = APIClient(baseURL: baseURL)
        let localStorage = FileLocalStorage()
        let workoutCache = WorkoutCache(storage: localStorage)
        let deviceLayer = DeviceLayer()

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
        let authRepository = RemoteAuthRepository(storage: localStorage, apiClient: apiClient)
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
    /// Nog steeds leeg — de Bluetooth-laag uit Sprint 3 kent geen PM5. Vanaf
    /// Sprint 5 komt hier bijvoorbeeld:
    ///
    /// ```swift
    /// Task {
    ///     await deviceLayer.register(
    ///         { PM5Adapter(bluetooth: bluetoothManager) },
    ///         for: PM5Adapter.descriptor
    ///     )
    /// }
    /// ```
    private static func registerDeviceAdapters(in deviceLayer: DeviceLayer, bluetoothManager: BluetoothManagerProtocol) {
        // Bewust leeg tot en met Sprint 4. PM5-registratie start in Sprint 5.
    }
}
