import SwiftUI

@main
struct KRALIAgentNativeApp: App {
    @StateObject private var engine = AgentEngine()

    var body: some Scene {
        WindowGroup("KRALİ") {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
