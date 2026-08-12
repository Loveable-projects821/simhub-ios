import Foundation
import Combine

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case awaitingPin
    case paired
    case wrongPin
    case error(String)
}

/// Connects directly to the Android hub's WebSocket server over the shared hotspot/WiFi.
/// No cloud, no external signaling — this talks straight to ws://<android-ip>:8765
final class HubConnection: NSObject, ObservableObject {

    @Published var state: ConnectionState = .disconnected
    @Published var signalEvents: [Int: SignalEvent] = [:]   // keyed by SIM slot, latest wins
    @Published var callEvents: [CallEvent] = []
    @Published var smsEvents: [SmsEvent] = []

    /// Fired whenever a call starts ringing — the app layer uses this to trigger CallKit.
    var onIncomingCall: ((CallEvent) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    func connect(ip: String, port: Int = 8765, pin: String) {
        guard let url = URL(string: "ws://\(ip):\(port)") else {
            state = .error("Invalid address")
            return
        }
        state = .connecting
        task = session.webSocketTask(with: url)
        task?.resume()
        listen()

        // First message must be the pairing request.
        let pairMessage: [String: Any] = ["type": "pair", "pin": pin]
        send(json: pairMessage)
        state = .awaitingPin
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        state = .disconnected
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.state = .error(error.localizedDescription)
                }
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handle(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handle(text: text)
                    }
                @unknown default:
                    break
                }
            }
            // Keep listening for the next message.
            self.listen()
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "paired":
                let status = json["status"] as? String
                self.state = (status == "ok") ? .paired : .wrongPin

            case "signal":
                if let event = SignalEvent(json: json) {
                    self.signalEvents[event.slot] = event
                }

            case "call":
                if let event = CallEvent(json: json) {
                    self.callEvents.insert(event, at: 0)
                    if event.state == "ringing" {
                        self.onIncomingCall?(event)
                    }
                }

            case "sms":
                if let event = SmsEvent(json: json) {
                    self.smsEvents.insert(event, at: 0)
                }

            default:
                break
            }
        }
    }
}
