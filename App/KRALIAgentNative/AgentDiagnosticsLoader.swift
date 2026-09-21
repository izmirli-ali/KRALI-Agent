import Foundation

struct AgentDiagnosticsSnapshot {
    let trainingLabReport: TrainingLabReport?
    let liveResearchEvalReport: LiveResearchEvalReport?
    let arenaReport: AgentArenaReport?
    let screenPerceptionReport: ScreenPerceptionReport?
    let screenPerceptionStatus: String?
    let desktopControlReport: DesktopControlProbeReport?
    let desktopControlStatus: String?
}

struct AgentDiagnosticsLoader {
    private let fileManager = FileManager.default
    private let trainingLabStore = TrainingLabStore()
    private let liveResearchEvalStore =
        LiveResearchEvalStore()
    private let arenaStore = AgentArenaStore()
    private let screenPerceptionStore =
        ScreenPerceptionStore()
    private let desktopControlStore =
        DesktopControlProbeStore()

    func hasStoredDiagnostics() -> Bool {
        [
            trainingLabStore.outputURL,
            liveResearchEvalStore.outputURL,
            arenaStore.outputURL,
            screenPerceptionStore.outputURL,
            screenPerceptionStore.statusURL,
            desktopControlStore.outputURL,
            desktopControlStore.statusURL
        ]
        .contains {
            fileManager.fileExists(
                atPath: $0.path
            )
        }
    }

    func load() -> AgentDiagnosticsSnapshot {
        AgentDiagnosticsSnapshot(
            trainingLabReport:
                trainingLabStore.load(),
            liveResearchEvalReport:
                liveResearchEvalStore.load(),
            arenaReport:
                arenaStore.load(),
            screenPerceptionReport:
                screenPerceptionStore.load(),
            screenPerceptionStatus:
                screenPerceptionStore.readStatus(),
            desktopControlReport:
                desktopControlStore.load(),
            desktopControlStatus:
                desktopControlStore.readStatus()
        )
    }
}
