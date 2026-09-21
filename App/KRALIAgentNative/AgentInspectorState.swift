import Foundation
import Combine

@MainActor
final class AgentInspectorState: ObservableObject {
    @Published var mentorTraceStatus =
        "Henüz mentor kaydı yok."
    @Published var mentorTraceReady = false
    @Published var mentorSyncBusy = false

    @Published var trainingLabReport:
        TrainingLabReport?
    @Published var trainingLabStatus =
        "Henüz Training Lab çalıştırılmadı."
    @Published var trainingLabBusy = false

    @Published var liveResearchEvalReport:
        LiveResearchEvalReport?
    @Published var liveResearchEvalStatus =
        "Henüz gerçek internet kalite testi yapılmadı."
    @Published var liveResearchEvalBusy = false

    @Published var arenaReport:
        AgentArenaReport?
    @Published var arenaStatus =
        "Henüz KRALİ Arena çalıştırılmadı."
    @Published var arenaBusy = false

    @Published var screenPerceptionReport:
        ScreenPerceptionReport?
    @Published var screenPerceptionStatus =
        "Henüz Screen Perception Probe çalıştırılmadı."
    @Published var screenPerceptionBusy = false

    @Published var desktopControlReport:
        DesktopControlProbeReport?
    @Published var desktopControlStatus =
        "Desktop Control Probe henüz çalıştırılmadı."
    @Published var desktopControlBusy = false

    @Published var developerAgentStatus =
        DeveloperAgentStatus(
            state: "idle",
            message:
                "Developer Agent henüz çalıştırılmadı.",
            branch: nil,
            worktree: nil
        )
    @Published var developerAgentBusy = false

    @Published var learningQueueJobs:
        [AgentLearningJob] = []

    @Published var debugIncident:
        AgentDebugIncident?

    @Published var diagnosticsLoaded = false

    var activeLearningJobs: [AgentLearningJob] {
        learningQueueJobs.filter {
            !$0.state.isTerminal
        }
    }

    var shouldShowPrimaryDeveloperStatus: Bool {
        developerAgentStatus
            .shouldShowLearningStatus &&
        developerAgentStatus.state !=
            "stale_run"
    }

    var hasActiveLearning: Bool {
        !activeLearningJobs.isEmpty ||
        developerAgentStatus.isLearningActive ||
        developerAgentStatus.isReadyForReview
    }
}
