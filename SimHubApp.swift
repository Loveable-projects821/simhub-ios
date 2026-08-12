import SwiftUI

@main
struct SimHubApp: App {
    @StateObject private var hub = HubConnection()

    init() {
        // Wire the two systems together up front so it's obvious where the
        // "real call ringing" event turns into a native iPhone call screen.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hub)
                .onAppear {
                    hub.onIncomingCall = { event in
                        CallKitManager.shared.reportIncomingCall(from: event.number)
                    }
                    CallKitManager.shared.onAnswer = {
                        // Phase 2: start the WebRTC audio session with the Android hub here.
                    }
                    CallKitManager.shared.onEnd = {
                        // Phase 2: tear down the WebRTC audio session here.
                    }
                }
        }
    }
}
