import SwiftUI
import CoachOSConnectBluetooth
import CoachOSConnectDeviceDiscovery

/// Sprint 4: generieke "apparaten in de buurt"-lijst. Toont wat de
/// Bluetooth-laag ontdekt, zonder aan te nemen welk apparaat het is — geen
/// PM5-naam, geen Concept2-logo, geen fabrikant-specifieke iconen. Die
/// interpretatie hoort bij een toekomstige adapter (Sprint 5).
///
/// Bewust dun: alle logica zit in `DeviceDiscoveryController`, hier alleen
/// declaratieve weergave. Dat is ook waarom dit bestand (net als de rest
/// van `App/`) niet door de CI-tests wordt gedekt — de logica waar het op
/// leunt wel, zie `CoachOSConnectDeviceDiscoveryTests`.
struct DevicesView: View {
    @StateObject private var controller: DeviceDiscoveryController

    init(bluetooth: BluetoothManagerProtocol) {
        _controller = StateObject(wrappedValue: DeviceDiscoveryController(bluetooth: bluetooth))
    }

    var body: some View {
        List {
            if let lastError = controller.lastError {
                Section {
                    Text(lastError.localizedDescription ?? "Onbekende Bluetooth-fout")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                ForEach(controller.discoveredDevices) { device in
                    DeviceRow(
                        device: device,
                        connectionState: controller.connectionState(for: device.id),
                        onConnect: { Task { await controller.connect(to: device.id) } },
                        onDisconnect: { Task { await controller.disconnect(from: device.id) } }
                    )
                }
            } header: {
                if controller.isScanning {
                    HStack {
                        ProgressView()
                        Text("Zoeken naar apparaten…")
                    }
                } else if controller.discoveredDevices.isEmpty {
                    Text("Nog geen apparaten gevonden")
                }
            }
        }
        .navigationTitle("Apparaten")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(controller.isScanning ? "Stop" : "Scan") {
                    Task {
                        if controller.isScanning {
                            await controller.stopScan()
                        } else {
                            await controller.startScan()
                        }
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: BluetoothDevice
    let connectionState: BluetoothConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? "Onbekend apparaat")
                    .font(.body)
                Text("Signaal: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch connectionState {
        case .disconnected, .failed:
            Button("Verbind", action: onConnect)
                .buttonStyle(.bordered)
                .disabled(!device.isConnectable)
        case .connecting, .reconnecting:
            ProgressView()
        case .connected:
            Button("Verbreek", action: onDisconnect)
                .buttonStyle(.borderedProminent)
        case .disconnecting:
            ProgressView()
        }
    }
}
