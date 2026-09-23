import SwiftUI

@main
struct KRALIAgentNativeApp: App {
    @StateObject private var engine = AgentEngine()

    var body: some Scene {
        WindowGroup("KRALİ") {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 680, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
