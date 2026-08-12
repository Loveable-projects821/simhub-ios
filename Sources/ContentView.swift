import SwiftUI

struct ContentView: View {
    @EnvironmentObject var hub: HubConnection

    @State private var ipAddress: String = ""
    @State private var pin: String = ""

    var body: some View {
        NavigationView {
            Group {
                if hub.state == .paired {
                    DashboardView()
                } else {
                    PairingView(ipAddress: $ipAddress, pin: $pin)
                }
            }
            .navigationTitle("SimHub")
        }
    }
}

struct PairingView: View {
    @EnvironmentObject var hub: HubConnection
    @Binding var ipAddress: String
    @Binding var pin: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect to your Android hub")
                .font(.headline)

            Text("Join the Android's hotspot WiFi first, then enter the IP and PIN shown on its screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Android IP (e.g. 192.168.43.1)", text: $ipAddress)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .autocapitalization(.none)
                .padding(.horizontal)

            TextField("6-digit PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.horizontal)

            statusLabel

            Button("Connect") {
                hub.connect(ip: ipAddress, pin: pin)
            }
            .buttonStyle(.borderedProminent)
            .disabled(ipAddress.isEmpty || pin.count != 6)
        }
        .padding()
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch hub.state {
        case .connecting: Text("Connecting…").foregroundColor(.orange)
        case .awaitingPin: Text("Verifying PIN…").foregroundColor(.orange)
        case .wrongPin: Text("Wrong PIN — check the Android screen").foregroundColor(.red)
        case .error(let msg): Text("Error: \(msg)").foregroundColor(.red)
        default: EmptyView()
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var hub: HubConnection

    var body: some View {
        List {
            Section("SIM Signal") {
                if hub.signalEvents.isEmpty {
                    Text("Waiting for signal data…").foregroundColor(.secondary)
                }
                ForEach(hub.signalEvents.keys.sorted(), id: \.self) { slot in
                    if let event = hub.signalEvents[slot] {
                        HStack {
                            Text("SIM \(slot + 1) — \(event.carrier)")
                            Spacer()
                            SignalBars(level: event.level)
                        }
                    }
                }
            }

            Section("Recent Calls") {
                if hub.callEvents.isEmpty {
                    Text("No call activity yet").foregroundColor(.secondary)
                }
                ForEach(hub.callEvents.prefix(10)) { call in
                    VStack(alignment: .leading) {
                        Text(call.number.isEmpty ? "Unknown" : call.number)
                        Text(call.state.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Messages") {
                if hub.smsEvents.isEmpty {
                    Text("No messages yet").foregroundColor(.secondary)
                }
                ForEach(hub.smsEvents.prefix(20)) { sms in
                    VStack(alignment: .leading) {
                        Text(sms.from).font(.subheadline).bold()
                        Text(sms.body).font(.body)
                    }
                }
            }

            Section {
                Button("Disconnect", role: .destructive) {
                    hub.disconnect()
                }
            }
        }
    }
}

struct SignalBars: View {
    let level: Int // 0...4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
    }
}
