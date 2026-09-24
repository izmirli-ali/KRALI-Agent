import Foundation
import AppKit
import Combine

@MainActor
final class AgentEngine: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var conversationHistory: [ConversationArchiveSegment] = []
    @Published var selectedConversationArchiveID: String?
    @Published var archivedConversationPreview: [ChatMessage] = []

    var visibleConversationMessages: [ChatMessage] {
        selectedConversationArchiveID == nil
            ? messages
            : archivedConversationPreview
    }

    var isViewingArchivedConversation: Bool {
        selectedConversationArchiveID != nil
    }

    @Published var activities: [ActivityItem] = []
    @Published var activeRoute: [String] = ["Core"]
    @Published var memories: [String] = []
    @Published var contextMemoryEntries: [AgentContextMemoryEntry] = []
    @Published var activeContextMemories: [AgentContextMemoryEntry] = []
    @Published var contextMemoryStatus = "Henüz görev bağlamı yok."

    @Published var selectedRootURL: URL?
    @Published var indexedFiles: [FileRecord] = []
    @Published var indexedFolders: [FolderRecord] = []
    @Published var pendingFileAction: PendingFileAction?
    @Published var pendingTaskApproval: PendingTaskApproval?
    @Published var pendingDeveloperToolApproval:
        PendingDeveloperToolApproval?
    @Published var lastUndoAction: UndoFileAction?
    @Published var fileSearchResults: [FileRecord] = []
    @Published var folderSearchResults: [FolderRecord] = []
    @Published var fileSearchTitle = ""
    @Published var workspaceIndexReady = false
    private(set) var lastFileSearchOutcome:
        AgentFileSearchOutcome?

    @Published var currentGoal = "Hazır"
    @Published var currentPlan = "Yeni görevi bekliyor"
    @Published var currentAlternatives: [String] = []
    @Published var currentSemanticMission: AgentSemanticMission?
    @Published var currentSemanticPlannerProvider: String?
    @Published var missionOwner: AgentMissionOwner = .runtime
    @Published var missionPhase: AgentMissionPhase = .runtime
    @Published var developerRepository: AgentDeveloperRepository?
    @Published var developerMissionReason: String?
    @Published var executionProfile: AgentExecutionProfile = .developmentResearchMode
    @Published var currentTaskGraph: AgentTaskGraph?
    @Published var currentRuntimeTask: AgentRuntimeTask?
    @Published var taskGraphStatus = "Henüz görev grafiği yok."
    @Published var currentProblemResolution: AgentProblemResolution?
    @Published var currentOutcomeResolution: AgentOutcomeResolution?
    @Published var currentOutcomeAttempts: [AgentOutcomeStrategyAttempt] = []
    @Published var currentReflectionSummary: String?
    @Published var currentSelfDiagnosisReport: AgentSelfDiagnosisReport?
    @Published var currentCapabilityGaps: [CapabilityGapResolution] = []
    @Published var executionSteps: [AgentExecutionStep] = []
    @Published var verificationState: AgentVerificationState = .idle
    @Published var verificationSummary = "Henüz doğrulama yapılmadı."
    @Published var fallbackPlan: String?
    @Published var recoverySummary: String?
    @Published var selectedCapabilities: [AgentCapability] = []
    @Published var capabilityLearningPlans: [CapabilityLearningPlan] = []
    @Published var capabilityLearningBacklog: [CapabilityLearningTask] = []
    @Published var webResearchResults: [WebResearchResult] = []
    @Published var webResearchEvidence: [WebSourceEvidence] = []
    @Published var webResearchStatus = "Henüz web araştırması yapılmadı."
    @Published var localIntelligenceState: LocalIntelligenceState = .checking
    @Published var intelligenceProviderStatus = "Sentez sağlayıcısı henüz kullanılmadı."

    @Published var voiceOutputEnabled = true {
        didSet {
            UserDefaults.standard.set(
                voiceOutputEnabled,
                forKey: "krali.native.voiceOutputEnabled.v1"
            )
        }
    }
    @Published var busy = false

    let speech = SpeechController()
    let inspectorState = AgentInspectorState()

    private let memoryKey = "krali.native.memories.v1"
    private let selectedRootKey = "krali.native.selectedRootPath.v1"
    private let fileManager = FileManager.default
    private let brain = AgentBrain()
    private let planner = AgentPlanner()
    private let taskOrchestrator = AgentTaskOrchestrator()
    private let taskRuntimePlanner =
        AgentTaskRuntimePlanner()
    private let missionNormalizer = AgentMissionNormalizer()
    private let problemSolver = AgentProblemSolver()
    private let outcomePlanner = AgentOutcomePlanner()
    private let capabilityGapResolver = AgentCapabilityGapResolver()
    private let verifier = AgentVerifier()
    private let capabilityRegistry = AgentCapabilityRegistry()
    private let goalInterpreter = AgentGoalInterpreter()
    private let responseComposer = AgentResponseComposer()
    private let routeBuilder = AgentRouteBuilder()
    private let capabilityLearner = AgentCapabilityLearner()
    private let learningStore = AgentLearningStore()
    private let skillLibraryStore = AgentSkillLibraryStore()
    private let webResearchService = AgentWebResearchService()
    private let webSourceReader = AgentWebSourceReader()
    private let researchQueryPlanner =
        AgentResearchQueryPlanner()
    private let developmentResearchSourceClassifier =
        AgentDevelopmentResearchSourceClassifier()
    private let developmentResearchVerifier =
        AgentDevelopmentResearchVerifier()
    private let mentorTraceStore = MentorTraceStore()
    private let trainingLab = AgentTrainingLab()
    private let trainingLabStore = TrainingLabStore()
    private let liveResearchEval = AgentLiveResearchEval()
    private let liveResearchEvalStore = LiveResearchEvalStore()
    private let arena = AgentArena()
    private let arenaStore = AgentArenaStore()
    private let screenPerception = AgentScreenPerception()
    private let appWorkflowStrategy = AgentAppWorkflowStrategy()
    private let screenPerceptionStore = ScreenPerceptionStore()
    private let desktopControl = AgentDesktopControl()
    private let desktopControlStore = DesktopControlProbeStore()
    private let textFileWriter = AgentTextFileWriter()
    private let developerBridge = AgentDeveloperBridge()
    private let missionRouter = AgentMissionRouter()
    private let developerRepositoryResolver = AgentDeveloperRepositoryResolver()
    private let developerContextFirewall = AgentDeveloperContextFirewall()
    private let selfDiagnosisExecutor = AgentSelfDiagnosisExecutor()
    private let developerToolSafetyPolicy =
        AgentDeveloperToolSafetyPolicy()
    private let learningQueueStore = AgentLearningQueueStore()
    private let debugRecoveryCenter = AgentDebugRecoveryCenter()
    private let localIntelligence = AgentLocalIntelligence()
    private let subscriptionIntelligence = AgentSubscriptionIntelligence()
    private let contextMemoryStore = AgentContextMemoryStore()
    private let conversationStore = ConversationStore()
    private let workspaceIndexer = AgentWorkspaceIndexer()
    private let fileQueryParser = AgentFileQueryParser()
    private let naturalLanguageResolver =
        AgentNaturalLanguageResolver()
    private let fileSearchCoordinator =
        AgentFileSearchCoordinator()
    private let diagnosticsLoader = AgentDiagnosticsLoader()
    private let workspaceIndexFreshness: TimeInterval = 45
    private var workspaceIndexUpdatedAt: Date?
    private var inspectorStateForwarder: AnyCancellable?
    private var lastDecision: AgentDecision?
    private var activeLearningJobID: UUID?
    private var pendingDeveloperLearningJob:
        AgentLearningJob?
    private var pendingDeveloperLearningJobBriefURL:
        URL?
    private var pendingDeveloperTask:
        AgentDeveloperTaskDescriptor?
    private var currentOutcomeFailureIsTransient = false
    private var currentTaskInput = ""
    // Only set by the mission that actually starts a Developer Agent run.
    // Never reuse inspector status from an earlier mission as trace ownership.
    private var missionDeveloperRunID: String?
    private var approvedRuntimeStepIndexes = Set<Int>()
    private var approvedRuntimeApplicationTargets:
        [Int: DesktopApplicationApprovalTarget] = [:]
    private var currentTaskApprovalAudit:
        TaskApprovalAudit?
    private var runtimeStepEvidence: [Int: String] = [:]
    private var runtimeExecutedCapabilityIDs = Set<String>()

    private var currentAppVersionString: String {
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "unknown"
    }

    private var currentAppSourceRevision: String? {
        if let value =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "KRALISourceRevision"
            ) as? String {
            let trimmed =
                value.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        guard
            let url = Bundle.main.url(
                forResource:
                    "KRALISourceRevision",
                withExtension:
                    "txt"
            ),
            let raw = try? String(
                contentsOf: url,
                encoding: .utf8
            )
        else {
            return nil
        }

        let trimmed =
            raw.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }

    /// The active runtime capability surface after execution-profile policy.
    /// Paused computer-control capabilities are excluded from planning,
    /// normalization, fallback selection, execution and gap generation.
    private func runtimeCapabilities() -> [AgentCapability] {
        capabilityRegistry.availableCapabilities(
            for: executionProfile
        )
    }

    init() {
        inspectorStateForwarder =
            inspectorState.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }

        if UserDefaults.standard.object(
            forKey: "krali.native.voiceOutputEnabled.v1"
        ) != nil {
            voiceOutputEnabled = UserDefaults.standard.bool(
                forKey: "krali.native.voiceOutputEnabled.v1"
            )
        }

        let restoredMessages =
            conversationStore.loadActive()

        if restoredMessages.isEmpty {
            messages = [
                starterConversationMessage()
            ]
            messages =
                conversationStore.persistActive(
                    messages
                )
        } else {
            messages = restoredMessages
        }

        conversationHistory =
            conversationStore.archiveSegments()

        loadMemory()
        contextMemoryEntries = contextMemoryStore.load()

        for rule in memories {
            contextMemoryEntries = contextMemoryStore.upsertRule(
                rule,
                in: contextMemoryEntries
            )
        }

        contextMemoryStore.save(contextMemoryEntries)
        contextMemoryStatus = contextMemoryEntries.isEmpty
            ? "Henüz görev bağlamı yok."
            : "\(contextMemoryEntries.count) bağlam kaydı hazır."

        let mergedLearningBacklog =
            learningStore.merge(
                existing:
                    learningStore.load(),
                plans: [],
                capabilities:
                    capabilityRegistry.all
            )

        capabilityLearningBacklog =
            mergedLearningBacklog.filter {
                !executionProfile.isPaused(
                    $0.capabilityID
                )
            }

        inspectorState.mentorTraceReady =
            fileManager.fileExists(
                atPath: mentorTraceStore.latestURL.path
            ) ||
            diagnosticsLoader.hasStoredDiagnostics()

        if inspectorState.mentorTraceReady {
            inspectorState.mentorTraceStatus =
                "Mentor / diagnostic kaydı hazır."
        }

        let launchAppVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        inspectorState.developerAgentStatus =
            developerBridge
                .readStatus()
                .freshForApp(
                    launchAppVersion
                )

        if inspectorState.developerAgentStatus.state ==
            "stale_run" {
            developerBridge.writeStatus(
                inspectorState.developerAgentStatus
            )
        }

        inspectorState.learningQueueJobs =
            learningQueueStore
                .recoverInterruptedJobs(
                    learningQueueStore.load(),
                    activeRunIsFresh:
                        inspectorState.developerAgentStatus
                            .isLearningActive
                )

        for job in inspectorState
            .learningQueueJobs
            where job.state == .failed &&
                (
                    job.lastStatus?
                        .contains(
                            "capability eksikliği değildir"
                        ) == true
                ) {
            capabilityLearningBacklog =
                learningStore.update(
                    existing:
                        capabilityLearningBacklog,
                    capabilityID:
                        job.capabilityID,
                    progress:
                        .interrupted,
                    nextStep:
                        "Önceki öğrenme işi observation belirsizliği veya foreground müdahalesinden doğmuştu; gerçek capability eksikliği olmadığı için kapatıldı."
                )
        }

        if let running =
            inspectorState.learningQueueJobs.first(
                where: {
                    $0.state == .running
                }
            ) {
            activeLearningJobID =
                running.id
        }

        if inspectorState.developerAgentStatus.state == "no_change" {
            loadDiagnosticsIfNeeded()
        }

        log("KRALİ Core hazır")
        log("Dinamik hedef ve kabiliyet yönlendirme aktif")
        log("Ağır geliştirici testleri normal açılışta otomatik çalıştırılmıyor")
        restoreSelectedFolder()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let state = await self.localIntelligence.availability()
            self.localIntelligenceState = state
            self.log(state.title)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            if self.inspectorState
                .developerAgentStatus
                .isReadyForReview,
               let recovered =
                await self.developerBridge
                    .recoverPendingCandidate() {
                self.inspectorState.developerAgentStatus =
                    recovered

                self.log(
                    "Developer candidate recovery: " +
                    recovered.message
                )
            }

            self.startNextLearningJobIfNeeded()
        }
    }

    // MARK: - Lazy Diagnostics

    func loadDiagnosticsIfNeeded() {
        guard !inspectorState.diagnosticsLoaded else {
            return
        }

        let snapshot = diagnosticsLoader.load()

        inspectorState.trainingLabReport =
            snapshot.trainingLabReport
        inspectorState.liveResearchEvalReport =
            snapshot.liveResearchEvalReport
        inspectorState.arenaReport =
            snapshot.arenaReport
        inspectorState.screenPerceptionReport =
            snapshot.screenPerceptionReport
        inspectorState.desktopControlReport =
            snapshot.desktopControlReport

        if let report = inspectorState.trainingLabReport {
            inspectorState.trainingLabStatus =
                "Son test: \(report.passed)/\(report.total) geçti • " +
                "Core \(report.corePassed)/\(report.coreTotal) • " +
                "North Star \(report.northStarPassed)/\(report.northStarTotal)"
            inspectorState.mentorTraceReady = true
        }

        if let report = inspectorState.liveResearchEvalReport {
            inspectorState.liveResearchEvalStatus =
                "Son gerçek test: \(report.passed)/\(report.total) geçti"
            inspectorState.mentorTraceReady = true
        }

        if let report = inspectorState.arenaReport {
            inspectorState.arenaStatus =
                "Son Arena: \(report.passed)/\(report.total) geçti • " +
                "\(report.failed) başarısız • " +
                "Reviewer \(report.reviewerFlagged) işaret"
            inspectorState.mentorTraceReady = true
        }

        if let report = inspectorState.screenPerceptionReport {
            inspectorState.screenPerceptionStatus =
                "Son Screen Probe: " +
                String(report.recognizedText.count) +
                " metin satırı • " +
                String(report.visibleWindows.count) +
                " pencere"
            inspectorState.mentorTraceReady = true
        } else if let status =
            snapshot.screenPerceptionStatus,
                  !status.isEmpty {
            inspectorState.screenPerceptionStatus = status
        }

        if let report = inspectorState.desktopControlReport {
            inspectorState.desktopControlStatus =
                "Son Desktop Probe: " +
                (report.launchOrActivateSucceeded
                    ? "uygulama açıldı/öne geldi"
                    : "başarısız") +
                " • AX " +
                (report.accessibilityTrusted
                    ? "izinli"
                    : "izin bekliyor")
            inspectorState.mentorTraceReady = true
        } else if let status =
            snapshot.desktopControlStatus,
                  !status.isEmpty {
            inspectorState.desktopControlStatus = status
        }

        inspectorState.diagnosticsLoaded = true
        validateNoChangeDiagnostics()
        log("Diagnostics isteğe bağlı yüklendi")
    }

    private func validateNoChangeDiagnostics() {
        guard inspectorState.developerAgentStatus.state == "no_change" else {
            return
        }

        let launchAppVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        let current =
            inspectorState.trainingLabReport?.appVersion ==
                launchAppVersion &&
            inspectorState.liveResearchEvalReport?.appVersion ==
                launchAppVersion &&
            inspectorState.arenaReport?.appVersion ==
                launchAppVersion

        guard !current else {
            return
        }

        let staleStatus =
            DeveloperAgentStatus(
                state: "stale_diagnostics",
                message:
                    "Önceki no_change kararı bu sürüm için geçerli değil. Güncel Training, Live ve Arena diagnostic'leri gerekiyor.",
                branch: nil,
                worktree: nil
            )

        inspectorState.developerAgentStatus = staleStatus
        developerBridge.writeStatus(
            staleStatus
        )
    }

    // MARK: - Chat

    private func appendConversationMessage(
        _ message: ChatMessage
    ) {
        messages.append(message)

        let beforePersistCount =
            messages.count

        messages =
            conversationStore.persistActive(
                messages
            )

        if messages.count < beforePersistCount {
            refreshConversationHistory()
        }
    }

    func postAssistantMessage(
        _ text: String
    ) {
        appendConversationMessage(
            ChatMessage(
                role: .assistant,
                text: text
            )
        )
    }

    func startNewConversation() {
        guard !busy else {
            return
        }

        speech.stopSpeaking()

        guard conversationStore
            .archiveActiveConversation(
                messages
            )
        else {
            log(
                "Yeni sohbet açılamadı: aktif konuşma güvenli şekilde arşivlenemedi"
            )
            return
        }

        messages = [
            starterConversationMessage()
        ]
        messages =
            conversationStore.persistActive(
                messages
            )

        selectedConversationArchiveID = nil
        archivedConversationPreview = []
        refreshConversationHistory()

        resetTransientTaskStateForNewInput()
        currentGoal = "Hazır"
        currentPlan = "Yeni görevi bekliyor"
        verificationState = .idle
        verificationSummary =
            "Henüz doğrulama yapılmadı."

        log("Yeni sohbet başlatıldı")
    }

    func showActiveConversation() {
        selectedConversationArchiveID = nil
        archivedConversationPreview = []
    }

    func openConversationArchive(
        _ segment: ConversationArchiveSegment
    ) {
        selectedConversationArchiveID =
            segment.id
        archivedConversationPreview =
            conversationStore.loadArchive(
                segment
            )
    }

    @discardableResult
    func deleteConversationArchive(
        _ segment: ConversationArchiveSegment
    ) -> Bool {
        guard
            conversationStore.deleteArchive(
                segment
            )
        else {
            log(
                "Geçmiş sohbet silinemedi: " +
                segment.title
            )
            return false
        }

        if selectedConversationArchiveID ==
            segment.id {
            selectedConversationArchiveID =
                nil
            archivedConversationPreview =
                []
        }

        refreshConversationHistory()
        log(
            "Geçmiş sohbet silindi: " +
            segment.title
        )
        return true
    }

    private func refreshConversationHistory() {
        conversationHistory =
            conversationStore.archiveSegments()
    }

    private func starterConversationMessage()
        -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: "Hazırım. Bana normal konuşur gibi hedefini söyle; gerekli kabiliyetleri seçip yolu kendim kuracağım."
        )
    }

    private func developerTaskRequest(
        from raw: String
    ) -> String? {
        let trimmed =
            raw.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
        let lower =
            trimmed.lowercased(
                with:
                    Locale(
                        identifier:
                            "tr_TR"
                    )
            )

        let prefixes = [
            "geliştirici görevi:",
            "gelistirici gorevi:",
            "developer task:"
        ]

        for prefix in prefixes {
            guard
                lower.hasPrefix(prefix)
            else {
                continue
            }

            let index =
                trimmed.index(
                    trimmed.startIndex,
                    offsetBy:
                        prefix.count
                )
            let query =
                String(
                    trimmed[index...]
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            return query.isEmpty
                ? nil
                : query
        }

        return nil
    }

    private func handleDeveloperTaskChatCommand(
        _ text: String
    ) -> Bool {
        guard
            let request =
                developerTaskRequest(
                    from: text
                )
        else {
            return false
        }

        let liveStatus =
            developerBridge
                .readStatus()
                .freshForApp(
                    currentAppVersionString
                )

        guard
            !inspectorState
                .developerAgentBusy,
            !liveStatus
                .isLearningActive
        else {
            postAssistantMessage(
                "Developer Agent zaten aktif. Mevcut görev tamamlanmadan yeni geliştirici görevi başlatılmadı."
            )
            return true
        }

        guard
            let task =
                developerBridge
                    .resolveDeveloperTask(
                        request
                    )
        else {
            postAssistantMessage(
                "Bu isimde kontrollü bir geliştirici görev kartı bulamadım: " +
                request +
                ". Görev kartı DeveloperAgent/Tasks altında olmalı."
            )
            return true
        }

        currentGoal =
            "Geliştirici görevi: " +
            task.title
        currentPlan =
            "İzole worktree → izinli scope içinde kodla → git diff → build-check → review"
        activeRoute = [
            "Core",
            "Developer"
        ]
        verificationState =
            .checking
        verificationSummary =
            task.title +
            " geliştirici görevi başlatılıyor."

        postAssistantMessage(
            task.title +
            " görevini kontrollü Developer Agent'a verdim. Main'e doğrudan yazmayacak; task kartındaki mutation scope uygulanacak. Sistem etkisi gerekirse burada ayrıca onay isteyeceğim."
        )

        runDeveloperAgent(
            developerTask:
                task
        )
        return true
    }

    /// Dynamic self-development goals intentionally stop at diagnosis.  The
    /// existing runner accepts only registered task cards with predeclared
    /// mutation scope, so this bridge cannot create mutation authority.
    private func handleSelfDevelopmentMission(
        _ text: String,
        source: ChatInputSource
    ) -> Bool {
        let routing =
            missionRouter.classify(text)
        missionOwner = routing.owner
        missionPhase = routing.phase
        developerMissionReason =
            routing.reason

        guard routing.owner != .runtime else {
            return false
        }

        currentTaskGraph = nil
        currentRuntimeTask = nil
        selectedCapabilities = []
        capabilityLearningPlans = []
        currentCapabilityGaps = []
        executionSteps = []
        currentSelfDiagnosisReport = nil
        activeRoute =
            routing.owner == .developer
            ? (
                routing.phase == .research
                ? [
                    "Core",
                    "Developer",
                    "Research",
                    "Compare",
                    "Proposal"
                ]
                : [
                    "Core",
                    "Developer",
                    "Diagnosis"
                ]
            )
            : [
                "Core",
                "Stop"
            ]

        if routing.owner == .stop {
            currentGoal =
                "Self-development authority escalation"
            currentPlan =
                "Stop → explicit user review"
            verificationState =
                .attention
            verificationSummary =
                routing.reason

            let reply =
                "Bu self-development isteği korunan yetki içeriyor. KRALİ kendi kendine izin, merge, secret veya filesystem yetkisi veremez; normal runtime görevi de başlatılmadı."

            postAssistantMessage(reply)

            recordMentorTrace(
                input: text,
                source: source,
                goal: currentGoal,
                plan: currentPlan,
                route: activeRoute,
                capabilities: [],
                learningPlans: [],
                verification:
                    AgentVerificationResult(
                        state: .attention,
                        summary:
                            routing.reason,
                        fallback:
                            "Explicit user review is required."
                    ),
                intelligenceProvider: nil,
                finalResponse: reply
            )
            return true
        }

        guard
            let repository =
                developerRepositoryResolver
                    .resolve(
                        userWorkspace:
                            selectedRootURL
                    )
        else {
            currentGoal =
                "KRALİ self-development diagnosis"
            currentPlan =
                "Stop → approved KRALİ repository identity required"
            verificationState =
                .attention
            verificationSummary =
                "Developer repository identity could not be resolved safely."

            let reply =
                "Bu hedef Developer Mission olarak sınıflandı; ancak KRALİ kaynak deposu güvenle doğrulanamadı. Kullanıcı çalışma alanı developer kaynağı olarak kullanılmadı ve mutation başlatılmadı."

            postAssistantMessage(reply)

            recordMentorTrace(
                input: text,
                source: source,
                goal: currentGoal,
                plan: currentPlan,
                route: activeRoute,
                capabilities: [],
                learningPlans: [],
                verification:
                    AgentVerificationResult(
                        state: .attention,
                        summary:
                            verificationSummary,
                        fallback:
                            "Configure an approved KRALİ repository."
                    ),
                intelligenceProvider: nil,
                finalResponse: reply
            )
            return true
        }

        developerRepository = repository

        if routing.phase == .research {
            currentGoal =
                "KRALİ self-development research"
            currentPlan =
                "Exact source revision → read-only repository evidence → research.web → compare → development proposal → stop"
            verificationState =
                .checking
            verificationSummary =
                "Read-only self-development research is collecting repository and web evidence. Mutation authority has not been granted."
            activeContextMemories = []
            contextMemoryStatus =
                "Self-development research context firewall aktif; önceki kullanıcı görevleri bu tura taşınmadı."

            busy = true

            log(
                "Self-development research başladı • repo=" +
                repository.path
            )

            Task {
                await executeSelfDevelopmentResearchMission(
                    text,
                    source: source,
                    repository: repository
                )
            }

            return true
        }

        currentGoal =
            "KRALİ self-development diagnosis"
        currentPlan =
            "Exact source revision → read-only repository evidence → root cause → alternatives → development proposal → stop"
        verificationState =
            .checking
        verificationSummary =
            "Read-only self-diagnosis is collecting source and historical evidence. Mutation authority has not been granted."
        activeContextMemories = []
        contextMemoryStatus =
            "Developer context firewall aktif; önceki kullanıcı görevleri bu tura taşınmadı."

        busy = true

        log(
            "Self-diagnosis başladı • repo=" +
            repository.path
        )

        Task {
            await executeSelfDiagnosisMission(
                text,
                source: source,
                repository: repository
            )
        }

        return true
    }

    private func executeSelfDevelopmentResearchMission(
        _ text: String,
        source: ChatInputSource,
        repository: AgentDeveloperRepository
    ) async {
        let appVersion =
            currentAppVersionString
        let appSourceRevision =
            currentAppSourceRevision
        let repositoryPath =
            repository.path

        let evidencePackage =
            await Task.detached(
                priority: .utility
            ) {
                AgentSelfDiagnosisExecutor()
                    .collect(
                        userInput: text,
                        repository:
                            AgentDeveloperRepository(
                                path:
                                    repositoryPath
                            ),
                        appVersion:
                            appVersion,
                        appSourceRevision:
                            appSourceRevision
                    )
            }
            .value

        guard
            evidencePackage
                .canDiagnoseCurrentSource
        else {
            let reply =
                "Self-development research durdu: çalışan uygulama ile repository source revision birebir eşleşmiyor. Mutation başlatılmadı."

            let verification =
                AgentVerificationResult(
                    state: .attention,
                    summary:
                        "Exact source identity is required before self-development research.",
                    fallback:
                        "Update KRALİ to the exact develop revision and retry."
                )

            verificationState =
                verification.state
            verificationSummary =
                verification.summary

            recordMentorTrace(
                input: text,
                source: source,
                goal: currentGoal,
                plan: currentPlan,
                route: activeRoute,
                capabilities: [],
                learningPlans: [],
                verification:
                    verification,
                intelligenceProvider: nil,
                finalResponse:
                    reply
            )

            postAssistantMessage(
                reply
            )
            busy = false
            return
        }

        let repositoryEvidence =
            evidencePackage.evidence.filter {
                $0.kind == "source"
            }

        let researchPlan =
            researchQueryPlanner
                .developmentPlan(text)

        guard
            !researchPlan.facets.isEmpty
        else {
            let reply =
                """
                Self-development research için anlamlı araştırma facet'i çıkarılamadı.

                Mutation Started: NO
                """

            let verification =
                AgentVerificationResult(
                    state: .attention,
                    summary:
                        "Mission-derived development research plan contains no usable facets.",
                    fallback:
                        "Clarify the external approaches/topics to compare; do not start mutation."
                )

            verificationState =
                verification.state
            verificationSummary =
                verification.summary

            recordMentorTrace(
                input: text,
                source: source,
                goal: currentGoal,
                plan: currentPlan,
                route: activeRoute,
                capabilities:
                    capabilityRegistry.resolve(
                        ids: [
                            "core.reasoning",
                            "context.local",
                            "research.web"
                        ],
                        profile:
                            executionProfile
                    ),
                learningPlans: [],
                verification:
                    verification,
                intelligenceProvider: nil,
                finalResponse:
                    reply
            )

            postAssistantMessage(reply)
            busy = false
            return
        }

        var sourceAssessments:
            [AgentDevelopmentResearchSourceAssessment] = []
        var evidenceCandidates: [
            (
                facetID: String,
                evidence: WebSourceEvidence,
                assessment:
                    AgentDevelopmentResearchSourceAssessment
            )
        ] = []

        var resultByURL:
            [String: WebResearchResult] = [:]
        var seenAssessmentKeys =
            Set<String>()
        var seenEvidenceKeys =
            Set<String>()
        var coveredFacets =
            Set<String>()

        researchLoop:
        for facet in
            researchPlan.facets.prefix(8) {
            var facetHasQualifyingEvidence =
                false

            for query in
                facet.queries.prefix(2) {
                _ =
                    await performWebResearch(
                        query: query,
                        allowInteractiveEscalation:
                            false,
                        allowSnippetEvidence:
                            false,
                        developmentFacet:
                            facet
                    )

                for result in
                    webResearchResults {
                    let assessment =
                        developmentResearchSourceClassifier
                            .assess(
                                result,
                                facet: facet
                            )

                    guard
                        assessment.tier != .d
                    else {
                        continue
                    }

                    let key =
                        facet.id +
                        "|" +
                        assessment.sourceURL

                    if seenAssessmentKeys
                        .insert(key)
                        .inserted {
                        sourceAssessments
                            .append(
                                assessment
                            )
                    }

                    resultByURL[
                        assessment.sourceURL
                    ] = result
                }

                for item in
                    webResearchEvidence {
                    let assessment =
                        developmentResearchSourceClassifier
                            .assess(
                                item.source,
                                facet: facet
                            )

                    guard
                        assessment.tier != .d
                    else {
                        continue
                    }

                    let sourceKey =
                        facet.id +
                        "|" +
                        assessment.sourceURL

                    if seenAssessmentKeys
                        .insert(sourceKey)
                        .inserted {
                        sourceAssessments
                            .append(
                                assessment
                            )
                    }

                    resultByURL[
                        assessment.sourceURL
                    ] =
                        item.source

                    let evidenceKey =
                        facet.id +
                        "|" +
                        assessment.sourceURL

                    if seenEvidenceKeys
                        .insert(evidenceKey)
                        .inserted {
                        evidenceCandidates
                            .append(
                                (
                                    facetID:
                                        facet.id,
                                    evidence:
                                        item,
                                    assessment:
                                        assessment
                                )
                            )
                    }

                    if assessment
                        .qualifiesForTechnicalCoverage {
                        facetHasQualifyingEvidence =
                            true
                    }
                }

                if facetHasQualifyingEvidence {
                    break
                }
            }

            if facetHasQualifyingEvidence {
                coveredFacets.insert(
                    facet.id
                )
            }

            let uniqueHighQuality =
                Dictionary(
                    sourceAssessments
                        .filter {
                            $0.qualifiesForTechnicalCoverage
                        }
                        .map {
                            ($0.sourceURL, $0)
                        },
                    uniquingKeysWith: {
                        left,
                        right in
                        left.qualityScore >=
                        right.qualityScore
                        ? left
                        : right
                    }
                )
                .values

            let origins =
                Set(
                    uniqueHighQuality
                        .map(\.origin)
                )

            if coveredFacets.count >=
                    researchPlan
                        .requiredApproachCount,
               uniqueHighQuality.count >=
                    researchPlan
                        .minimumHighQualitySourceCount,
               origins.count >=
                    researchPlan
                        .minimumIndependentOriginCount {
                break researchLoop
            }
        }

        sourceAssessments.sort {
            if $0.tier.rank ==
                $1.tier.rank {
                return $0.qualityScore >
                    $1.qualityScore
            }

            return $0.tier.rank >
                $1.tier.rank
        }

        evidenceCandidates.sort {
            if $0.assessment.tier.rank ==
                $1.assessment.tier.rank {
                return $0.assessment
                    .qualityScore >
                    $1.assessment
                    .qualityScore
            }

            return $0.assessment
                .tier.rank >
                $1.assessment
                .tier.rank
        }

        let evidenceRecords =
            Array(
                evidenceCandidates
                    .prefix(16)
            )
            .enumerated()
            .map {
                index,
                item in

                AgentDevelopmentResearchEvidenceRecord(
                    id:
                        "W" +
                        String(index + 1),
                    facetID:
                        item.facetID,
                    sourceURL:
                        item.assessment
                            .sourceURL,
                    sourceTitle:
                        item.assessment
                            .sourceTitle,
                    domain:
                        item.assessment
                            .domain,
                    kind:
                        item.assessment
                            .kind,
                    tier:
                        item.assessment
                            .tier,
                    excerpt:
                        String(
                            item.evidence
                                .excerpt
                                .prefix(800)
                        )
                )
            }

        let uniqueResultURLs =
            sourceAssessments
                .map(\.sourceURL)

        var resultSeen =
            Set<String>()
        webResearchResults =
            uniqueResultURLs
                .compactMap { url in
                    guard
                        resultSeen
                            .insert(url)
                            .inserted
                    else {
                        return nil
                    }

                    return resultByURL[url]
                }
                .prefix(12)
                .map { $0 }

        var mentorEvidenceSeen =
            Set<String>()
        webResearchEvidence =
            evidenceCandidates
                .compactMap { item in
                    let url =
                        item.evidence
                            .source
                            .url
                            .absoluteString
                    guard
                        mentorEvidenceSeen
                            .insert(url)
                            .inserted
                    else {
                        return nil
                    }
                    return item.evidence
                }
                .prefix(12)
                .map { $0 }

        let synthesis =
            await localIntelligence
                .synthesizeSelfDevelopmentResearch(
                    userInput: text,
                    plan:
                        researchPlan,
                    repositoryEvidence:
                        repositoryEvidence,
                    evidenceRecords:
                        evidenceRecords,
                    sourceAssessments:
                        sourceAssessments,
                    prohibitedCapabilityIDs:
                        evidencePackage
                            .prohibitedCapabilityIDs
                )

        let executedCapabilities:
            Set<String> = [
                "core.reasoning",
                "context.local",
                "research.web"
            ]

        let qualityVerification =
            developmentResearchVerifier
                .verify(
                    plan:
                        researchPlan,
                    sources:
                        sourceAssessments,
                    evidence:
                        evidenceRecords,
                    repositoryEvidenceIDs:
                        Set(
                            repositoryEvidence
                                .map(\.id)
                        ),
                    synthesis:
                        synthesis,
                    executedCapabilityIDs:
                        executedCapabilities
                )

        let verification:
            AgentVerificationResult

        switch qualityVerification.state {
        case .passed:
            verification =
                AgentVerificationResult(
                    state: .passed,
                    summary:
                        qualityVerification
                            .summary,
                    fallback:
                        qualityVerification
                            .fallback
                )

        case .partial:
            verification =
                AgentVerificationResult(
                    state: .partial,
                    summary:
                        qualityVerification
                            .summary,
                    fallback:
                        qualityVerification
                            .fallback
                )

        case .attention:
            verification =
                AgentVerificationResult(
                    state: .attention,
                    summary:
                        qualityVerification
                            .summary,
                    fallback:
                        qualityVerification
                            .fallback
                )
        }

        verificationState =
            verification.state
        verificationSummary =
            verification.summary

        let capabilities =
            capabilityRegistry.resolve(
                ids: [
                    "core.reasoning",
                    "context.local",
                    "research.web"
                ],
                profile:
                    executionProfile
            )

        let fallbackReport =
            """
            A. Current KRALİ Architecture
            Read-only repository evidence collected from \(repositoryEvidence.count) current-source snippets.

            B. Research Sources
            \(sourceAssessments.prefix(12).map { "[Tier \($0.tier.rawValue)] \($0.sourceTitle) — \($0.domain)" }.joined(separator: "\n"))

            F. Biggest Current Gap
            Structured, evidence-ID-bound comparison could not be completed to the mission-derived verification contract.

            K. Verification Plan
            \(qualityVerification.summary)

            L. Mutation Recommended
            Mutation Recommended: NO

            M. Mutation Started
            Mutation Started: NO

            N. Recommended Next Step
            \(qualityVerification.fallback ?? "Collect stronger Tier A/B page-derived evidence for uncovered facets.")
            """

        let reply =
            synthesis?
                .formattedFinalReport(
                    sources:
                        sourceAssessments
                ) ??
            fallbackReport

        currentReflectionSummary =
            "Development research • facets=" +
            String(
                researchPlan.facets.count
            ) +
            " • requiredApproaches=" +
            String(
                researchPlan
                    .requiredApproachCount
            ) +
            " • pageEvidence=" +
            String(
                evidenceRecords.count
            ) +
            " • verification=" +
            verification.state.rawValue

        currentAlternatives =
            synthesis?
                .approaches
                .map {
                    $0.decision.rawValue +
                    ": " +
                    $0.title
                } ??
            []

        intelligenceProviderStatus =
            synthesis == nil
            ? "Structured self-development research synthesis unavailable"
            : "Apple Foundation Models / Evidence-Bound Development Research"

        activeRoute = [
            "Core",
            "Developer",
            "Research Plan",
            "Source Quality",
            "Page Evidence",
            "Repository",
            "Compare",
            "Research Verify",
            "Proposal",
            "Stop"
        ]

        recordMentorTrace(
            input: text,
            source: source,
            goal: currentGoal,
            plan: currentPlan,
            route: activeRoute,
            capabilities:
                capabilities,
            learningPlans: [],
            verification:
                verification,
            intelligenceProvider:
                synthesis == nil
                ? nil
                : "Apple Foundation Models / Evidence-Bound Development Research",
            finalResponse:
                reply
        )

        postAssistantMessage(
            reply
        )

        log(
            "Self-development research tamamlandı • facets=" +
            String(
                researchPlan.facets.count
            ) +
            " • sources=" +
            String(
                sourceAssessments.count
            ) +
            " • pageEvidence=" +
            String(
                evidenceRecords.count
            ) +
            " • verification=" +
            verification.state.rawValue +
            " • mutation=no"
        )

        busy = false
    }

    private func executeSelfDiagnosisMission(
        _ text: String,
        source: ChatInputSource,
        repository: AgentDeveloperRepository
    ) async {
        let appVersion =
            currentAppVersionString
        let appSourceRevision =
            currentAppSourceRevision

        let repositoryPath =
            repository.path

        let evidencePackage =
            await Task.detached(
                priority: .utility
            ) {
                AgentSelfDiagnosisExecutor()
                    .collect(
                        userInput: text,
                        repository:
                            AgentDeveloperRepository(
                                path:
                                    repositoryPath
                            ),
                        appVersion:
                            appVersion,
                        appSourceRevision:
                            appSourceRevision
                    )
            }
            .value

        let modelOutput:
            AgentSelfDiagnosisModelOutput?
        let reasoningFailure:
            String?

        if evidencePackage
            .canDiagnoseCurrentSource {
            modelOutput =
                await localIntelligence
                    .diagnoseSelfDevelopment(
                        userInput: text,
                        evidencePackage:
                            evidencePackage
                    )

            reasoningFailure =
                modelOutput == nil
                ? await localIntelligence
                    .selfDiagnosisFailureReason()
                : nil
        } else {
            modelOutput = nil
            reasoningFailure =
                "Source identity is not exact; reasoning was not started."
        }

        let report =
            selfDiagnosisExecutor
                .assembleReport(
                    package:
                        evidencePackage,
                    modelOutput:
                        modelOutput,
                    reasoningFailure:
                        reasoningFailure
                )

        currentSelfDiagnosisReport =
            report
        currentReflectionSummary =
            report.architecturalRootCause
        currentAlternatives =
            report.alternatives
                .map(\.title)

        let verification:
            AgentVerificationResult

        if report.evidenceBound {
            verification =
                AgentVerificationResult(
                    state: .passed,
                    summary:
                        "Read-only self-diagnosis produced an evidence-bound root cause. No mutation was started.",
                    fallback:
                        "A bounded registered task and explicit human review are still required before code changes."
                )
        } else {
            verification =
                AgentVerificationResult(
                    state: .attention,
                    summary:
                        "Self-diagnosis stopped without an evidence-bound root cause.",
                    fallback:
                        report.stopReason
                )
        }

        verificationState =
            verification.state
        verificationSummary =
            verification.summary

        let reasoningCapabilities =
            capabilityRegistry.resolve(
                ids: [
                    "core.reasoning",
                    "context.local"
                ],
                profile:
                    executionProfile
            )

        let provider =
            modelOutput == nil
            ? nil
            : "Apple Foundation Models / Guided Self Diagnosis"

        intelligenceProviderStatus =
            provider ??
            (
                reasoningFailure?.isEmpty == false
                ? "Self-diagnosis reasoning failed: " +
                    reasoningFailure!
                : "Self-diagnosis reasoning provider unavailable"
            )

        let reply =
            report.formattedFinalReport()

        recordMentorTrace(
            input: text,
            source: source,
            goal: currentGoal,
            plan: currentPlan,
            route: activeRoute,
            capabilities:
                reasoningCapabilities,
            learningPlans: [],
            verification:
                verification,
            intelligenceProvider:
                provider,
            finalResponse:
                reply
        )

        postAssistantMessage(reply)

        log(
            report.evidenceBound
            ? "Self-diagnosis tamamlandı • evidence-bound root cause"
            : "Self-diagnosis durdu • evidence binding başarısız"
        )

        busy = false
    }

    func send(
        _ raw: String,
        source: ChatInputSource = .text
    ) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let taskStartedAt = Date()
        guard !busy else {
            log("Yeni görev alınmadı: KRALİ mevcut görevi tamamlıyor")
            return
        }

        if source == .text {
            speech.stopSpeaking()
        }

        resetTransientTaskStateForNewInput()
        currentTaskInput = text
        missionDeveloperRunID = nil

        let preliminaryRouting =
            missionRouter.classify(text)
        let isolateDeveloperContext =
            developerContextFirewall
                .shouldIsolate(
                    routing:
                        preliminaryRouting
                )

        let recalledContextMemories:
            [AgentContextMemoryEntry]
        let executionContextMemories:
            [AgentContextMemoryEntry]

        if isolateDeveloperContext {
            recalledContextMemories = []
            executionContextMemories = []
            activeContextMemories = []
            contextMemoryStatus =
                "Developer context firewall aktif; önceki kullanıcı görevleri bu tura taşınmadı."
            log(
                "Developer context firewall: conversational task memory isolated"
            )
        } else {
            recalledContextMemories =
                contextMemoryStore.relevant(
                    to: text,
                    from: contextMemoryEntries,
                    limit: 4
                )

            executionContextMemories =
                contextMemoryStore
                    .executionContext(
                        to: text,
                        from:
                            recalledContextMemories,
                        limit: 4
                    )

            // Only execution-safe context is allowed to influence routing,
            // planning and verification. Broader recall may still exist in
            // the persistent store but must not poison an unrelated task.
            activeContextMemories =
                executionContextMemories

            if !executionContextMemories
                .isEmpty {
                contextMemoryStatus =
                    "\(executionContextMemories.count) güvenli bağlam kaydı bu tura taşındı."
                log(
                    "Bağlam hafızası: " +
                    executionContextMemories
                        .map(\.title)
                        .joined(
                            separator: " • "
                        )
                )
            } else if
                !recalledContextMemories
                    .isEmpty {
                contextMemoryStatus =
                    "Önceki görev bağlamları bulundu ancak yeni hedef bağımsız olduğu için izole edildi."
                log(
                    "Bağlam firewall: önceki görev bağlamları bu tura taşınmadı"
                )
            } else {
                contextMemoryStatus =
                    "Bu tur için ilgili önceki bağlam bulunmadı."
            }
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text: text
            )
        )

        if handleDeveloperTaskChatCommand(
            text
        ) {
            return
        }

        if handleSelfDevelopmentMission(
            text,
            source: source
        ) {
            return
        }

        let decision = brain.analyze(
            text,
            context: brainContext()
        )

        let interpretedGoalProfile =
            goalInterpreter.interpret(
                text,
                decision: decision,
                context: brainContext()
            )

        let goalProfile =
            researchCoreGoalProfile(
                interpretedGoalProfile
            )

        let requestedActionCapabilityIDs =
            goalProfile.requiredCapabilityIDs
                .subtracting(
                    Set([
                        "core.reasoning",
                        "context.local"
                    ])
                )
        let pausedRequestedCapabilityIDs =
            requestedActionCapabilityIDs
                .filter {
                    executionProfile.isPaused($0)
                }
                .sorted()
        let runnableRequestedCapabilityIDs =
            requestedActionCapabilityIDs
                .filter {
                    !executionProfile.isPaused($0)
                }

        // An explicitly computer-control-only goal must not be converted into
        // a fake capability gap or an unsafe workaround while the profile is
        // intentionally paused. Mixed goals (for example public research plus
        // an optional browser path) continue with the non-paused capability
        // surface so research can proceed without the computer-control node.
        if !pausedRequestedCapabilityIDs.isEmpty &&
           runnableRequestedCapabilityIDs.isEmpty {
            currentGoal = goalProfile.summary
            currentPlan =
                "Development / Research Mode → paused capability"
            currentTaskGraph = nil
            currentRuntimeTask = nil
            selectedCapabilities = []
            capabilityLearningPlans = []
            currentCapabilityGaps = []
            executionSteps = []
            verificationState = .attention
            verificationSummary =
                "İstenen bilgisayar-kontrol capability'si Development / Research Mode'da geçici olarak duraklatıldı."
            fallbackPlan = nil
            activeRoute = [
                "Core",
                "ExecutionProfile",
                "Paused"
            ]

            let reply =
                "Bu işlem Development / Research Mode açıkken geçici olarak duraklatıldı. " +
                "Bilgisayar kontrolü uygulanmadı ve bu durum yeni bir capability eksikliği olarak öğrenme kuyruğuna eklenmedi. " +
                "Duraklatılan capability: " +
                pausedRequestedCapabilityIDs.joined(separator: ", ")

            postAssistantMessage(reply)
            recordMentorTrace(
                input: text,
                source: source,
                goal: currentGoal,
                plan: currentPlan,
                route: activeRoute,
                capabilities: [],
                learningPlans: [],
                verification:
                    AgentVerificationResult(
                        state: .attention,
                        summary: verificationSummary,
                        fallback:
                            "Bilgisayar kontrolünü yeniden etkinleştiren bir execution profile seçilene kadar bu eylem uygulanmaz."
                    ),
                intelligenceProvider: nil,
                finalResponse: reply
            )
            return
        }

        currentGoal = goalProfile.summary
        currentPlan = decision.selectedPlan
        currentAlternatives = decision.alternatives
        lastDecision = decision

        let capabilities = capabilityRegistry.select(
            for: text,
            decision: decision,
            context: brainContext(),
            goal: goalProfile,
            profile: executionProfile
        )
        selectedCapabilities = capabilities

        let webResearchAvailable =
            capabilityRegistry.availableCapabilities(for: executionProfile).first(
                where: { $0.id == "research.web" }
            )?.isAvailable == true

        var learningPlans =
            capabilityLearner.makePlans(
                for: capabilities,
                webResearchAvailable:
                    webResearchAvailable
            )

        var executionPlan = planner.makePlan(
            decision: decision,
            context: brainContext(),
            capabilities: capabilities,
            learningPlans: [],
            goal: goalProfile
        )

        var deterministicGraph =
            deterministicProblemGraph(
                goal: goalProfile,
                plan: executionPlan
            )

        let problemSolvableBlockedIDs =
            Set(
                deterministicGraph.steps
                    .filter {
                        !$0.isAvailable
                    }
                    .filter { step in
                        !problemSolver
                            .candidateCapabilityIDs(
                                for: step,
                                availableCapabilities:
                                    runtimeCapabilities()
                            )
                            .isEmpty
                    }
                    .map(\.capabilityID)
            )

        if !problemSolvableBlockedIDs
            .isEmpty {
            learningPlans =
                learningPlans.filter {
                    !problemSolvableBlockedIDs
                        .contains(
                            $0.capabilityID
                        )
                }

            log(
                "Problem Solver Learning'i erteledi: mevcut strateji bulunan capability=" +
                problemSolvableBlockedIDs
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        capabilityLearningPlans =
            learningPlans

        capabilityLearningBacklog =
            learningStore.merge(
                existing:
                    capabilityLearningBacklog,
                plans: learningPlans,
                capabilities: capabilities
            )

        executionPlan = planner.makePlan(
            decision: decision,
            context: brainContext(),
            capabilities: capabilities,
            learningPlans: learningPlans,
            goal: goalProfile
        )

        deterministicGraph =
            deterministicProblemGraph(
                goal: goalProfile,
                plan: executionPlan
            )

        currentTaskGraph =
            deterministicGraph
        currentRuntimeTask =
            taskRuntimePlanner.makeTask(
                graph:
                    deterministicGraph
            )

        let deterministicResolution =
            problemSolver.solve(
                graph: deterministicGraph,
                capabilities:
                    runtimeCapabilities(),
                observations:
                    problemSolverObservations()
            )

        currentProblemResolution =
            deterministicResolution
        currentReflectionSummary =
            deterministicResolution.reflection

        if let chosen =
            deterministicResolution
                .chosenStrategy {
            log(
                "Problem Solver başlangıç stratejisi: " +
                chosen.title +
                " • " +
                chosen.rationale
            )
        }

        activeRoute = routeBuilder.build(
            goal: goalProfile,
            capabilities: capabilities,
            learningPlans: learningPlans,
            requiresVerification: executionPlan.requiresVerification
        )

        executionSteps = executionPlan.steps
        prepareExecutionSteps()
        verificationState = .idle
        verificationSummary = "Uygulama adımı tamamlanınca kontrol edilecek."
        fallbackPlan = executionPlan.fallback
        recoverySummary = nil

        if !goalProfile.outcomes.contains(.research) {
            webResearchResults = []
            webResearchEvidence = []
            webResearchStatus = "Bu görevde web araştırması istenmedi."
        }

        log("KRALİ Core hedef sözleşmesi: \(goalProfile.summary)")
        log("Seçilen plan: \(decision.selectedPlan)")
        log("Otomatik rota: \(activeRoute.joined(separator: " → "))")
        log(
            "Seçilen kabiliyetler: " +
            capabilities
                .map { $0.name + ($0.isAvailable ? "" : " [bekliyor]") }
                .joined(separator: ", ")
        )

        if !learningPlans.isEmpty {
            log(
                "Yetkinlik öğrenme planı: " +
                learningPlans
                    .map { $0.capabilityName + " → " + $0.state.title }
                    .joined(separator: ", ")
            )
        }

        busy = true

        Task {
            await executeTaskPipeline(
                text: text,
                source: source,
                taskStartedAt: taskStartedAt,
                decision: decision,
                goalProfile: goalProfile,
                capabilities: capabilities,
                learningPlans: learningPlans,
                executionPlan: executionPlan,
                executionContextMemories:
                    executionContextMemories,
                webResearchAvailable:
                    webResearchAvailable
            )
        }
    }

    private func executeTaskPipeline(
        text: String,
        source: ChatInputSource,
        taskStartedAt: Date,
        decision: AgentDecision,
        goalProfile: AgentGoalProfile,
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        executionPlan: AgentExecutionPlan,
        executionContextMemories:
            [AgentContextMemoryEntry],
        webResearchAvailable: Bool
    ) async {
        var resolvedGoal = goalProfile
        var resolvedCapabilities = capabilities
        var resolvedLearningPlans = learningPlans
        var resolvedExecutionPlan = executionPlan
        var semanticMission: AgentSemanticMission?
        var executedSemanticCapabilities = Set<String>()
        var completedSemanticStepIndexes = Set<Int>()

        if shouldUseSemanticMission(
            decision: decision,
            goal: resolvedGoal
        ) {
            var plannedMission: AgentSemanticMission?
            var plannerProvider: String?

            if let localMission =
                await localIntelligence.planMission(
                    userInput: text,
                    contextMemory: executionContextMemories,
                    capabilities: runtimeCapabilities(),
                    hasWorkspace: selectedRootURL != nil
                ),
               localMission.normalizedConfidence >= 0.45,
               semanticMissionCoverageIsValid(
                    localMission,
                    fallbackGoal: goalProfile
               ) {
                plannedMission = localMission
                plannerProvider =
                    localMission.steps.contains(
                        where: {
                            $0.operation ==
                                "semantic.fallback"
                        }
                    )
                        ? "Local Contract Repair"
                        : (
                            localMission.steps.contains(
                                where: {
                                    $0.operation ==
                                        "capability.contract"
                                }
                            )
                                ? "Apple + Contract Repair"
                                : "Apple Foundation Models"
                        )
            } else if let subscriptionMission =
                await subscriptionIntelligence.planMission(
                    userInput: text,
                    contextMemory: executionContextMemories,
                    capabilities: runtimeCapabilities(),
                    hasWorkspace: selectedRootURL != nil
                ),
                subscriptionMission.mission
                    .normalizedConfidence >= 0.45,
                semanticMissionCoverageIsValid(
                    subscriptionMission.mission,
                    fallbackGoal: goalProfile
                ) {
                plannedMission =
                    subscriptionMission.mission
                plannerProvider =
                    subscriptionMission.provider
            }

            if plannedMission == nil {
                let actionableCapabilities =
                    goalProfile
                        .requiredCapabilityIDs
                        .subtracting(
                            Set([
                                "core.reasoning",
                                "context.local"
                            ])
                        )

                if !actionableCapabilities.isEmpty {
                    plannedMission =
                        AgentSemanticMission(
                            objective: text,
                            outcomes:
                                goalProfile
                                    .outcomes
                                    .map(\.rawValue)
                                    .sorted(),
                            steps: [],
                            requiredCapabilityIDs:
                                Array(
                                    goalProfile
                                        .requiredCapabilityIDs
                                )
                                .sorted(),
                            requiresUserInput: false,
                            userInputReason: nil,
                            confidence: 0.6
                        )
                    plannerProvider =
                        "Deterministic Capability Contract"

                    log(
                        "Semantic planner fallback: goal contract'tan deterministic mission üretildi"
                    )
                }
            }

            if let rawMission = plannedMission {
                let mission =
                    missionNormalizer.normalize(
                        rawMission,
                        userInput: text,
                        capabilities:
                            runtimeCapabilities()
                    )

                semanticMission = mission
                currentSemanticMission = mission
                currentSemanticPlannerProvider =
                    plannerProvider

                resolvedGoal = semanticGoalProfile(
                    from: mission,
                    fallback: goalProfile
                )
            resolvedCapabilities = semanticCapabilities(
                from: mission,
                fallback: capabilities
            )

            let compiledTaskGraph =
                taskOrchestrator.compile(
                    mission: mission,
                    capabilities:
                        runtimeCapabilities()
                )

            currentTaskGraph =
                compiledTaskGraph
            currentRuntimeTask =
                taskRuntimePlanner.makeTask(
                    graph:
                        compiledTaskGraph
                )

            let problemResolution =
                problemSolver.solve(
                    graph: compiledTaskGraph,
                    capabilities:
                        runtimeCapabilities(),
                    observations:
                        problemSolverObservations()
                )

            currentProblemResolution =
                problemResolution
            currentReflectionSummary =
                problemResolution.reflection

            let outcomeContract =
                outcomePlanner.makeContract(
                    userInput: text,
                    goal: resolvedGoal,
                    mission: mission,
                    profile: executionProfile
                )
            let outcomeResolution =
                outcomePlanner.resolve(
                    contract: outcomeContract,
                    capabilities:
                        runtimeCapabilities()
                )
            currentOutcomeResolution =
                outcomeResolution

            let outcomeSuppressedLearningIDs =
                outcomeResolution
                    .suppressedLearningCapabilityIDs

            if outcomeResolution.isFullyCovered {
                log(
                    "Outcome Solver: başarı kriterleri mevcut capability'lerle kapsandı • " +
                    outcomeResolution
                        .chosenStrategies
                        .map(\.title)
                        .joined(separator: " | ")
                )
            }

            let problemSolvableBlockedIDs =
                Set(
                    compiledTaskGraph.steps
                        .filter {
                            !$0.isAvailable
                        }
                        .filter { step in
                            !problemSolver
                                .candidateCapabilityIDs(
                                    for: step,
                                    availableCapabilities:
                                        runtimeCapabilities()
                                )
                                .isEmpty
                        }
                        .map(\.capabilityID)
                )

            resolvedLearningPlans =
                capabilityLearner.makePlans(
                    for: resolvedCapabilities,
                    webResearchAvailable:
                        webResearchAvailable
                )
                .filter {
                    !problemSolvableBlockedIDs
                        .contains(
                            $0.capabilityID
                        ) &&
                    !outcomeSuppressedLearningIDs
                        .contains(
                            $0.capabilityID
                        )
                }

            let deferredLearningIDs =
                problemSolvableBlockedIDs
                    .union(
                        outcomeSuppressedLearningIDs
                    )

            if !deferredLearningIDs.isEmpty {
                log(
                    "Problem Solver semantic Learning'i erteledi: " +
                    deferredLearningIDs
                        .sorted()
                        .joined(separator: ", ")
                )
            }

            resolvedExecutionPlan = semanticExecutionPlan(
                mission,
                capabilities:
                    resolvedCapabilities,
                goal: resolvedGoal
            )

            currentCapabilityGaps =
                capabilityGapResolver.resolve(
                    graph:
                        compiledTaskGraph,
                    capabilities:
                        runtimeCapabilities()
                )
                .filter {
                    !outcomeSuppressedLearningIDs
                        .contains(
                            $0.capabilityID
                        )
                }

            let blocked =
                compiledTaskGraph
                    .blockedCapabilityIDs
            let approvals =
                compiledTaskGraph
                    .approvalStepIndexes

            taskGraphStatus =
                String(
                    compiledTaskGraph.steps.count
                ) +
                " adım" +
                (blocked.isEmpty
                    ? ""
                    : " • blocked: " +
                        blocked.joined(
                            separator: ", "
                        )) +
                (approvals.isEmpty
                    ? ""
                    : " • onay: " +
                        approvals
                            .map(String.init)
                            .joined(
                                separator: ", "
                            ))

            currentGoal = resolvedGoal.summary
            currentPlan = mission.steps
                .map(\.title)
                .joined(separator: " → ")
            selectedCapabilities = resolvedCapabilities
            capabilityLearningPlans = resolvedLearningPlans
            capabilityLearningBacklog = learningStore.merge(
                existing: capabilityLearningBacklog,
                plans: resolvedLearningPlans,
                capabilities: resolvedCapabilities
            )
            executionSteps = resolvedExecutionPlan.steps
            activeRoute = routeBuilder.build(
                goal: resolvedGoal,
                capabilities: resolvedCapabilities,
                learningPlans: resolvedLearningPlans,
                requiresVerification: resolvedExecutionPlan.requiresVerification
            )
            fallbackPlan = resolvedExecutionPlan.fallback
            prepareExecutionSteps()

            log("Semantic Mission: \(mission.objective)")
            log(
                "Semantic planner sağlayıcısı: " +
                (plannerProvider ?? "Bilinmiyor")
            )
            log(
                "Semantic capability planı: " +
                mission.requiredCapabilityIDs.joined(separator: ", ")
            )
            if let chosen =
                problemResolution.chosenStrategy {
                log(
                    "Problem Solver seçimi: " +
                    chosen.title +
                    " • score=" +
                    String(chosen.score) +
                    " • capabilities=" +
                    chosen.capabilityIDs
                        .joined(separator: ",")
                )
            }

            let executableStrategies =
                problemResolution.strategies
                    .filter {
                        $0.executableNow &&
                        !$0.requiresLearning
                    }

            if !executableStrategies.isEmpty {
                log(
                    "Problem Solver adayları: " +
                    executableStrategies
                        .prefix(5)
                        .map {
                            $0.title +
                            "[" +
                            String($0.score) +
                            "]"
                        }
                        .joined(separator: " | ")
                )
            }

            log(
                "Task Graph: " +
                compiledTaskGraph.steps
                    .map {
                        String($0.index) +
                        ":" +
                        $0.capabilityID +
                        "[" +
                        $0.role.rawValue +
                        "]"
                    }
                    .joined(separator: " → ")
            )
            if !blocked.isEmpty {
                log(
                    "Task Graph blocked capability: " +
                    blocked.joined(
                        separator: ", "
                    )
                )
            }
            for gap in currentCapabilityGaps {
                log(
                    "Capability Gap: " +
                    gap.capabilityID +
                    " • " +
                    gap.kind.rawValue +
                    " • strategy=" +
                    (
                        gap.candidateCapabilityIDs
                            .isEmpty
                            ? "yok"
                            : gap.candidateCapabilityIDs
                                .joined(
                                    separator: ","
                                )
                    )
                )
            }
            if !approvals.isEmpty {
                log(
                    "Task Graph kullanıcı onayı bekleyen step: " +
                    approvals
                        .map(String.init)
                        .joined(separator: ", ")
                )
            }
            log(
                "Semantic rota: " +
                activeRoute.joined(separator: " → ")
            )
            } else {
                let plannerFailure =
                    await subscriptionIntelligence
                        .lastFailureReason()

                if let plannerFailure,
                   !plannerFailure.isEmpty {
                    log(
                        "Semantic planner geçerli mission üretemedi: " +
                        plannerFailure
                    )
                } else {
                    log(
                        "Semantic planner geçerli mission üretemedi; deterministic fallback korunuyor"
                    )
                }
            }
        }

        var baseReply = ""
        var outcomeOwnedMission = false

        if let outcomeResolution =
            currentOutcomeResolution,
           outcomeResolution.isFullyCovered,
           !outcomeResolution
                .contract
                .requiresMutation,
           outcomeChainCanOwnExecution(
                outcomeResolution
           ) {
            outcomeOwnedMission = true

            let chainResult =
                await executeOutcomeStrategyChain(
                    resolution:
                        outcomeResolution,
                    userInput: text
                )

            currentOutcomeAttempts =
                chainResult.attempts
            executedSemanticCapabilities
                .formUnion(
                    chainResult
                        .executedCapabilityIDs
                )

            for capabilityID in
                chainResult
                    .executedCapabilityIDs {
                if !selectedCapabilities.contains(
                    where: {
                        $0.id ==
                            capabilityID
                    }
                ),
                   let capability =
                    capabilityRegistry
                        .all
                        .first(
                            where: {
                                $0.id ==
                                    capabilityID
                            }
                        ) {
                    selectedCapabilities
                        .append(
                            capability
                        )
                }
            }

            if chainResult.succeeded {
                baseReply =
                    chainResult.reply
            } else {
                let attemptSummaries =
                    chainResult
                        .attempts
                        .map {
                            $0.strategyID +
                            ": " +
                            $0.summary
                        }

                let transientFailure =
                    capabilityGapResolver
                        .isTransientOutcomeFailure(
                            attemptSummaries:
                                attemptSummaries
                        )

                let browserGap =
                    capabilityGapResolver
                        .resolveExhaustedOutcomeCapability(
                            capabilityID:
                                "browser.control",
                            objective:
                                text,
                            attemptSummaries:
                                attemptSummaries,
                            capabilities:
                                capabilityRegistry
                                    .all
                        )

                if transientFailure {
                    currentOutcomeFailureIsTransient = true

                    capabilityLearningPlans
                        .removeAll {
                            $0.capabilityID ==
                                "browser.control"
                        }
                    resolvedLearningPlans =
                        capabilityLearningPlans

                    currentCapabilityGaps
                        .removeAll {
                            $0.capabilityID ==
                                "browser.control"
                        }

                    capabilityLearningBacklog =
                        learningStore.update(
                            existing:
                                capabilityLearningBacklog,
                            capabilityID:
                                "browser.control",
                            progress:
                                .interrupted,
                            nextStep:
                                "Gözlem sırasında foreground değişti. Bu geçici kullanıcı/uygulama müdahalesidir; yeni capability öğrenmesi başlatılmadı."
                        )

                    baseReply =
                        chainResult.reply
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? "Web hedefini açmayı denedim ancak gözlem sırasında foreground değiştiği için sonucu doğrulayamadım. Bu geçici bir gözlem kesintisi; yeni bir capability öğrenmesi başlatılmadı."
                        : chainResult.reply

                    currentReflectionSummary =
                        "Outcome gözlemi kullanıcı/uygulama foreground değişimiyle kesildi; transient failure capability gap olarak sınıflandırılmadı."

                    log(
                        "Outcome gözlemi kesildi; Learning Gateway açılmadı"
                    )
                } else {
                    queueInteractiveAccessCapability()
                    resolvedLearningPlans =
                        capabilityLearningPlans

                    if let browserGap,
                       !currentCapabilityGaps
                        .contains(
                            where: {
                                $0.capabilityID ==
                                    browserGap
                                        .capabilityID
                            }
                        ) {
                        currentCapabilityGaps
                            .append(
                                browserGap
                            )
                    }

                    baseReply =
                        chainResult.reply
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? "Mevcut outcome stratejilerini denedim ancak başarı kriterini doğrulayamadım. Gerçek capability eksikliği Learning Gateway'e aktarıldı."
                        : chainResult.reply

                    currentReflectionSummary =
                        "Outcome Strategy Chain mevcut güvenli stratejileri tüketti; gerçek capability eksikliği kaldığı için Learning Gateway açıldı."

                    log(
                        "Outcome Strategy Chain tükendi; Learning Gateway açıldı"
                    )
                }
            }
        }

        if !outcomeOwnedMission,
           let mission = semanticMission {
            let result = await executeAvailableSemanticMission(
                mission,
                userInput: text
            )
            baseReply = result.reply
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
                ? semanticMissionStatusReply(mission)
                : result.reply
            executedSemanticCapabilities =
                result.executedCapabilityIDs
            completedSemanticStepIndexes =
                result.completedStepIndexes

            if let graph =
                currentTaskGraph {
                let runtimeGaps =
                    capabilityGapResolver
                        .resolveRuntimeFailures(
                            graph: graph,
                            completedStepIndexes:
                                result
                                    .completedStepIndexes,
                            approvedStepIndexes:
                                approvedRuntimeStepIndexes,
                            capabilities:
                                runtimeCapabilities()
                        )

                let suppressedRuntimeIDs =
                    currentOutcomeResolution?
                        .suppressedLearningCapabilityIDs ??
                    []

                for gap in runtimeGaps
                    where !suppressedRuntimeIDs
                        .contains(
                            gap.capabilityID
                        ) &&
                    !currentCapabilityGaps
                        .contains(
                            where: {
                                $0.capabilityID ==
                                    gap.capabilityID
                            }
                        ) {
                    currentCapabilityGaps
                        .append(gap)

                    log(
                        "Runtime Capability Gap: " +
                        gap.capabilityID +
                        " • " +
                        gap.reason
                    )
                }
            }
        } else if !outcomeOwnedMission,
                  resolvedGoal.outcomes.contains(.research),
                  resolvedCapabilities.contains(where: {
                      $0.id == "research.web" && $0.isAvailable
                  }) {
            baseReply = await performWebResearch(
                query: webResearchQuery(from: text)
            )
        } else if !outcomeOwnedMission {
            baseReply = makeReply(
                for: text,
                decision: decision
            )
        }

        if let learningSummary = await researchCapabilityGapIfNeeded(
            plans: resolvedLearningPlans,
            userInput: text
        ) {
            baseReply += "\n\nÖğrenme araştırması: " + learningSummary
        }

        if semanticMission != nil {
            completeSemanticActionSteps(
                executedCapabilityIDs:
                    executedSemanticCapabilities,
                completedMissionStepIndexes:
                    completedSemanticStepIndexes,
                substitutedCapabilityIDs:
                    outcomeOwnedMission
                    ? (
                        currentOutcomeResolution?
                            .suppressedLearningCapabilityIDs ??
                        []
                    )
                    : []
            )
        } else {
            completeActionSteps()
        }

        let verification: AgentVerificationResult
        if resolvedExecutionPlan.requiresVerification {
            if currentRuntimeTask?.state !=
                .waitingForApproval {
                currentRuntimeTask?.state =
                    .verifying
            }

            setVerificationStep(.running)
            verificationState = .checking
            verificationSummary = "Sonuç kontrol ediliyor…"

            verification = verifier.verify(
                decision: decision,
                currentUserInput: text,
                goal: resolvedGoal,
                semanticMission: semanticMission,
                outcomeResolution:
                    currentOutcomeResolution,
                outcomeAttempts:
                    currentOutcomeAttempts,
                snapshot: verificationSnapshot(
                    executedCapabilityIDs:
                        executedSemanticCapabilities
                )
            )

            verificationState = verification.state
            verificationSummary = verification.summary

            if verification.state == .attention {
                setVerificationStep(.attention)
                fallbackPlan =
                    currentOutcomeFailureIsTransient
                    ? nil
                    : (
                        verification.fallback ??
                        resolvedExecutionPlan.fallback
                    )
            } else if verification.state == .partial {
                setVerificationStep(.partial)
                fallbackPlan = nil
            } else {
                setVerificationStep(.completed)
                // A passed/skipped verification has no recovery action.
                // Do not leak the execution plan's generic fallback into a
                // successfully verified negative observation.
                fallbackPlan = nil
            }
        } else {
            setVerificationStep(.skipped)
            verification = AgentVerificationResult(
                state: .skipped,
                summary: "Bu turda doğrulanacak gerçek araç işlemi yok.",
                fallback: nil
            )
            verificationState = .skipped
            verificationSummary = verification.summary
        }

        var finalBaseReply = baseReply
        var finalVerification = verification

        if let pending =
            pendingTaskApproval {
            finalVerification =
                AgentVerificationResult(
                    state: .partial,
                    summary:
                        "Görev güvenli biçimde duraklatıldı. Dış işlem uygulanmadı; kullanıcı onayı bekleniyor: " +
                        pending.title,
                    fallback: nil
                )
            verificationState =
                .partial
            verificationSummary =
                finalVerification.summary
            fallbackPlan = nil
            setVerificationStep(.partial)
        }

        if pendingTaskApproval == nil,
           verification.state == .attention,
           let recovery = attemptSafeRecovery(
                for: text,
                decision: decision,
                goal: resolvedGoal
           ) {
            finalBaseReply = "İlk plan sonuç vermedi. Güvenli Plan B'yi otomatik denedim.\n\n" + recovery.reply
            finalVerification = recovery.verification
            verificationState = recovery.verification.state
            verificationSummary = recovery.verification.summary
            recoverySummary = recovery.summary

            if recovery.verification.state == .passed {
                setVerificationStep(.completed)
                fallbackPlan = nil
                log("Plan B başarılı: \(recovery.summary)")
            } else if recovery.verification.state == .partial {
                setVerificationStep(.partial)
                fallbackPlan = nil
                log("Plan B kısmi sonuç verdi: \(recovery.summary)")
            } else {
                setVerificationStep(.attention)
                fallbackPlan = recovery.verification.fallback ?? fallbackPlan
                log("Plan B de hedefi doğrulayamadı")
            }
        }

        var intelligenceProvider: String?
        var synthesisApplied = false

        if pendingTaskApproval == nil &&
           shouldUseIntelligence(
            goal: resolvedGoal,
            verification: finalVerification
        ) {
            if let synthesized = await localIntelligence.synthesize(
                userInput: text,
                goal: resolvedGoal.summary,
                draft: finalBaseReply,
                verification: finalVerification,
                capabilities: selectedCapabilities,
                researchEvidence: webResearchEvidence,
                contextMemory: executionContextMemories
            ) {
                if synthesisOutputMeetsGoal(
                    userInput: text,
                    goal: resolvedGoal,
                    output: synthesized
                ) {
                    finalBaseReply = synthesized
                    synthesisApplied = true
                    intelligenceProvider = "Apple Foundation Models"
                    intelligenceProviderStatus =
                        "Apple yerel zeka sentezi kullanıldı."
                    log("Yerel zeka sentezi uygulandı")
                } else {
                    log(
                        "Yerel zeka çıktısı hedef biçimine uymadı; Subscription fallback denenecek"
                    )
                }
            }

            if !synthesisApplied,
               let subscription = await subscriptionIntelligence.synthesize(
                    userInput: text,
                    goal: resolvedGoal.summary,
                    draft: finalBaseReply,
                    verification: finalVerification,
                    capabilities: selectedCapabilities,
                    researchEvidence: webResearchEvidence,
                    contextMemory: executionContextMemories
               ) {
                if synthesisOutputMeetsGoal(
                    userInput: text,
                    goal: resolvedGoal,
                    output: subscription.text
                ) {
                    finalBaseReply = subscription.text
                    synthesisApplied = true
                    intelligenceProvider = subscription.provider
                    intelligenceProviderStatus =
                        "ChatGPT Subscription sentezi kullanıldı."
                    log(
                        "ChatGPT Subscription sentezi uygulandı"
                    )
                } else {
                    intelligenceProviderStatus =
                        "Sentez üretildi ancak hedef biçimine uymadı."
                    log(intelligenceProviderStatus)
                }
            }

            if !synthesisApplied {
                let reason = await subscriptionIntelligence
                    .lastFailureReason()

                if intelligenceProviderStatus ==
                    "Sentez sağlayıcısı henüz kullanılmadı." ||
                   intelligenceProviderStatus ==
                    "Apple yerel zeka hazır" {
                    intelligenceProviderStatus =
                        reason.map {
                            "ChatGPT Subscription sentezi kullanılamadı: " + $0
                        } ?? "Analiz/dönüşüm sentezi sağlayıcısı kullanılamadı."
                }

                log(intelligenceProviderStatus)
            }

            completeSynthesisSteps(
                success: synthesisApplied
            )

            finalVerification = enforceGoalCompletion(
                goal: resolvedGoal,
                verification: finalVerification,
                synthesisApplied: synthesisApplied
            )

            verificationState = finalVerification.state
            verificationSummary = finalVerification.summary

            switch finalVerification.state {
            case .passed:
                setVerificationStep(.completed)
            case .partial:
                setVerificationStep(.partial)
            case .attention:
                setVerificationStep(.attention)
            case .skipped:
                setVerificationStep(.skipped)
            case .idle, .checking:
                break
            }

            if synthesisApplied &&
               !activeRoute.contains("Intelligence") {
                if let verifyIndex = activeRoute.firstIndex(
                    of: "Verify"
                ) {
                    activeRoute.insert(
                        "Intelligence",
                        at: verifyIndex
                    )
                } else if let responseIndex = activeRoute.firstIndex(
                    of: "Response"
                ) {
                    activeRoute.insert(
                        "Intelligence",
                        at: responseIndex
                    )
                } else {
                    activeRoute.append("Intelligence")
                }
            }
        }

        if finalVerification.state == .attention &&
           currentCapabilityGaps.isEmpty &&
           !currentOutcomeFailureIsTransient &&
           currentRuntimeTask?.state !=
                .waitingForApproval &&
           inspectorState.debugIncident == nil &&
           lastFileSearchOutcome == nil {
            registerDebugIncident(
                source: "verifier",
                message: finalVerification.summary,
                evidence: finalVerification.fallback,
                progress: .investigating
            )
        }

        if currentRuntimeTask?.state !=
            .waitingForApproval {
            switch finalVerification.state {
            case .passed, .skipped:
                currentRuntimeTask?.state =
                    .completed
            case .partial, .attention:
                currentRuntimeTask?.state =
                    .failed
            case .idle, .checking:
                break
            }
        }

        if pendingTaskApproval == nil {
            promoteVerifiedSkills(
                executedCapabilityIDs:
                    executedSemanticCapabilities
                        .union(
                            runtimeExecutedCapabilityIDs
                        ),
                verification:
                    finalVerification
            )
        }

        let replyWithSuggestion = appendSuggestion(
            to: finalBaseReply,
            suggestion: decision.proactiveSuggestion
        )

        let reply = responseComposer.compose(
            baseReply: replyWithSuggestion,
            verification: finalVerification,
            goal: resolvedGoal,
            capabilities: selectedCapabilities,
            learningPlans: capabilityLearningPlans,
            capabilityGaps: currentCapabilityGaps,
            fallbackPlan: fallbackPlan
        )

        recordMentorTrace(
            input: text,
            source: source,
            goal: resolvedGoal.summary,
            plan: semanticMission.map {
                $0.steps.map(\.title).joined(separator: " → ")
            } ?? decision.selectedPlan,
            route: activeRoute,
            capabilities: selectedCapabilities,
            learningPlans: capabilityLearningPlans,
            verification: finalVerification,
            intelligenceProvider: intelligenceProvider,
            finalResponse: reply
        )

        let shouldPersistTaskContext =
            finalVerification.state == .passed &&
            (
                synthesisApplied ||
                !webResearchEvidence.isEmpty ||
                decision.intent != .general
            )

        if shouldPersistTaskContext,
           let memoryEntry = contextMemoryStore.captureTask(
                userInput: text,
                goal: resolvedGoal.summary,
                response: reply,
                researchEvidence: webResearchEvidence
           ) {
            contextMemoryEntries = contextMemoryStore.append(
                memoryEntry,
                to: contextMemoryEntries
            )
            contextMemoryStore.save(contextMemoryEntries)
            contextMemoryStatus =
                "\(contextMemoryEntries.count) bağlam kaydı hazır."
        }

        appendConversationMessage(
            ChatMessage(
                role: .assistant,
                text: reply
            )
        )

        let elapsed =
            Date().timeIntervalSince(
                taskStartedAt
            )
        log(
            String(
                format:
                    "Görev tamamlandı • %.2f sn",
                elapsed
            )
        )

        busy = false

        if source == .voice && voiceOutputEnabled {
            speech.speak(reply)
        }

        if pendingTaskApproval == nil &&
           !currentCapabilityGaps.isEmpty {
            inspectorState.learningQueueJobs =
                learningQueueStore.enqueue(
                    gaps:
                        currentCapabilityGaps,
                    sourceGoal: text,
                    into:
                        inspectorState.learningQueueJobs
                )

            let queuedCount =
                inspectorState.learningQueueJobs.filter {
                    $0.state == .queued
                }.count

            log(
                "Capability gap Learning Queue'ya alındı • sırada=" +
                String(queuedCount)
            )
        }

        startNextLearningJobIfNeeded()
    }

    private func promoteVerifiedSkills(
        executedCapabilityIDs:
            Set<String>,
        verification:
            AgentVerificationResult
    ) {
        guard
            verification.state == .passed
        else {
            return
        }

        let appVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        let foundational =
            Set([
                "core.reasoning",
                "context.local"
            ])

        let blocked =
            Set(
                currentCapabilityGaps
                    .map(\.capabilityID)
            )

        let promotable =
            executedCapabilityIDs
                .subtracting(
                    foundational
                )
                .subtracting(
                    blocked
                )

        for capabilityID in
            promotable.sorted() {
            if let skillName =
                skillLibraryStore
                    .promoteLatestExperimentalSkill(
                        capabilityID:
                            capabilityID,
                        appVersion:
                            appVersion,
                        verificationSummary:
                            verification.summary
                    ) {
                log(
                    "Skill promoted • " +
                    capabilityID +
                    " • " +
                    skillName
                )
            }
        }
    }

    private struct SemanticMissionExecutionResult {
        let reply: String
        let executedCapabilityIDs: Set<String>
        let completedStepIndexes: Set<Int>
    }

    private func shouldUseSemanticMission(
        decision: AgentDecision,
        goal: AgentGoalProfile
    ) -> Bool {
        switch decision.intent {
        case .approve, .reject, .undo, .remember,
             .conversation, .openPreviousResult:
            return false

        case .general, .futureCapability:
            return true

        default:
            return goal.isCompound ||
                goal.outcomes.contains(.edit)
        }
    }

    private func researchCoreGoalProfile(
        _ goal: AgentGoalProfile
    ) -> AgentGoalProfile {
        guard
            executionProfile ==
                .developmentResearchMode,
            goal.outcomes.contains(.research) ||
            goal.requiredCapabilityIDs.contains(
                "research.web"
            )
        else {
            return goal
        }

        var capabilityIDs =
            goal.requiredCapabilityIDs
                .subtracting(
                    executionProfile
                        .pausedCapabilityIDs
                )

        capabilityIDs.insert(
            "core.reasoning"
        )
        capabilityIDs.insert(
            "context.local"
        )

        return AgentGoalProfile(
            summary: goal.summary,
            outcomes: goal.outcomes,
            requiredCapabilityIDs:
                capabilityIDs,
            isCompound:
                goal.isCompound
        )
    }

    private func semanticMissionCoverageIsValid(
        _ mission: AgentSemanticMission,
        fallbackGoal: AgentGoalProfile
    ) -> Bool {
        let ids = Set(
            mission.requiredCapabilityIDs +
            mission.steps.map(\.capabilityID)
        )
        let outcomes = Set(
            mission.outcomes.compactMap {
                AgentGoalOutcome(rawValue: $0)
            }
        )

        let foundationalCapabilityIDs =
            Set([
                "core.reasoning",
                "context.local"
            ])

        let deterministicToolCapabilityIDs =
            fallbackGoal
                .requiredCapabilityIDs
                .subtracting(
                    foundationalCapabilityIDs
                )

        let semanticToolCapabilityIDs =
            ids.subtracting(
                foundationalCapabilityIDs
            )

        // A reasoning-only user request must stay reasoning-only.
        // The semantic model may enrich the reasoning shape, but it must not
        // invent file, screen, app, web, edit or other tool execution when
        // the deterministic intent layer did not establish any tool need.
        if deterministicToolCapabilityIDs.isEmpty,
           !semanticToolCapabilityIDs.isEmpty {
            return false
        }

        let toolGroundedOutcomes =
            Set<AgentGoalOutcome>([
                .locate,
                .assessContent,
                .research,
                .edit,
                .organize,
                .open,
                .remember,
                .communicate
            ])

        let introducedToolOutcomes =
            outcomes
                .intersection(
                    toolGroundedOutcomes
                )
                .subtracting(
                    fallbackGoal.outcomes
                )

        guard introducedToolOutcomes.isEmpty else {
            return false
        }

        if fallbackGoal.outcomes.contains(.edit) {
            guard outcomes.contains(.edit) else {
                return false
            }
        }

        if outcomes.contains(.locate) ||
           outcomes.contains(.shortlist) {
            guard ids.contains("files.search") ||
                  ids.contains("browser.control") else {
                return false
            }
        }

        if outcomes.contains(.assessContent) {
            guard ids.contains("perception.media") ||
                  ids.contains("perception.screen") else {
                return false
            }
        }

        if outcomes.contains(.research) {
            let researchCovered =
                ids.contains("research.web") ||
                (
                    executionProfile
                        .allowsComputerControl &&
                    ids.contains("browser.control")
                )

            guard researchCovered else {
                return false
            }
        }

        if outcomes.contains(.edit) {
            let providers = Set([
                "premiere.control",
                "photoshop.control",
                "desktop.control",
                "files.move.reversible"
            ])

            guard !ids.intersection(providers).isEmpty else {
                return false
            }
        }

        if outcomes.contains(.communicate) {
            guard ids.contains("mail.work") ||
                  ids.contains("browser.control") else {
                return false
            }
        }

        return true
    }

    private func semanticGoalProfile(
        from mission: AgentSemanticMission,
        fallback: AgentGoalProfile
    ) -> AgentGoalProfile {
        let parsedOutcomes = Set(
            mission.outcomes.compactMap {
                AgentGoalOutcome(rawValue: $0)
            }
        )

        let outcomes = parsedOutcomes.isEmpty
            ? fallback.outcomes
            : parsedOutcomes

        var capabilityIDs = Set(
            mission.requiredCapabilityIDs +
            mission.steps.map(\.capabilityID)
        )
        capabilityIDs.insert("core.reasoning")
        capabilityIDs.insert("context.local")

        return AgentGoalProfile(
            summary: mission.objective,
            outcomes: outcomes,
            requiredCapabilityIDs: capabilityIDs,
            isCompound:
                mission.steps.count > 2 ||
                capabilityIDs
                    .subtracting(
                        Set([
                            "core.reasoning",
                            "context.local"
                        ])
                    )
                    .count > 1
        )
    }

    private func semanticCapabilities(
        from mission: AgentSemanticMission,
        fallback: [AgentCapability]
    ) -> [AgentCapability] {
        var ids = [
            "core.reasoning",
            "context.local"
        ]
        ids += mission.requiredCapabilityIDs
        ids += mission.steps.map(\.capabilityID)

        let resolved = capabilityRegistry.resolve(
            ids: ids,
            profile: executionProfile
        )

        return resolved.isEmpty ? fallback : resolved
    }

    private func semanticExecutionPlan(
        _ mission: AgentSemanticMission,
        capabilities: [AgentCapability],
        goal: AgentGoalProfile
    ) -> AgentExecutionPlan {
        var steps: [AgentExecutionStep] = []

        for (index, missionStep) in mission.steps.enumerated() {
            let kind: AgentExecutionStepKind =
                missionStep.capabilityID == "core.reasoning" ||
                missionStep.capabilityID == "context.local"
                    ? .reasoning
                    : .action

            let dependencyText: String
            if missionStep.dependsOn.isEmpty {
                dependencyText = ""
            } else {
                let dependencies = missionStep.dependsOn
                    .filter { $0 >= 0 && $0 < index }
                    .map { String($0 + 1) }
                    .joined(separator: ", ")

                dependencyText = dependencies.isEmpty
                    ? ""
                    : " Ön koşul adımları: " + dependencies + "."
            }

            steps.append(
                AgentExecutionStep(
                    title: missionStep.title,
                    detail:
                        missionStep.purpose +
                        dependencyText +
                        " Operation: " +
                        missionStep.operation,
                    kind: kind,
                    capabilityID: missionStep.capabilityID
                )
            )
        }

        let actionIDs = Set(
            mission.steps
                .map(\.capabilityID)
                .filter {
                    $0 != "core.reasoning" &&
                    $0 != "context.local"
                }
        )

        let requiresVerification =
            !actionIDs.isEmpty ||
            mission.requiresUserInput ||
            capabilities.contains(where: {
                !$0.isAvailable
            })

        if requiresVerification {
            steps.append(
                AgentExecutionStep(
                    title: "Mission sonucunu doğrula",
                    detail: "Gerçekleşen adımları hedefle, capability durumuyla ve üretilen sonuçla karşılaştır.",
                    kind: .verification,
                    capabilityID: "core.reasoning"
                )
            )
        }

        steps.append(
            AgentExecutionStep(
                title: "Sonucu kullanıcıya aktar",
                detail: "Tamamlanan, bekleyen ve kullanıcı bilgisi gerektiren kısımları birbirinden ayır.",
                kind: .response
            )
        )

        return AgentExecutionPlan(
            goal: goal.summary,
            steps: steps,
            fallback: mission.requiresUserInput
                ? mission.userInputReason
                : "Eksik capability veya başarısız adımı yeniden planla; tamamlanmayan işi yapılmış gibi gösterme.",
            requiresVerification: requiresVerification
        )
    }

    private func executeAvailableSemanticMission(
        _ mission: AgentSemanticMission,
        userInput: String
    ) async -> SemanticMissionExecutionResult {
        if mission.requiresUserInput {
            return SemanticMissionExecutionResult(
                reply:
                    mission.userInputReason ??
                    "Bu görevi güvenilir biçimde ilerletmek için zorunlu bir bilgi eksik.",
                executedCapabilityIDs: [
                    "core.reasoning",
                    "context.local"
                ],
                completedStepIndexes: []
            )
        }

        let taskGraph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    runtimeCapabilities()
            )

        if currentRuntimeTask?.objective ==
            mission.objective {
            currentRuntimeTask?.state =
                .running
        }

        var outputs: [String] = []
        var stepEvidence =
            runtimeStepEvidence
        var executed =
            runtimeExecutedCapabilityIDs
        var completedStepIndexes =
            currentRuntimeTask?
                .completedStepIndexes ??
            []
        var didFileSearch =
            lastFileSearchOutcome != nil &&
            executed.contains(
                "files.search"
            )

        for (stepIndex, step) in mission.steps.enumerated() {
            if completedStepIndexes.contains(
                stepIndex
            ) {
                continue
            }
            let dependenciesSatisfied =
                step.dependsOn.allSatisfy {
                    completedStepIndexes.contains($0)
                }

            guard dependenciesSatisfied else {
                continue
            }

            guard
                taskGraph.steps.indices.contains(
                    stepIndex
                )
            else {
                continue
            }

            let graphStep =
                taskGraph.steps[stepIndex]

            let dependencyEvidence =
                taskOrchestrator
                    .dependencyEvidence(
                        for: graphStep,
                        evidence: stepEvidence
                    )

            let primaryCapabilityAvailable =
                selectedCapabilities.first(
                    where: {
                        $0.id ==
                            step.capabilityID
                    }
                )?.isAvailable == true

            if !primaryCapabilityAvailable {
                if let fallback =
                    await executeProblemSolverFallback(
                        graphStep: graphStep,
                        missionStep: step,
                        mission: mission,
                        dependencyEvidence:
                            dependencyEvidence,
                        userInput: userInput,
                        attemptedStrategyIDs: []
                    ) {
                    stepEvidence[stepIndex] =
                        fallback.evidence
                    outputs.append(
                        fallback.output
                    )
                    executed.formUnion(
                        fallback.executedCapabilityIDs
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                    currentReflectionSummary =
                        fallback.reflection

                    log(
                        "Problem Solver fallback tamamlandı: " +
                        fallback.strategyTitle
                    )
                }

                continue
            }

            if graphStep.requiresApproval &&
               !approvedRuntimeStepIndexes
                    .contains(
                        stepIndex
                    ) {
                let reason =
                    graphStep.approvalReason ??
                    "Bu adım kullanıcı cihazı veya dış dünya üzerinde bir işlem yapacak."

                var targetSummary: String?
                var targetName: String?
                var targetBundleIdentifier:
                    String?
                var targetPath: String?

                if graphStep.capabilityID ==
                    "desktop.app" {
                    if let target =
                        await desktopControl
                            .applicationApprovalTarget(
                                from: userInput
                            ) {
                        targetSummary =
                            target.summary
                        targetName =
                            target.name
                        targetBundleIdentifier =
                            target.bundleIdentifier
                        targetPath =
                            target.path
                    }
                } else if
                    graphStep.capabilityID ==
                        "system.open.url" ||
                    graphStep.capabilityID ==
                        "browser.control"
                {
                    targetSummary =
                        naturalLanguageResolver
                            .webURL(
                                from: userInput
                            )?
                            .absoluteString
                } else if
                    graphStep.capabilityID ==
                        "files.write.text" ||
                    graphStep.capabilityID ==
                        "files.move.reversible" ||
                    graphStep.capabilityID ==
                        "files.reveal"
                {
                    targetSummary =
                        selectedRootURL?
                            .path
                }

                if !taskOrchestrator
                    .approvalTargetIsResolved(
                        capabilityID:
                            graphStep.capabilityID,
                        targetSummary:
                            targetSummary,
                        targetName:
                            targetName,
                        targetPath:
                            targetPath
                    ) {
                    let unresolvedTarget =
                        naturalLanguageResolver
                            .applicationTargetDisplayPhrase(
                                from: userInput
                            ) ??
                        targetSummary ??
                        userInput

                    let failureMessage =
                        "Hedefi güvenilir biçimde çözemedim: " +
                        unresolvedTarget +
                        ". Hiçbir dış işlem yapılmadı ve onay kartı oluşturulmadı."

                    outputs.append(
                        failureMessage
                    )
                    stepEvidence[
                        stepIndex
                    ] =
                        failureMessage
                    currentRuntimeTask?
                        .state =
                        .failed

                    log(
                        "Strict Approval preflight blokladı: çözümlenmemiş hedef • capability=" +
                        graphStep.capabilityID +
                        " • target=" +
                        unresolvedTarget
                    )
                    break
                }

                let approvalMessage =
                    "Onay bekleniyor: " +
                    step.title +
                    (targetSummary.map {
                        "\nHedef: " + $0
                    } ?? "") +
                    "\nNeden: " +
                    reason

                currentTaskApprovalAudit =
                    TaskApprovalAudit(
                        stepIndex:
                            stepIndex,
                        title:
                            step.title,
                        capabilityID:
                            step.capabilityID,
                        targetSummary:
                            targetSummary,
                        targetName:
                            targetName,
                        targetBundleIdentifier:
                            targetBundleIdentifier,
                        targetPath:
                            targetPath,
                        decision:
                            "pending",
                        recordedAt:
                            Date()
                    )

                if let taskID =
                    currentRuntimeTask?.id {
                    pendingTaskApproval =
                        PendingTaskApproval(
                            taskID: taskID,
                            stepIndex:
                                stepIndex,
                            title:
                                step.title,
                            reason:
                                reason,
                            capabilityID:
                                step.capabilityID,
                            operation:
                                step.operation,
                            targetSummary:
                                targetSummary,
                            targetName:
                                targetName,
                            targetBundleIdentifier:
                                targetBundleIdentifier,
                            targetPath:
                                targetPath
                        )
                }

                currentRuntimeTask?.state =
                    .waitingForApproval
                currentRuntimeTask?
                    .waitingResourceIDs =
                    taskRuntimePlanner
                        .requiredResources(
                            for: graphStep
                        )

                runtimeStepEvidence =
                    stepEvidence
                runtimeExecutedCapabilityIDs =
                    executed
                currentRuntimeTask?
                    .completedStepIndexes =
                    completedStepIndexes

                outputs.append(
                    approvalMessage
                )
                log(
                    "Task Graph approval gate: " +
                    String(stepIndex) +
                    " • " +
                    step.capabilityID +
                    " • " +
                    reason
                )
                break
            }

            switch step.capabilityID {
            case "context.local":
                let contextSummary =
                    activeContextMemories
                        .map {
                            $0.title +
                            ": " +
                            $0.summary
                        }
                        .joined(separator: "\n")

                stepEvidence[stepIndex] =
                    contextSummary.isEmpty
                        ? "Bu görev için ek kalıcı bağlam yok."
                        : contextSummary

                executed.insert(
                    "context.local"
                )
                completedStepIndexes.insert(
                    stepIndex
                )

            case "core.reasoning":
                let operation =
                    normalizeSemanticText(
                        step.operation
                    )

                let isContractStep =
                    operation.contains(
                        "semantic.fallback"
                    ) ||
                    operation.contains(
                        "capability.contract"
                    )

                if isContractStep ||
                   dependencyEvidence
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    stepEvidence[stepIndex] =
                        mission.objective
                    executed.insert(
                        "core.reasoning"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                } else if let reasoningOutput =
                    await localIntelligence
                        .executeReasoningStep(
                            goal:
                                mission.objective,
                            title:
                                step.title,
                            purpose:
                                step.purpose,
                            operation:
                                step.operation,
                            dependencyEvidence:
                                dependencyEvidence
                        ) {
                    stepEvidence[stepIndex] =
                        reasoningOutput
                    executed.insert(
                        "core.reasoning"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )

                    if graphStep.role ==
                        .transform {
                        outputs.append(
                            reasoningOutput
                        )
                    }
                }

            case "research.web":
                let composedQuery =
                    [
                        mission.objective,
                        step.purpose,
                        dependencyEvidence
                    ]
                    .filter {
                        !$0.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ).isEmpty
                    }
                    .joined(separator: "\n")

                let query =
                    webResearchQuery(
                        from:
                            String(
                                composedQuery
                                    .prefix(4_000)
                            )
                    )

                let researchReply =
                    await performWebResearch(
                        query: query
                    )

                outputs.append(
                    researchReply
                )
                stepEvidence[stepIndex] =
                    researchReply
                executed.insert(
                    "research.web"
                )
                completedStepIndexes.insert(
                    stepIndex
                )

            case "files.search":
                let searchDecision =
                    semanticFileSearchDecision(
                        mission: mission,
                        userInput: userInput
                    )

                let fileQuery =
                    fileQueryParser.parse(
                        userInput
                    )

                var searchReply: String
                if searchDecision.target ==
                    .folder {
                    searchReply =
                        searchIndexedFolders(
                            for: userInput,
                            decision:
                                searchDecision
                        )
                } else {
                    searchReply =
                        searchIndexedFiles(
                            for: userInput,
                            decision:
                                searchDecision
                        )

                    if fileQuery.outputProjection ==
                        .namesOnly,
                       !fileSearchResults
                        .isEmpty {
                        searchReply =
                            fileSearchResults
                                .map {
                                    "• " + $0.name
                                }
                                .joined(
                                    separator: "\n"
                                )
                    }
                }

                outputs.append(
                    searchReply
                )
                stepEvidence[stepIndex] =
                    searchReply

                if lastFileSearchOutcome?
                    .rootPath != nil ||
                   (
                    searchDecision.target ==
                        .folder &&
                    selectedRootURL != nil
                   ) {
                    executed.insert(
                        "files.search"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                    didFileSearch = true
                }

            case "files.metadata":
                if didFileSearch &&
                   executed.contains(
                        "files.search"
                   ) {
                    let metadataEvidence =
                        dependencyEvidence
                            .isEmpty
                            ? "Dosya araması tamamlandı."
                            : dependencyEvidence

                    stepEvidence[stepIndex] =
                        metadataEvidence
                    executed.insert(
                        "files.metadata"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                }

            case "files.write.text":
                guard
                    folderSearchResults.count == 1,
                    let targetFolder =
                        folderSearchResults.first?.url
                else {
                    outputs.append(
                        folderSearchResults.isEmpty
                            ? "Metin dosyası yazılamadı: hedef klasör bulunamadı."
                            : "Metin dosyası yazılamadı: hedef klasör belirsiz; birden fazla eşleşme var."
                    )
                    continue
                }

                let contentDependencies =
                    step.dependsOn.compactMap {
                        dependencyIndex -> String? in

                        guard
                            mission.steps.indices
                                .contains(
                                    dependencyIndex
                                )
                        else {
                            return nil
                        }

                        let dependencyStep =
                            mission.steps[
                                dependencyIndex
                            ]

                        if dependencyStep.capabilityID ==
                            "files.search" ||
                           dependencyStep.capabilityID ==
                            "context.local" ||
                           dependencyStep.capabilityID ==
                            "desktop.app" {
                            return nil
                        }

                        return stepEvidence[
                            dependencyIndex
                        ]
                    }
                    .filter {
                        !$0.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ).isEmpty
                    }

                let textContent =
                    contentDependencies
                        .joined(
                            separator: "\n\n"
                        )

                do {
                    let result =
                        try await textFileWriter.write(
                            content:
                                textContent,
                            to:
                                targetFolder,
                            workspaceRoot:
                                selectedRootURL,
                            preferredStem:
                                step.title
                        )

                    let evidence =
                        "Metin dosyası yazıldı: " +
                        result.url.path +
                        " • " +
                        String(
                            result.byteCount
                        ) +
                        " byte"

                    stepEvidence[stepIndex] =
                        evidence
                    outputs.append(
                        evidence
                    )
                    executed.insert(
                        "files.write.text"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                } catch {
                    outputs.append(
                        "Metin dosyası yazılamadı: " +
                        error.localizedDescription
                    )
                    log(
                        "Text File Writer başarısız: " +
                        error.localizedDescription
                    )
                }

            case "desktop.app":
                guard let approvedTarget =
                    approvedRuntimeApplicationTargets[
                        stepIndex
                    ]
                else {
                    outputs.append(
                        "Strict Approval Mode: onaylanmış uygulama hedefi bulunmadığı için hiçbir uygulama açılmadı."
                    )
                    log(
                        "Strict Approval blokladı: desktop.app için sabitlenmiş onay hedefi yok • step=" +
                        String(stepIndex)
                    )
                    continue
                }

                approvedRuntimeApplicationTargets
                    .removeValue(
                        forKey: stepIndex
                    )

                do {
                    let result =
                        try await desktopControl
                            .openOrFocusApprovedApplication(
                                approvedTarget,
                                requestedText:
                                    userInput
                            )

                    let verified =
                        result.frontmostVerified

                    inspectorState.desktopControlStatus =
                        result
                            .resolvedApplicationName +
                        (
                            verified
                                ? " önde doğrulandı • " +
                                  result.verificationSource
                                : (
                                    result.launchOrActivateSucceeded
                                        ? " aktivasyon istendi fakat ön plan doğrulanamadı"
                                        : " aktivasyon başarısız ve ön plan doğrulanamadı"
                                  )
                        )

                    desktopControlStore
                        .saveStatus(
                            "runtime|app=" +
                            result
                                .resolvedApplicationName +
                            "|activate=" +
                            String(
                                result
                                    .launchOrActivateSucceeded
                            ) +
                            "|workspace=" +
                            String(
                                result
                                    .workspaceFrontmostVerified
                            ) +
                            "|axRecovery=" +
                            String(
                                result
                                    .accessibilityRecoveryAttempted
                            ) +
                            "|screenKit=" +
                            String(
                                result
                                    .screenKitFrontmostVerified
                            ) +
                            "|screenPerception=" +
                            String(
                                result
                                    .screenPerceptionFrontmostVerified
                            ) +
                            "|frontmost=" +
                            String(
                                result
                                    .frontmostVerified
                            ) +
                            "|source=" +
                            result
                                .verificationSource
                        )

                    let appEvidence =
                        result
                            .resolvedApplicationName +
                        " • activate=" +
                        String(
                            result
                                .launchOrActivateSucceeded
                        ) +
                        " • workspace=" +
                        String(
                            result
                                .workspaceFrontmostVerified
                        ) +
                        " • axRecovery=" +
                        String(
                            result
                                .accessibilityRecoveryAttempted
                        ) +
                        " • screenKit=" +
                        String(
                            result
                                .screenKitFrontmostVerified
                        ) +
                        " • screenPerception=" +
                        String(
                            result
                                .screenPerceptionFrontmostVerified
                        ) +
                        " • foreground=" +
                        String(
                            result
                                .frontmostVerified
                        ) +
                        " • source=" +
                        result
                            .verificationSource

                    stepEvidence[stepIndex] =
                        appEvidence

                    log(
                        "Desktop runtime: " +
                        appEvidence
                    )

                    if verified {
                        outputs.append(
                            result
                                .resolvedApplicationName +
                            " uygulamasını açtım ve görünür biçimde öne geldiğini doğruladım."
                        )
                        executed.insert(
                            "desktop.app"
                        )
                        completedStepIndexes
                            .insert(
                                stepIndex
                            )
                    } else {
                        let debugMessage =
                            result.resolvedApplicationName +
                            " uygulaması için foreground postcondition doğrulanamadı."

                        registerDebugIncident(
                            source: "desktop.app",
                            message: debugMessage,
                            evidence: appEvidence,
                            progress: .investigating
                        )

                        outputs.append(
                            result
                                .resolvedApplicationName +
                            " uygulamasını açmayı/öne getirmeyi denedim ancak görünür biçimde öne geldiğini doğrulayamadım."
                        )
                    }
                } catch {
                    inspectorState.desktopControlStatus =
                        "Uygulama kontrolü başarısız: " +
                        error.localizedDescription
                    desktopControlStore
                        .saveStatus(
                            "runtime_failed|" +
                            error.localizedDescription
                        )
                    registerDebugIncident(
                        source: "desktop.app",
                        message: inspectorState.desktopControlStatus,
                        evidence: error.localizedDescription,
                        progress: .investigating
                    )
                    log(
                        inspectorState.desktopControlStatus
                    )
                }

            case "perception.screen":
                do {
                    let goal =
                        [
                            mission.objective,
                            "Aktif step: " +
                                step.title,
                            step.purpose,
                            dependencyEvidence
                        ]
                        .filter {
                            !$0.trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ).isEmpty
                        }
                        .joined(separator: "\n")

                    let report =
                        try await screenPerception
                            .observe(
                                goal:
                                    String(
                                        goal
                                            .prefix(
                                                8_000
                                            )
                                    )
                            )

                    inspectorState.screenPerceptionReport =
                        report
                    try? screenPerceptionStore
                        .save(report)
                    screenPerceptionStore
                        .saveStatus(
                            "success|" +
                            String(
                                report
                                    .recognizedText
                                    .count
                            ) +
                            " metin satırı|" +
                            String(
                                report
                                    .visibleWindows
                                    .count
                            ) +
                            " pencere|runtime"
                        )

                    inspectorState.screenPerceptionStatus =
                        String(
                            report
                                .recognizedText
                                .count
                        ) +
                        " metin satırı • " +
                        String(
                            report
                                .visibleWindows
                                .count
                        ) +
                        " pencere • runtime gözlemi başarılı"

                    let perceptionEvidence =
                        report
                            .semanticSummary

                    stepEvidence[stepIndex] =
                        perceptionEvidence
                    outputs.append(
                        "Ekran gözlemi:\n" +
                        perceptionEvidence
                    )

                    executed.insert(
                        "perception.screen"
                    )
                    completedStepIndexes.insert(
                        stepIndex
                    )
                } catch {
                    screenPerceptionStore
                        .saveStatus(
                            "failed|" +
                            error
                                .localizedDescription +
                            "|runtime"
                        )
                    inspectorState.screenPerceptionStatus =
                        "Screen Perception başarısız: " +
                        error.localizedDescription
                    log(
                        inspectorState.screenPerceptionStatus
                    )
                }

            case "app.workflow":
                do {
                    let result = try await appWorkflowStrategy.execute(
                        objective: mission.objective,
                        stepTitle: step.title,
                        stepPurpose: step.purpose,
                        dependencyEvidence: dependencyEvidence
                    )

                    let evidence = [
                        "Öndeki uygulama: " +
                            result.frontmostApplication,
                        result.observationEvidence,
                        "Hazırlık çıktısı:\n" +
                            result.workflowOutput,
                        "Dış değişiklik uygulandı: hayır"
                    ]
                    .joined(separator: "\n\n")

                    stepEvidence[stepIndex] = evidence
                    outputs.append(result.workflowOutput)
                    executed.insert("app.workflow")
                    completedStepIndexes.insert(stepIndex)
                    log(
                        "App workflow strategy tamamlandı • frontmost=" +
                            result.frontmostApplication +
                            " • commit=false"
                    )
                } catch {
                    let message =
                        "Uygulama içi iş akışı doğrulanamadı: " +
                        error.localizedDescription
                    outputs.append(message)
                    registerDebugIncident(
                        source: "app.workflow",
                        message: message,
                        evidence: dependencyEvidence,
                        progress: .investigating
                    )
                    log(message)
                }

            default:
                break
            }

            if !completedStepIndexes.contains(
                stepIndex
            ),
               !graphStep.requiresApproval,
               let fallback =
                await executeProblemSolverFallback(
                    graphStep: graphStep,
                    missionStep: step,
                    mission: mission,
                    dependencyEvidence:
                        dependencyEvidence,
                    userInput: userInput,
                    attemptedStrategyIDs: [
                        "primary:" +
                        step.capabilityID
                    ]
                ) {
                stepEvidence[stepIndex] =
                    fallback.evidence
                outputs.append(
                    fallback.output
                )
                executed.formUnion(
                    fallback.executedCapabilityIDs
                )
                completedStepIndexes.insert(
                    stepIndex
                )
                currentReflectionSummary =
                    fallback.reflection

                log(
                    "Problem Solver reflection recovery tamamlandı: " +
                    fallback.strategyTitle
                )
            }

            runtimeStepEvidence =
                stepEvidence
            runtimeExecutedCapabilityIDs =
                executed
            currentRuntimeTask?
                .completedStepIndexes =
                completedStepIndexes
        }

        if didFileSearch,
           mission.requiredCapabilityIDs
            .contains(
                "files.metadata"
            ) {
            executed.insert(
                "files.metadata"
            )
        }

        runtimeStepEvidence =
            stepEvidence
        runtimeExecutedCapabilityIDs =
            executed
        currentRuntimeTask?
            .completedStepIndexes =
            completedStepIndexes

        return SemanticMissionExecutionResult(
            reply:
                outputs.joined(
                    separator: "\n\n"
                ),
            executedCapabilityIDs:
                executed,
            completedStepIndexes:
                completedStepIndexes
        )
    }

    func approvePendingTaskApproval() {
        guard
            !busy,
            let approval =
                pendingTaskApproval,
            let mission =
                currentSemanticMission,
            let decision =
                lastDecision,
            approval.taskID ==
                currentRuntimeTask?.id
        else {
            return
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text:
                    "Onaylıyorum: " +
                    approval.title
            )
        )

        approvedRuntimeStepIndexes
            .insert(
                approval.stepIndex
            )

        if
            approval.capabilityID ==
                "desktop.app",
            let targetName =
                approval.targetName,
            let targetPath =
                approval.targetPath
        {
            approvedRuntimeApplicationTargets[
                approval.stepIndex
            ] =
                DesktopApplicationApprovalTarget(
                    name: targetName,
                    bundleIdentifier:
                        approval.targetBundleIdentifier,
                    path: targetPath
                )
        }

        currentTaskApprovalAudit =
            TaskApprovalAudit(
                stepIndex:
                    approval.stepIndex,
                title:
                    approval.title,
                capabilityID:
                    approval.capabilityID,
                targetSummary:
                    approval.targetSummary,
                targetName:
                    approval.targetName,
                targetBundleIdentifier:
                    approval
                        .targetBundleIdentifier,
                targetPath:
                    approval.targetPath,
                decision:
                    "approved",
                recordedAt:
                    Date()
            )

        pendingTaskApproval = nil
        currentRuntimeTask?.state =
            .running
        currentRuntimeTask?
            .waitingResourceIDs = []

        verificationState =
            .checking
        verificationSummary =
            "Onaylanan adımdan devam ediliyor…"
        busy = true

        Task {
            await resumeApprovedSemanticTask(
                mission: mission,
                decision: decision
            )
        }
    }

    func cancelPendingTaskApproval() {
        guard let approval =
            pendingTaskApproval
        else {
            return
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text:
                    "İptal: " +
                    approval.title
            )
        )

        currentTaskApprovalAudit =
            TaskApprovalAudit(
                stepIndex:
                    approval.stepIndex,
                title:
                    approval.title,
                capabilityID:
                    approval.capabilityID,
                targetSummary:
                    approval.targetSummary,
                targetName:
                    approval.targetName,
                targetBundleIdentifier:
                    approval
                        .targetBundleIdentifier,
                targetPath:
                    approval.targetPath,
                decision:
                    "rejected",
                recordedAt:
                    Date()
            )

        pendingTaskApproval = nil
        currentRuntimeTask?.state =
            .cancelled
        currentRuntimeTask?
            .waitingResourceIDs = []
        verificationState =
            .partial
        verificationSummary =
            "Kullanıcı onay vermedi; dış işlem uygulanmadı."

        postAssistantMessage(
            "İşlemi iptal ettim. Onay gerektiren adım uygulanmadı."
        )

        log(
            "Task approval kullanıcı tarafından iptal edildi • step=" +
            String(
                approval.stepIndex
            )
        )
    }

    private func resumeApprovedSemanticTask(
        mission: AgentSemanticMission,
        decision: AgentDecision
    ) async {
        let result =
            await executeAvailableSemanticMission(
                mission,
                userInput:
                    currentTaskInput
            )

        completeSemanticActionSteps(
            executedCapabilityIDs:
                result.executedCapabilityIDs,
            completedMissionStepIndexes:
                result.completedStepIndexes
        )

        if let graph =
            currentTaskGraph,
           currentRuntimeTask?.state !=
                .waitingForApproval {
            let runtimeGaps =
                capabilityGapResolver
                    .resolveRuntimeFailures(
                        graph: graph,
                        completedStepIndexes:
                            result
                                .completedStepIndexes,
                        approvedStepIndexes:
                            approvedRuntimeStepIndexes,
                        capabilities:
                            runtimeCapabilities()
                    )

            for gap in runtimeGaps
                where !currentCapabilityGaps
                    .contains(
                        where: {
                            $0.capabilityID ==
                                gap.capabilityID
                        }
                    ) {
                currentCapabilityGaps
                    .append(gap)
            }
        }

        let fallbackGoal =
            goalInterpreter.interpret(
                currentTaskInput,
                decision: decision,
                context: brainContext()
            )

        let goal =
            semanticGoalProfile(
                from: mission,
                fallback:
                    fallbackGoal
            )

        var verification =
            verifier.verify(
                decision: decision,
                currentUserInput:
                    currentTaskInput,
                goal: goal,
                semanticMission:
                    mission,
                outcomeResolution:
                    currentOutcomeResolution,
                outcomeAttempts:
                    currentOutcomeAttempts,
                snapshot:
                    verificationSnapshot(
                        executedCapabilityIDs:
                            result
                                .executedCapabilityIDs
                    )
            )

        if let pending =
            pendingTaskApproval {
            verification =
                AgentVerificationResult(
                    state: .partial,
                    summary:
                        "Görev güvenli biçimde duraklatıldı. Sıradaki dış işlem kullanıcı onayı bekliyor: " +
                        pending.title,
                    fallback: nil
                )
        }

        verificationState =
            verification.state
        verificationSummary =
            verification.summary

        if pendingTaskApproval == nil {
            switch verification.state {
            case .passed, .skipped:
                currentRuntimeTask?.state =
                    .completed
            case .partial, .attention:
                if currentRuntimeTask?.state !=
                    .cancelled {
                    currentRuntimeTask?.state =
                        .failed
                }
            case .idle, .checking:
                break
            }

            promoteVerifiedSkills(
                executedCapabilityIDs:
                    result.executedCapabilityIDs
                        .union(
                            runtimeExecutedCapabilityIDs
                        ),
                verification:
                    verification
            )
        }

        let baseReply =
            result.reply
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
            ? (
                pendingTaskApproval == nil
                ? "Onaylanan adımdan devam ettim."
                : "Görev bir sonraki onay kapısında durdu."
            )
            : result.reply

        let reply =
            responseComposer.compose(
                baseReply: baseReply,
                verification:
                    verification,
                goal: goal,
                capabilities:
                    selectedCapabilities,
                learningPlans:
                    capabilityLearningPlans,
                capabilityGaps:
                    currentCapabilityGaps,
                fallbackPlan: nil
            )

        recordMentorTrace(
            input:
                currentTaskInput,
            source: .text,
            goal:
                goal.summary,
            plan:
                mission.steps
                    .map(\.title)
                    .joined(
                        separator: " → "
                    ),
            route:
                activeRoute,
            capabilities:
                selectedCapabilities,
            learningPlans:
                capabilityLearningPlans,
            verification:
                verification,
            intelligenceProvider:
                nil,
            finalResponse:
                reply
        )

        appendConversationMessage(
            ChatMessage(
                role: .assistant,
                text: reply
            )
        )

        busy = false

        if pendingTaskApproval == nil,
           !currentCapabilityGaps
                .isEmpty {
            inspectorState.learningQueueJobs =
                learningQueueStore.enqueue(
                    gaps:
                        currentCapabilityGaps,
                    sourceGoal:
                        currentTaskInput,
                    into:
                        inspectorState
                            .learningQueueJobs
                )

            startNextLearningJobIfNeeded()
        }
    }

    private struct ProblemSolverFallbackResult {
        let strategyTitle: String
        let evidence: String
        let output: String
        let executedCapabilityIDs: Set<String>
        let reflection: String
    }

    private func executeProblemSolverFallback(
        graphStep: AgentTaskGraphStep,
        missionStep: AgentSemanticMissionStep,
        mission: AgentSemanticMission,
        dependencyEvidence: String,
        userInput: String,
        attemptedStrategyIDs: [String]
    ) async -> ProblemSolverFallbackResult? {
        let resolution =
            problemSolver.reflection(
                step: graphStep,
                attemptedStrategyIDs:
                    attemptedStrategyIDs,
                dependencyEvidence:
                    dependencyEvidence,
                capabilities:
                    runtimeCapabilities()
            )

        currentProblemResolution =
            resolution
        currentReflectionSummary =
            resolution.reflection

        guard
            let strategy =
                resolution.chosenStrategy,
            strategy.executableNow,
            !strategy.requiresLearning,
            strategy.kind != .primary
        else {
            return nil
        }

        log(
            "Problem Solver reflection: " +
            (resolution.reflection ??
                "Alternatif strateji seçildi")
        )
        log(
            "Problem Solver stratejisi: " +
            strategy.title +
            " • " +
            strategy.rationale
        )

        switch strategy.kind {
        case .reuseEvidence:
            let evidence =
                dependencyEvidence
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard !evidence.isEmpty else {
                return nil
            }

            return ProblemSolverFallbackResult(
                strategyTitle:
                    strategy.title,
                evidence: evidence,
                output:
                    "Mevcut doğrulanmış kanıtı yeniden kullanarak adımı tamamladım.",
                executedCapabilityIDs:
                    Set(strategy.capabilityIDs),
                reflection:
                    resolution.reflection ??
                    strategy.rationale
            )

        case .screenObservation:
            do {
                let report =
                    try await screenPerception
                        .observe(
                            goal:
                                [
                                    mission.objective,
                                    missionStep.title,
                                    missionStep.purpose,
                                    dependencyEvidence
                                ]
                                .filter {
                                    !$0
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        )
                                        .isEmpty
                                }
                                .joined(
                                    separator: "\n"
                                )
                        )

                let evidence =
                    report.semanticSummary

                return ProblemSolverFallbackResult(
                    strategyTitle:
                        strategy.title,
                    evidence: evidence,
                    output:
                        "Alternatif ekran gözlemi:\n" +
                        evidence,
                    executedCapabilityIDs:
                        Set(strategy.capabilityIDs),
                    reflection:
                        resolution.reflection ??
                        strategy.rationale
                )
            } catch {
                log(
                    "Problem Solver screen fallback başarısız: " +
                    error.localizedDescription
                )
                return nil
            }

        case .genericAppWorkflow:
            do {
                let result =
                    try await appWorkflowStrategy
                        .execute(
                            objective:
                                mission.objective,
                            stepTitle:
                                missionStep.title,
                            stepPurpose:
                                missionStep.purpose,
                            dependencyEvidence:
                                dependencyEvidence
                        )

                let evidence = [
                    "Öndeki uygulama: " +
                        result.frontmostApplication,
                    result.observationEvidence,
                    result.workflowOutput,
                    "Dış değişiklik uygulandı: hayır"
                ]
                .joined(separator: "\n\n")

                return ProblemSolverFallbackResult(
                    strategyTitle:
                        strategy.title,
                    evidence: evidence,
                    output:
                        result.workflowOutput,
                    executedCapabilityIDs:
                        Set(strategy.capabilityIDs),
                    reflection:
                        resolution.reflection ??
                        strategy.rationale
                )
            } catch {
                log(
                    "Problem Solver app workflow fallback başarısız: " +
                    error.localizedDescription
                )
                return nil
            }

        case .publicResearch:
            let composedQuery = [
                mission.objective,
                missionStep.title,
                missionStep.purpose,
                dependencyEvidence,
                userInput
            ]
            .filter {
                !$0
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            }
            .joined(separator: "\n")

            let reply =
                await performWebResearch(
                    query:
                        webResearchQuery(
                            from:
                                String(
                                    composedQuery
                                        .prefix(4_000)
                                )
                        )
                )

            guard
                !webResearchResults.isEmpty ||
                !webResearchEvidence.isEmpty
            else {
                return nil
            }

            return ProblemSolverFallbackResult(
                strategyTitle:
                    strategy.title,
                evidence: reply,
                output: reply,
                executedCapabilityIDs:
                    Set(strategy.capabilityIDs),
                reflection:
                    resolution.reflection ??
                    strategy.rationale
            )

        case .reasoningTransform:
            guard
                !dependencyEvidence
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                return nil
            }

            if let reasoning =
                await localIntelligence
                    .executeReasoningStep(
                        goal:
                            mission.objective,
                        title:
                            missionStep.title,
                        purpose:
                            missionStep.purpose,
                        operation:
                            missionStep.operation,
                        dependencyEvidence:
                            dependencyEvidence
                    ) {
                return ProblemSolverFallbackResult(
                    strategyTitle:
                        strategy.title,
                    evidence: reasoning,
                    output: reasoning,
                    executedCapabilityIDs:
                        Set(strategy.capabilityIDs),
                    reflection:
                        resolution.reflection ??
                        strategy.rationale
                )
            }

            return nil

        case .primary,
             .learning:
            return nil
        }
    }

    private func semanticFileSearchInput(
        step: AgentSemanticMissionStep,
        userInput: String
    ) -> String {
        var parts: [String] = [
            step.title,
            step.operation
        ]

        let normalized =
            normalizeSemanticText(
                userInput
            )

        let portableConstraints = [
            "masaustu", "desktop",
            "indirilenler", "downloads",
            "belgeler", "documents",
            "bugun", "bugunku",
            "dun", "dunku",
            "en yeni", "en son",
            "latest", "recent",
            "pdf", "video",
            "gorsel", "fotograf",
            "resim", "belge",
            "dokuman", "proje",
            "ses", "audio"
        ]

        for constraint in portableConstraints
            where normalized.contains(
                normalizeSemanticText(
                    constraint
                )
            ) {
            parts.append(
                constraint
            )
        }

        return parts
            .filter {
                !$0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ).isEmpty
            }
            .joined(separator: " ")
    }

    private func semanticRelativeDateRange(
        from normalizedCorpus: String
    ) -> DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        let today =
            calendar.startOfDay(
                for: now
            )

        if containsSemanticAny(
            normalizedCorpus,
            [
                "bugun",
                "bugunku"
            ]
        ) {
            guard let tomorrow =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: today
                )
            else {
                return nil
            }

            return DateInterval(
                start: today,
                end: tomorrow
            )
        }

        if containsSemanticAny(
            normalizedCorpus,
            [
                "dun",
                "dunku"
            ]
        ) {
            guard
                let yesterday =
                    calendar.date(
                        byAdding: .day,
                        value: -1,
                        to: today
                    )
            else {
                return nil
            }

            return DateInterval(
                start: yesterday,
                end: today
            )
        }

        return nil
    }

    private func semanticFileSearchDecision(
        mission: AgentSemanticMission,
        userInput: String
    ) -> AgentDecision {
        let query =
            fileQueryParser.parse(
                userInput
            )

        let target =
            fileQueryParser
                .resolveTargetEntity(
                    userInput
                )

        let relativeDateRange =
            semanticRelativeDateRange(
                from:
                    normalizeSemanticText(
                        userInput
                    )
            )

        return AgentDecision(
            intent: .fileSearch,
            target: target,
            dateRange:
                relativeDateRange,
            dateField:
                query.dateField,
            sortMode:
                query.sortMode,
            route: [
                "Core",
                "Goal",
                "Context",
                "Files"
            ],
            goal:
                mission.objective,
            selectedPlan:
                query.scopeIsExplicit
                ? (
                    query.scope.title +
                    " kapsamını salt-okunur tara; entity, rank, output ve güvenlik kısıtlarını koru."
                )
                : "Seçili çalışma alanında entity, rank, output ve güvenlik kısıtlarını koruyarak salt-okunur ara.",
            alternatives: [],
            proactiveSuggestion: nil,
            usePreviousResults: false,
            resultSelection: nil
        )
    }

    private func semanticMissionStatusReply(
        _ mission: AgentSemanticMission
    ) -> String {
        let blocked = selectedCapabilities
            .filter {
                mission.requiredCapabilityIDs.contains($0.id) &&
                !$0.isAvailable
            }
            .map(\.name)

        if blocked.isEmpty {
            return "Hedefi “\(mission.objective)” olarak çözdüm ve mevcut capability'lerle uygulanabilir adımları yürüttüm."
        }

        return "Hedefi “\(mission.objective)” olarak çözdüm. Semantic plan hazır; şu capability'ler henüz bağlı olmadığı için ilgili uygulama adımları bekliyor: " +
            blocked.joined(separator: ", ") + "."
    }

    private func completeSemanticActionSteps(
        executedCapabilityIDs: Set<String>,
        completedMissionStepIndexes: Set<Int>,
        substitutedCapabilityIDs: Set<String> = []
    ) {
        var semanticStepIndex = 0

        for index in executionSteps.indices {
            switch executionSteps[index].kind {
            case .reasoning:
                if !isSynthesisReasoningStep(
                    executionSteps[index]
                ) {
                    executionSteps[index].state = .completed
                }

                if executionSteps[index].capabilityID != nil {
                    semanticStepIndex += 1
                }

            case .action:
                guard let capabilityID =
                    executionSteps[index].capabilityID else {
                    executionSteps[index].state = .partial
                    continue
                }

                if completedMissionStepIndexes.contains(
                    semanticStepIndex
                ) {
                    executionSteps[index].state = .completed
                } else if substitutedCapabilityIDs
                    .contains(
                        capabilityID
                    ) {
                    executionSteps[index].state = .skipped
                } else if !isStepCapabilityAvailable(
                    executionSteps[index]
                ) {
                    executionSteps[index].state = .blocked
                } else if executedCapabilityIDs.contains(
                    capabilityID
                ) {
                    executionSteps[index].state = .completed
                } else {
                    executionSteps[index].state = .partial
                }

                semanticStepIndex += 1

            case .response:
                executionSteps[index].state = .completed

            case .verification:
                break
            }
        }
    }

    private func normalizeSemanticText(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
    }

    private func containsSemanticAny(
        _ text: String,
        _ values: [String]
    ) -> Bool {
        values.contains {
            text.contains(
                normalizeSemanticText($0)
            )
        }
    }

    private func makeReply(
        for text: String,
        decision: AgentDecision
    ) -> String {
        switch decision.intent {
        case .approve:
            return approvePendingFileAction()

        case .reject:
            pendingFileAction = nil
            log("Bekleyen dosya işlemi iptal edildi")
            return "Tamam, dosya işlemini iptal ettim."

        case .undo:
            return undoLastFileAction()

        case .conversation:
            return conversationReply(for: text)

        case .assessWorkspace:
            return assessWorkspace()

        case .remember:
            let explicitRules = memoryIntents(from: text)

            guard !explicitRules.isEmpty else {
                return "Bunu bir çalışma kuralı olarak algıladım fakat kaydedilecek kısmı net çıkaramadım."
            }

            for rule in explicitRules {
                addMemory(rule)
            }

            if explicitRules.count == 1,
               let rule = explicitRules.first {
                return "Kaydettim: “\(rule)”. Uygun görevlerde bunu otomatik uygulayacağım."
            }

            let listedRules = explicitRules
                .map { "• " + $0 }
                .joined(separator: "\n")

            return "İki ayrı kural olarak kaydettim:\n" + listedRules

        case .organizeScreenshots:
            return prepareScreenshotOrganizeAction()

        case .fileSearch:
            if decision.target == .folder {
                return searchIndexedFolders(
                    for: text,
                    decision: decision
                )
            }

            return searchIndexedFiles(
                for: text,
                decision: decision
            )

        case .compoundFileTask:
            return executeCompoundFileTask(
                for: text,
                decision: decision
            )

        case .openPreviousResult:
            return openPreviousResult(
                selection: decision.resultSelection
            )

        case .contextSuggestion:
            return suggestFromPreviousResults()

        case .workMail:
            log("Mail görevi planlandı; gönderim onay gerektiriyor")
            return "Mail hedefini anladım. Şimdilik gerçek mail bağlantısını çalıştırmadan önce kaynak ve taslak aşamasını ayrı tutuyorum."

        case .futureCapability:
            return "Bu hedefi anladım fakat ilgili dış araç henüz KRALİ'ye bağlı değil. Mevcut yerel araçlarla yapılabilecek kısmı ayırıp güvenli plan üretebilirim."

        case .general:
            return "Hedefi analiz ettim fakat mevcut yerel araçlardan biriyle güvenilir biçimde eşleştiremedim. Şu an en güvenli planım: \(decision.selectedPlan)."
        }
    }

    private func deterministicProblemGraph(
        goal: AgentGoalProfile,
        plan: AgentExecutionPlan
    ) -> AgentTaskGraph {
        let steps =
            plan.steps.enumerated().map {
                index, step in

                let capabilityID =
                    step.capabilityID ??
                    "core.reasoning"

                let capability =
                    runtimeCapabilities()
                        .first {
                            $0.id ==
                                capabilityID
                        }

                let role: AgentTaskStepRole

                switch step.kind {
                case .reasoning:
                    role = .reason

                case .verification:
                    role = .verify

                case .response:
                    role = .reason

                case .action:
                    switch capability?.risk {
                    case .readOnly:
                        role = .retrieve
                    case .reversibleWrite:
                        role = .persist
                    case .external:
                        role = .act
                    case .reasoning, .none:
                        role = .act
                    }
                }

                let approvalReason =
                    taskOrchestrator
                        .approvalReason(
                            title:
                                step.title,
                            operation:
                                step.detail,
                            capability:
                                capability
                        )

                return AgentTaskGraphStep(
                    index: index,
                    title: step.title,
                    capabilityID:
                        capabilityID,
                    operation: step.detail,
                    role: role,
                    dependsOn:
                        index > 0
                        ? [index - 1]
                        : [],
                    risk:
                        capability?.risk ??
                        .reasoning,
                    isAvailable:
                        capability?
                            .isAvailable ??
                        (
                            capabilityID ==
                            "core.reasoning"
                        ),
                    requiresApproval:
                        approvalReason != nil,
                    approvalReason:
                        approvalReason
                )
            }

        return AgentTaskGraph(
            objective: goal.summary,
            steps: steps
        )
    }

    private func resetTransientTaskStateForNewInput() {
        currentSemanticMission = nil
        currentSemanticPlannerProvider = nil
        currentTaskGraph = nil
        currentRuntimeTask = nil
        pendingTaskApproval = nil
        approvedRuntimeStepIndexes = []
        approvedRuntimeApplicationTargets = [:]
        currentTaskApprovalAudit = nil
        runtimeStepEvidence = [:]
        runtimeExecutedCapabilityIDs = []
        currentTaskInput = ""
        taskGraphStatus = "Yeni görev için görev grafiği bekleniyor."
        currentProblemResolution = nil
        currentOutcomeResolution = nil
        currentOutcomeAttempts = []
        currentReflectionSummary = nil
        currentSelfDiagnosisReport = nil
        currentCapabilityGaps = []
        currentOutcomeFailureIsTransient = false
        activeRoute = ["Core"]
        selectedCapabilities = []
        capabilityLearningPlans = []
        executionSteps = []
        verificationState = .idle
        verificationSummary = "Yeni görev için doğrulama bekleniyor."
        fallbackPlan = nil
        recoverySummary = nil
        inspectorState.debugIncident = nil
        webResearchResults = []
        webResearchEvidence = []
        lastFileSearchOutcome = nil
        webResearchStatus = "Bu tur için araştırma henüz başlamadı."
        intelligenceProviderStatus = "Sentez sağlayıcısı henüz kullanılmadı."
        inspectorState.mentorTraceReady = false
        if !inspectorState.mentorSyncBusy {
            inspectorState.mentorTraceStatus =
                "Yeni görev için güncel Mentor kaydı bekleniyor."
        }
    }

    private func problemSolverObservations()
        -> [String] {
        var observations: [String] = []

        if let root = selectedRootURL {
            observations.append(
                "Seçili çalışma alanı: " +
                root.lastPathComponent
            )
        }

        if workspaceIndexReady {
            observations.append(
                "Workspace gözlemi: " +
                String(indexedFiles.count) +
                " dosya, " +
                String(indexedFolders.count) +
                " klasör."
            )
        }

        if let fileOutcome =
            lastFileSearchOutcome {
            observations.append(
                "Son dosya araması: " +
                fileOutcome.status.rawValue +
                " • " +
                String(fileOutcome.resultCount) +
                " sonuç."
            )
        }

        if let incident =
            inspectorState.debugIncident {
            observations.append(
                "Son debug gözlemi: " +
                incident.summary
            )
        }

        return observations
    }

    private func brainContext() -> AgentContextSnapshot {
        let taskContext =
            activeContextMemories.filter {
                $0.kind != .userRule
            }

        return AgentContextSnapshot(
            hasWorkspace:
                selectedRootURL != nil ||
                lastFileSearchOutcome?.rootPath != nil,
            workspaceName: selectedRootURL?.lastPathComponent,
            fileCount: indexedFiles.count,
            imageCount: imageCount,
            videoCount: videoCount,
            projectCount: projectCount,
            documentCount: documentCount,
            screenshotCount: screenshotCount,
            hasPendingAction: pendingFileAction != nil,
            previousFileResultCount: fileSearchResults.count,
            previousFolderResultCount: folderSearchResults.count,
            lastTarget: lastDecision?.target,
            lastGoal: lastDecision?.goal,
            relevantMemoryCount: taskContext.count,
            lastMemoryGoal: taskContext
                .first(where: { $0.goal != nil })?
                .goal
        )
    }

    private struct RecoveryAttempt {
        let reply: String
        let verification: AgentVerificationResult
        let summary: String
    }

    private func attemptSafeRecovery(
        for text: String,
        decision: AgentDecision,
        goal: AgentGoalProfile
    ) -> RecoveryAttempt? {
        guard decision.intent == .fileSearch ||
              decision.intent == .compoundFileTask else {
            return nil
        }

        if lastFileSearchOutcome?
            .status.isExpectedBoundary == true {
            return nil
        }

        let parsedQuery =
            fileQueryParser.parse(text)

        let explicitScope =
            parsedQuery.scopeIsExplicit

        if explicitScope {
            log(
                "Scope Isolation aktif • explicit=" +
                parsedQuery.scope.title +
                " • selectedWorkspace=" +
                (
                    selectedRootURL?
                        .lastPathComponent ??
                    "∅"
                )
            )
        }

        // Workspace contradiction recovery is only valid when the task
        // actually targets the user-selected workspace. An explicit scope
        // such as Downloads/Desktop/Documents must never borrow evidence
        // from selectedRootURL.
        if !explicitScope,
           decision.target == .folder,
           folderSearchResults.isEmpty {
            ensureWorkspaceIndexed()

            if !indexedFolders.isEmpty {
                var recoveredFolders =
                    indexedFolders

                if decision.sortMode ==
                    .newestFirst {
                    recoveredFolders.sort {
                        let left =
                            $0.modificationDate ??
                            $0.creationDate ??
                            .distantPast
                        let right =
                            $1.modificationDate ??
                            $1.creationDate ??
                            .distantPast
                        return left > right
                    }
                }

                folderSearchResults =
                    recoveredFolders
                fileSearchResults = []
                fileSearchTitle =
                    "Klasörler • mevcut indeks kanıtı"

                let preview =
                    recoveredFolders
                        .prefix(5)
                        .map(\.name)
                        .joined(separator: ", ")

                let reply =
                    String(
                        recoveredFolders.count
                    ) +
                    " klasör gözlemledim. İlk klasör arama stratejisi sonuç üretmediği için seçili çalışma alanının doğrulanmış indeksini yeniden kullandım: " +
                    preview +
                    (
                        recoveredFolders.count > 5
                        ? " ve " +
                            String(
                                recoveredFolders.count - 5
                            ) +
                            " klasör daha."
                        : "."
                    )

                let verification =
                    verifier.verify(
                        decision: decision,
                        currentUserInput: text,
                        goal: goal,
                        snapshot:
                            verificationSnapshot()
                    )

                let reflection =
                    "Çelişki algılandı: seçili workspace indeksi " +
                    String(
                        indexedFolders.count
                    ) +
                    " klasör gözlemledi fakat birincil arama 0 sonuç verdi. Explicit scope olmadığı için aynı workspace kanıtı yeniden kullanıldı."

                currentReflectionSummary =
                    reflection

                if let current =
                    currentProblemResolution {
                    currentProblemResolution =
                        AgentProblemResolution(
                            frame:
                                current.frame,
                            strategies:
                                current.strategies,
                            chosenStrategyID:
                                current.chosenStrategyID,
                            reflection:
                                reflection
                        )
                }

                recoverySummary =
                    reflection

                log(
                    "Problem Solver contradiction recovery: " +
                    reflection
                )

                return RecoveryAttempt(
                    reply: reply,
                    verification:
                        verification,
                    summary:
                        reflection
                )
            }
        }

        let hasRelaxableConstraint =
            decision.usePreviousResults ||
            decision.dateRange != nil

        guard hasRelaxableConstraint else {
            return nil
        }

        // Folder search still uses the legacy selected-workspace index.
        // Until it is migrated to the scoped coordinator, never run Plan B
        // for an explicitly-scoped folder request because that could cross
        // into selectedRootURL.
        if explicitScope,
           decision.target == .folder {
            log(
                "Plan B atlandı: explicit folder scope selected workspace'e düşürülemez"
            )
            return nil
        }

        let recoveryDecision = AgentDecision(
            intent: decision.intent,
            target: decision.target,
            dateRange: nil,
            dateField: .either,
            sortMode: decision.sortMode,
            route: decision.route + ["Plan B"],
            goal:
                explicitScope
                ? "Aynı explicit kapsamda daha geniş " +
                    decision.goal
                : "Seçili çalışma alanında daha geniş " +
                    decision.goal,
            selectedPlan:
                explicitScope
                ? "İlk aramada sonuç çıkmadığı için tarih / önceki-sonuç kısıtını kaldır; konumu değiştirmeden aynı explicit kapsamda salt-okunur yeniden ara."
                : "İlk aramada sonuç çıkmadığı için tarih / önceki-sonuç kısıtını kaldır ve aynı seçili çalışma alanında salt-okunur yeniden ara.",
            alternatives:
                decision.alternatives,
            proactiveSuggestion: nil,
            usePreviousResults: false,
            resultSelection: nil
        )

        log(
            explicitScope
            ? "Plan B deneniyor: explicit scope korunarak yalnız relaxable filtreler gevşetiliyor"
            : "Plan B deneniyor: seçili çalışma alanında relaxable filtreler gevşetiliyor"
        )

        let reply: String
        if recoveryDecision.intent ==
            .compoundFileTask {
            reply = executeCompoundFileTask(
                for: text,
                decision: recoveryDecision
            )
        } else if recoveryDecision.target ==
            .folder {
            reply = searchIndexedFolders(
                for: text,
                decision: recoveryDecision
            )
        } else {
            // raw text is intentionally preserved so AgentFileQueryParser
            // keeps explicit Downloads/Desktop/Documents scope unchanged.
            reply = searchIndexedFiles(
                for: text,
                decision: recoveryDecision
            )
        }

        let verification =
            verifier.verify(
                decision: recoveryDecision,
                currentUserInput: text,
                goal: goal,
                snapshot:
                    verificationSnapshot()
            )

        return RecoveryAttempt(
            reply: reply,
            verification:
                verification,
            summary:
                explicitScope
                ? "Tarih / önceki sonuç kısıtı kaldırıldı; explicit dosya kapsamı değişmeden korundu."
                : "Tarih / önceki sonuç kısıtı kaldırılarak aynı seçili çalışma alanında yeniden arandı."
        )
    }

    private func prepareExecutionSteps() {
        for index in executionSteps.indices {
            switch executionSteps[index].kind {
            case .reasoning:
                executionSteps[index].state =
                    isSynthesisReasoningStep(
                        executionSteps[index]
                    )
                    ? .pending
                    : .completed

            case .action:
                if isStepCapabilityAvailable(executionSteps[index]) {
                    executionSteps[index].state = .pending
                } else {
                    executionSteps[index].state = .blocked
                }

            case .verification, .response:
                executionSteps[index].state = .pending
            }
        }

        if let firstRunnableAction = executionSteps.firstIndex(
            where: {
                $0.kind == .action &&
                $0.state == .pending
            }
        ) {
            executionSteps[firstRunnableAction].state = .running
        } else if let response = executionSteps.firstIndex(
            where: { $0.kind == .response }
        ) {
            executionSteps[response].state = .running
        }
    }

    private func completeActionSteps() {
        for index in executionSteps.indices {
            guard executionSteps[index].kind == .action else {
                continue
            }

            if isStepCapabilityAvailable(executionSteps[index]) {
                executionSteps[index].state = .completed
            } else {
                executionSteps[index].state = .blocked
            }
        }

        if let response = executionSteps.firstIndex(
            where: { $0.kind == .response }
        ) {
            executionSteps[response].state = .completed
        }
    }

    private func completeSynthesisSteps(
        success: Bool
    ) {
        for index in executionSteps.indices {
            guard
                executionSteps[index].kind == .reasoning,
                isSynthesisReasoningStep(
                    executionSteps[index]
                )
            else {
                continue
            }

            executionSteps[index].state =
                success ? .completed : .partial
        }
    }

    private func isSynthesisReasoningStep(
        _ step: AgentExecutionStep
    ) -> Bool {
        let normalized = step.title
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(
                of: "ı",
                with: "i"
            )

        return normalized.contains("analiz et") ||
            normalized.contains("bagimsiz fikir") ||
            normalized.contains("icerigi olustur") ||
            normalized.contains("istenen formata")
    }

    private func enforceGoalCompletion(
        goal: AgentGoalProfile,
        verification: AgentVerificationResult,
        synthesisApplied: Bool
    ) -> AgentVerificationResult {
        let needsSynthesis =
            goal.outcomes.contains(.analyze) ||
            goal.outcomes.contains(.ideate) ||
            goal.outcomes.contains(.compose) ||
            goal.outcomes.contains(.transform) ||
            (
                goal.outcomes.contains(.research) &&
                goal.outcomes.contains(.explain)
            )

        guard needsSynthesis else {
            return verification
        }

        guard !synthesisApplied else {
            return verification
        }

        if verification.state == .attention {
            return verification
        }

        return AgentVerificationResult(
            state: .partial,
            summary:
                verification.summary +
                " Araştırma/araç kısmı doğrulandı; ancak istenen analiz, dönüşüm veya bağımsız fikir üretimi için güvenilir sentez sağlayıcısı kullanılamadığı için hedefin tamamı doğrulanmadı.",
            fallback: nil
        )
    }

    private func isStepCapabilityAvailable(
        _ step: AgentExecutionStep
    ) -> Bool {
        guard let capabilityID = step.capabilityID else {
            return true
        }

        guard let capability = selectedCapabilities.first(
            where: { $0.id == capabilityID }
        ) else {
            return true
        }

        return capability.isAvailable
    }

    private func setVerificationStep(
        _ state: AgentStepState
    ) {
        for index in executionSteps.indices {
            if executionSteps[index].kind == .verification {
                executionSteps[index].state = state
            }
        }
    }

    private func verificationSnapshot(
        executedCapabilityIDs: Set<String> = []
    ) -> AgentVerificationSnapshot {
        AgentVerificationSnapshot(
            hasWorkspace:
                selectedRootURL != nil ||
                lastFileSearchOutcome?.rootPath != nil,
            fileResultCount: fileSearchResults.count,
            folderResultCount: folderSearchResults.count,
            hasPendingAction: pendingFileAction != nil,
            hasUndoAction: lastUndoAction != nil,
            unavailableCapabilityIDs: Set(
                selectedCapabilities
                    .filter { !$0.isAvailable }
                    .map(\.id)
            ),
            selectedCapabilityIDs: Set(
                selectedCapabilities.map(\.id)
            ),
            executedCapabilityIDs:
                executedCapabilityIDs,
            incompleteRequiredActionCapabilityIDs:
                Set(
                    executionSteps.compactMap { step in
                        guard
                            step.kind == .action,
                            let capabilityID =
                                step.capabilityID,
                            step.state != .completed
                        else {
                            return nil
                        }

                        return capabilityID
                    }
                ),
            webResearchResultCount: webResearchResults.count,
            webResearchEvidenceCount: webResearchEvidence.count,
            webResearchUniqueDomainCount: Set(
                webResearchResults.map {
                    $0.domain.lowercased()
                }
            ).count,
            webResearchCanonicalEvidenceCount:
                webResearchEvidence.filter {
                    !$0.source.evidenceEligible
                }.count,
            fileSearchOutcome:
                lastFileSearchOutcome
        )
    }

    private func outcomeChainCanOwnExecution(
        _ resolution: AgentOutcomeResolution
    ) -> Bool {
        let supportedKinds: Set<AgentOutcomeStrategyKind> = [
            .publicResearch,
            .openURLAndObserve,
            .screenObservation
        ]

        return resolution
            .contract
            .requirements
            .allSatisfy { requirement in
                resolution
                    .orderedExecutableStrategies(
                        for:
                            requirement.id
                    )
                    .contains(
                        where: {
                            supportedKinds
                                .contains(
                                    $0.kind
                                )
                        }
                    )
            }
    }

    private struct OutcomeStrategyChainResult {
        let succeeded: Bool
        let reply: String
        let executedCapabilityIDs: Set<String>
        let attempts: [AgentOutcomeStrategyAttempt]
    }

    private struct OutcomeStrategyExecutionResult {
        let succeeded: Bool
        let reply: String
        let summary: String
        let executedCapabilityIDs: Set<String>
        let observation: AgentOutcomeObservationMetadata?

        init(
            succeeded: Bool,
            reply: String,
            summary: String,
            executedCapabilityIDs: Set<String>,
            observation: AgentOutcomeObservationMetadata? = nil
        ) {
            self.succeeded = succeeded
            self.reply = reply
            self.summary = summary
            self.executedCapabilityIDs =
                executedCapabilityIDs
            self.observation = observation
        }
    }

    private func executeOutcomeStrategyChain(
        resolution: AgentOutcomeResolution,
        userInput: String
    ) async -> OutcomeStrategyChainResult {
        var attempts: [AgentOutcomeStrategyAttempt] = []
        var outputs: [String] = []
        var executed = Set<String>()
        var verifiedNavigationOutput: String?

        for requirement in
            resolution.contract.requirements {
            if requirement.kind ==
                .retrievePublicInformation,
               let navigationOutput =
                    verifiedNavigationOutput,
               !navigationOutput
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty {
                attempts.append(
                    AgentOutcomeStrategyAttempt(
                        id: UUID()
                            .uuidString,
                        strategyID:
                            requirement.id +
                            ":reuse-navigation-evidence",
                        requirementID:
                            requirement.id,
                        state:
                            .succeeded,
                        summary:
                            "Aynı görev içindeki doğrulanmış web-navigation ekran kanıtı yeniden kullanıldı; ikinci URL açılışı veya bağımsız ekran gözlemi yapılmadı.",
                        executedCapabilityIDs: []
                    )
                )

                log(
                    "Outcome Strategy başarılı: doğrulanmış navigation kanıtı yeniden kullanıldı"
                )
                continue
            }
            let strategies =
                resolution
                    .orderedExecutableStrategies(
                        for:
                            requirement.id
                    )

            var requirementSucceeded = false

            for strategy in strategies {
                log(
                    "Outcome Strategy denenecek: " +
                    strategy.title +
                    " • score=" +
                    String(strategy.score)
                )

                let result =
                    await executeOutcomeStrategy(
                        strategy,
                        requirement:
                            requirement,
                        userInput:
                            userInput
                    )

                attempts.append(
                    AgentOutcomeStrategyAttempt(
                        id: UUID()
                            .uuidString,
                        strategyID:
                            strategy.id,
                        requirementID:
                            requirement.id,
                        state:
                            result.succeeded
                            ? .succeeded
                            : .failed,
                        summary:
                            result.summary,
                        executedCapabilityIDs:
                            result
                                .executedCapabilityIDs
                                .sorted(),
                        observation:
                            result.observation
                    )
                )

                if result.succeeded {
                    requirementSucceeded = true
                    executed.formUnion(
                        result
                            .executedCapabilityIDs
                    )

                    let trimmedReply =
                        result.reply
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                    if !trimmedReply.isEmpty {
                        outputs.append(
                            trimmedReply
                        )

                        if requirement.kind ==
                            .navigateWebResource {
                            verifiedNavigationOutput =
                                trimmedReply
                        }
                    }

                    log(
                        "Outcome Strategy başarılı: " +
                        strategy.title
                    )
                    break
                }

                log(
                    "Outcome Strategy başarısız: " +
                    strategy.title +
                    " • " +
                    result.summary
                )
            }

            if !requirementSucceeded {
                return OutcomeStrategyChainResult(
                    succeeded: false,
                    reply:
                        outputs.joined(
                            separator: "\n\n"
                        ),
                    executedCapabilityIDs:
                        executed,
                    attempts:
                        attempts
                )
            }
        }

        return OutcomeStrategyChainResult(
            succeeded: true,
            reply:
                outputs.joined(
                    separator: "\n\n"
                ),
            executedCapabilityIDs:
                executed,
            attempts:
                attempts
        )
    }

    private func executeOutcomeStrategy(
        _ strategy: AgentOutcomeStrategy,
        requirement:
            AgentOutcomeRequirement,
        userInput: String
    ) async -> OutcomeStrategyExecutionResult {
        switch strategy.kind {
        case .publicResearch:
            let reply =
                await performWebResearch(
                    query:
                        webResearchQuery(
                            from:
                                userInput
                        ),
                    allowInteractiveEscalation:
                        false
                )

            let hasEvidence =
                !webResearchEvidence
                    .isEmpty

            return OutcomeStrategyExecutionResult(
                succeeded:
                    hasEvidence,
                reply:
                    hasEvidence
                    ? reply
                    : "",
                summary:
                    hasEvidence
                    ? "Gerçek web kaynak kanıtı üretildi."
                    : "Web araştırması sonuç veya derin okuma üretse bile başarı kriterini destekleyen gerçek kaynak kanıtı oluşmadı.",
                executedCapabilityIDs:
                    hasEvidence
                    ? Set(
                        strategy
                            .capabilityIDs
                    )
                    : []
            )

        case .openURLAndObserve:
            let targetURL =
                naturalLanguageResolver
                    .webURL(
                        from:
                            userInput
                    )

            return OutcomeStrategyExecutionResult(
                succeeded: false,
                reply: "",
                summary:
                    "Strict Approval Mode: otomatik URL açma fallback'i kullanıcı onayı olmadan çalıştırılmadı." +
                    (targetURL.map {
                        " Hedef: " +
                            $0.absoluteString
                    } ?? ""),
                executedCapabilityIDs: []
            )

        case .screenObservation:
            do {
                let report =
                    try await screenPerception
                        .observe(
                            goal:
                                userInput
                        )

                let summary =
                    report.semanticSummary
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard !summary.isEmpty else {
                    return OutcomeStrategyExecutionResult(
                        succeeded: false,
                        reply: "",
                        summary:
                            "Ekran gözlemi anlamlı kanıt üretmedi.",
                        executedCapabilityIDs: []
                    )
                }

                return OutcomeStrategyExecutionResult(
                    succeeded: true,
                    reply: summary,
                    summary:
                        "Görünür ekran kanıtı üretildi.",
                    executedCapabilityIDs:
                        Set(
                            strategy
                                .capabilityIDs
                        )
                )
            } catch {
                return OutcomeStrategyExecutionResult(
                    succeeded: false,
                    reply: "",
                    summary:
                        error.localizedDescription,
                    executedCapabilityIDs: []
                )
            }

        case .genericAppWorkflow,
             .directCapability,
             .localFiles,
             .reasoningTransform,
             .learning:
            return OutcomeStrategyExecutionResult(
                succeeded: false,
                reply: "",
                summary:
                    "Bu strategy kind için outcome-level generic executor bu sürümde bağlı değil.",
                executedCapabilityIDs: []
            )
        }
    }

    private func webResearchQuery(
        from rawText: String
    ) -> String {
        var query = rawText

        let phrases = [
            "web'de araştır",
            "webde araştır",
            "web'de arastir",
            "webde arastir",
            "internetten araştır",
            "internetten arastir",
            "internette araştır",
            "internette arastir",
            "google'da araştır",
            "googleda araştır",
            "google'da arastir",
            "googleda arastir"
        ]

        for phrase in phrases {
            query = query.replacingOccurrences(
                of: phrase,
                with: " ",
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ]
            )
        }

        return query
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func performWebResearch(
        query: String,
        allowInteractiveEscalation: Bool = true,
        allowSnippetEvidence: Bool = true,
        developmentFacet:
            AgentDevelopmentResearchFacet? = nil
    ) async -> String {
        webResearchStatus = "Web araştırılıyor…"
        log("Web Research başladı")

        do {
            let report = try await webResearchService.search(
                query,
                limit:
                    developmentFacet == nil
                    ? 5
                    : 8,
                developmentFacet:
                    developmentFacet
            )

            let evidence = await webSourceReader.read(
                report.results,
                query: query,
                limit: 4,
                allowSnippetFallback:
                    allowSnippetEvidence
            )

            webResearchEvidence = evidence

            if !evidence.isEmpty {
                webResearchResults = evidence.map(\.source)
            } else {
                webResearchResults = report.results
            }

            webResearchStatus =
                "\(webResearchResults.count) kaynak • " +
                "\(evidence.count) derin okuma • " +
                report.provider

            log(
                "Web Research tamamlandı: " +
                String(webResearchResults.count) +
                " kaynak, " +
                String(evidence.count) +
                " kaynak okundu"
            )

            let lines = webResearchResults.enumerated().map {
                index,
                result in

                "\(index + 1). \(result.title) — \(result.domain)"
            }
            .joined(separator: "\n")

            let evidenceText = evidence.prefix(3).map { item in
                "• \(item.source.title): \(item.excerpt)"
            }
            .joined(separator: "\n")

            let resolvedTargets = report.results.filter {
                !$0.evidenceEligible
            }

            if evidence.isEmpty,
               let resolved = resolvedTargets.first {
                if allowInteractiveEscalation {
                    queueInteractiveAccessCapability()
                }

                var reply =
                    "Hedefin doğrudan adresini çözdüm: " +
                    resolved.url.absoluteString +
                    "\n\nAncak bu kaynak canlı içeriğini statik web isteğine açmadığı için güncel veriyi doğrulayamadım."

                if allowInteractiveEscalation {
                    reply +=
                        "\n\nKRALİ bunu 'hedef yok' diye yorumlamıyor; bir sonraki gerekli yetkinlik olarak güvenli tarayıcı/oturum erişimini öğrenme kuyruğuna aldı."
                } else {
                    reply +=
                        "\n\nOutcome Strategy Chain bu yolu başarısız sayıp sıradaki güvenli stratejiyi değerlendirecek."
                }

                if !lines.isEmpty {
                    reply += "\n\nÇözülen / bulunan kaynaklar:\n" + lines
                }

                return reply
            }

            var reply =
                "Web'de araştırdım ve \(webResearchResults.count) alakalı kaynak buldum."

            if !evidenceText.isEmpty {
                reply +=
                    "\n\nKaynakların içine girip okuduğum kanıtlar:\n" +
                    evidenceText
            } else {
                reply +=
                    "\n\nKaynakları buldum fakat bu turda sayfa içeriğinden yeterli kanıt çıkaramadım."
            }

            reply += "\n\nKaynaklar:\n" + lines
            return reply
        } catch {
            webResearchResults = []
            webResearchEvidence = []
            webResearchStatus = error.localizedDescription
            log(
                "Web Research başarısız: " +
                error.localizedDescription
            )

            return "Web araştırmasını başlattım fakat doğrulanabilir sonuç kümesi alamadım: " +
                error.localizedDescription
        }
    }

    private func queueInteractiveAccessCapability() {
        guard
            let browser = runtimeCapabilities().first(
                where: { $0.id == "browser.control" }
            ),
            !browser.isAvailable
        else {
            return
        }

        if !selectedCapabilities.contains(
            where: {
                $0.id ==
                    browser.id
            }
        ) {
            selectedCapabilities.append(
                browser
            )
        }

        let plans = capabilityLearner.makePlans(
            for: [browser],
            webResearchAvailable: true
        )

        for plan in plans where !capabilityLearningPlans.contains(
            where: { $0.capabilityID == plan.capabilityID }
        ) {
            capabilityLearningPlans.append(plan)
        }

        capabilityLearningBacklog = learningStore.merge(
            existing: capabilityLearningBacklog,
            plans: plans,
            capabilities: selectedCapabilities
        )

        if !activeRoute.contains("Browser") {
            if let verifyIndex = activeRoute.firstIndex(
                of: "Verify"
            ) {
                activeRoute.insert(
                    "Browser",
                    at: verifyIndex
                )
            } else if let responseIndex = activeRoute.firstIndex(
                of: "Response"
            ) {
                activeRoute.insert(
                    "Browser",
                    at: responseIndex
                )
            } else {
                activeRoute.append("Browser")
            }
        }

        if !activeRoute.contains("Learn") {
            if let verifyIndex = activeRoute.firstIndex(
                of: "Verify"
            ) {
                activeRoute.insert(
                    "Learn",
                    at: verifyIndex
                )
            } else {
                activeRoute.append("Learn")
            }
        }

        log(
            "Statik araştırma hedefi çözdü ancak içerik erişimi doğrulanamadı; browser.control öğrenme kuyruğuna eklendi"
        )
    }

    private func researchCapabilityGapIfNeeded(
        plans: [CapabilityLearningPlan],
        userInput: String
    ) async -> String? {
        let corpus =
            normalizeSemanticText(
                userInput
            )

        let explicitLearningRequest =
            containsSemanticAny(
                corpus,
                [
                    "hangi yetenek eksik",
                    "hangi yetenegin eksik",
                    "nasıl yapıldığını öğren",
                    "nasil yapildigini ogren",
                    "kendine öğren",
                    "kendine ogren",
                    "öğrenme planı",
                    "ogrenme plani",
                    "bu yeteneği geliştir",
                    "bu yetenegi gelistir",
                    "capability geliştir",
                    "capability gelistir"
                ]
            )

        guard explicitLearningRequest else {
            return nil
        }

        guard let plan = plans.first(where: {
            $0.canResearchAutonomously
        }) else {
            return nil
        }

        guard let task = capabilityLearningBacklog.first(
            where: { $0.capabilityID == plan.capabilityID }
        ) else {
            return nil
        }

        guard task.progress == .readyToResearch else {
            return nil
        }

        capabilityLearningBacklog = learningStore.update(
            existing: capabilityLearningBacklog,
            capabilityID: plan.capabilityID,
            progress: .researching,
            nextStep: "KRALİ resmi ve güvenilir web kaynaklarını araştırıyor."
        )

        log(
            "Yetkinlik araştırması başladı: " +
            plan.capabilityName
        )

        do {
            let report = try await webResearchService.search(
                plan.researchGoal,
                limit: 5
            )

            let domains = report.results
                .map(\.domain)
                .joined(separator: ", ")

            let nextStep =
                "\(report.results.count) kaynak bulundu (\(domains)). " +
                "Sonraki adım: kaynakları derin oku, uygulanabilir mimari önerisini çıkar, izole prototip ve test planı hazırla."

            capabilityLearningBacklog = learningStore.update(
                existing: capabilityLearningBacklog,
                capabilityID: plan.capabilityID,
                progress: .proposalReady,
                nextStep: nextStep
            )

            log(
                "Yetkinlik araştırması kaynak buldu: " +
                plan.capabilityName
            )

            return "\(plan.capabilityName) için \(report.results.count) kaynak buldum. Çözüm önerisi hazırlama kuyruğuna aldım."
        } catch {
            capabilityLearningBacklog = learningStore.update(
                existing: capabilityLearningBacklog,
                capabilityID: plan.capabilityID,
                progress: .readyToResearch,
                nextStep: "Araştırma denemesi başarısız oldu: \(error.localizedDescription). Daha sonra farklı sorgu / sağlayıcıyla tekrar dene."
            )

            log(
                "Yetkinlik araştırması başarısız: " +
                error.localizedDescription
            )

            return "\(plan.capabilityName) için araştırma denemesi başarısız oldu; öğrenme kuyruğunda bekliyor."
        }
    }

    private func recordMentorTrace(
        input: String,
        source: ChatInputSource,
        goal: String,
        plan: String,
        route: [String],
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        verification: AgentVerificationResult,
        intelligenceProvider: String?,
        finalResponse: String
    ) {
        do {
            _ = try mentorTraceStore.save(
                input: input,
                inputSource: source,
                goal: goal,
                plan: plan,
                route: route,
                missionOwner: missionOwner,
                missionPhase: missionPhase,
                developerRepository: developerRepository,
                developerMissionReason: developerMissionReason,
                developerRunID: missionDeveloperRunID,
                selfDiagnosis: currentSelfDiagnosisReport,
                executionProfile: executionProfile,
                semanticMission: currentSemanticMission,
                semanticPlannerProvider:
                    currentSemanticPlannerProvider,
                taskGraph:
                    currentTaskGraph,
                approvalAudit:
                    currentTaskApprovalAudit,
                runtimeTask:
                    currentRuntimeTask,
                problemResolution:
                    currentProblemResolution,
                outcomeResolution:
                    currentOutcomeResolution,
                outcomeAttempts:
                    currentOutcomeAttempts,
                reflectionSummary:
                    currentReflectionSummary,
                capabilityGaps:
                    currentCapabilityGaps,
                capabilities: capabilities,
                learningPlans: learningPlans,
                executionSteps: executionSteps,
                verification: verification,
                intelligenceProvider: intelligenceProvider,
                fallbackPlan: fallbackPlan,
                finalResponse: finalResponse,
                researchSources: webResearchResults,
                researchEvidence: webResearchEvidence,
                contextMemory: activeContextMemories,
                activities: activities
            )

            inspectorState.mentorTraceReady = true
            inspectorState.mentorTraceStatus = "Mentor kaydı hazır • GitHub'a gönderilebilir"
            log("Mentor trace yerel olarak kaydedildi")
        } catch {
            inspectorState.mentorTraceReady = false
            inspectorState.mentorTraceStatus =
                "Mentor kaydı oluşturulamadı: " +
                error.localizedDescription
            log(inspectorState.mentorTraceStatus)
        }
    }

    func runTrainingLab() {
        guard !inspectorState.trainingLabBusy else { return }

        inspectorState.trainingLabBusy = true
        inspectorState.trainingLabStatus = "Simülasyon tabanlı temel yeterlilik testleri çalışıyor • fiziksel eylem uygulanmaz."
        log("Training Lab başladı • simulation-only")

        Task {
            await Task.yield()

            let report = trainingLab.run()
            inspectorState.trainingLabReport = report

            do {
                try trainingLabStore.save(report)

                inspectorState.trainingLabStatus =
                    "\(report.passed)/\(report.total) test geçti • " +
                    "Core \(report.corePassed)/\(report.coreTotal) • " +
                    "North Star \(report.northStarPassed)/\(report.northStarTotal)"

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Training Lab raporu hazır • Mentora gönderilebilir"

                log(
                    "Training Lab tamamlandı: " +
                    String(report.passed) +
                    "/" +
                    String(report.total)
                )

                let failedScenarios = report.results.filter {
                    !$0.passed
                }

                for failed in failedScenarios {
                    let detail = failed.diagnostics.isEmpty
                        ? "Tanı ayrıntısı yok"
                        : failed.diagnostics.joined(separator: " | ")

                    log(
                        "Training Lab FAIL [\(failed.scenarioID)]: " +
                        failed.title +
                        " • " +
                        detail
                    )
                }
            } catch {
                inspectorState.trainingLabStatus =
                    "Training Lab tamamlandı fakat rapor kaydedilemedi: " +
                    error.localizedDescription

                log("Training Lab raporu kaydedilemedi")
            }

            inspectorState.trainingLabBusy = false
        }
    }

    func runLiveResearchEval() {
        guard !inspectorState.liveResearchEvalBusy else { return }

        inspectorState.liveResearchEvalBusy = true
        inspectorState.liveResearchEvalStatus =
            "Gerçek internet araştırma kalitesi test ediliyor…"
        log("Live Research Eval başladı")

        Task {
            let report = await liveResearchEval.run()
            inspectorState.liveResearchEvalReport = report

            do {
                try liveResearchEvalStore.save(report)

                inspectorState.liveResearchEvalStatus =
                    "\(report.passed)/\(report.total) gerçek araştırma testi geçti"

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Live Research Eval raporu hazır • Mentora gönderilebilir"

                log(
                    "Live Research Eval tamamlandı: " +
                    String(report.passed) +
                    "/" +
                    String(report.total)
                )
            } catch {
                inspectorState.liveResearchEvalStatus =
                    "Live Research Eval tamamlandı fakat rapor kaydedilemedi: " +
                    error.localizedDescription

                log("Live Research Eval raporu kaydedilemedi")
            }

            inspectorState.liveResearchEvalBusy = false
        }
    }

    func runArena() {
        guard !inspectorState.arenaBusy else { return }

        inspectorState.arenaBusy = true
        inspectorState.arenaStatus =
            "Planner + reviewer simülasyonu çalışıyor • fiziksel eylem uygulanmaz."
        log("KRALİ Arena başladı • simulation-only")

        Task {
            let monitor = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, self.inspectorState.arenaBusy else {
                        break
                    }

                    if let progress =
                        self.arenaStore.readProgress(),
                       !progress.isEmpty {
                        self.inspectorState.arenaStatus = progress
                    }

                    try? await Task.sleep(
                        for: .milliseconds(400)
                    )
                }
            }

            let report = await arena.run()
            monitor.cancel()

            inspectorState.arenaReport = report

            do {
                try arenaStore.save(report)

                inspectorState.arenaStatus =
                    "\(report.passed)/\(report.total) geçti • " +
                    "\(report.failed) başarısız • " +
                    "Reviewer \(report.reviewerFlagged) işaret"

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Arena raporu hazır • Mentora gönderilebilir"

                log(
                    "KRALİ Arena tamamlandı: " +
                    String(report.passed) +
                    "/" +
                    String(report.total) +
                    " • Reviewer işaret: " +
                    String(report.reviewerFlagged)
                )

                for result in report.results where
                    !result.passed ||
                    result.reviewerPassed == false ||
                    !result.reviewerMissingCapabilityIDs.isEmpty ||
                    !result.reviewerUnnecessaryCapabilityIDs.isEmpty ||
                    !result.reviewerRiskNotes.isEmpty {
                    var detail = result.diagnostics
                    if let summary = result.reviewerSummary,
                       !summary.isEmpty {
                        detail.append(
                            "Reviewer: " + summary
                        )
                    }

                    if !result.reviewerMissingCapabilityIDs.isEmpty {
                        detail.append(
                            "Reviewer eksik: " +
                            result.reviewerMissingCapabilityIDs
                                .joined(separator: ", ")
                        )
                    }

                    if !result.reviewerUnnecessaryCapabilityIDs.isEmpty {
                        detail.append(
                            "Reviewer gereksiz: " +
                            result.reviewerUnnecessaryCapabilityIDs
                                .joined(separator: ", ")
                        )
                    }

                    if !result.reviewerRiskNotes.isEmpty {
                        detail.append(
                            "Reviewer risk notu: " +
                            result.reviewerRiskNotes
                                .joined(separator: " • ")
                        )
                    }

                    log(
                        "Arena REVIEW [\(result.scenarioID)] " +
                        result.plannerProvider +
                        " • " +
                        (detail.isEmpty
                            ? "Ek tanı yok"
                            : detail.joined(separator: " | "))
                    )
                }
            } catch {
                inspectorState.arenaStatus =
                    "Arena tamamlandı fakat rapor kaydedilemedi: " +
                    error.localizedDescription
                log("Arena raporu kaydedilemedi")
            }

            inspectorState.arenaBusy = false

            let arenaNeedsDevelopment =
                report.failed > 0 ||
                report.reviewerFlagged > 0

            let currentAppVersion =
                Bundle.main.object(
                    forInfoDictionaryKey:
                        "CFBundleShortVersionString"
                ) as? String ?? "unknown"

            let arenaCurrent =
                report.appVersion ==
                    currentAppVersion

            let trainingGreen =
                arenaCurrent &&
                inspectorState.trainingLabReport?.failed == 0 &&
                inspectorState.trainingLabReport?.appVersion ==
                    currentAppVersion

            let liveGreen =
                arenaCurrent &&
                inspectorState.liveResearchEvalReport?.failed == 0 &&
                inspectorState.liveResearchEvalReport?.appVersion ==
                    currentAppVersion

            if arenaNeedsDevelopment &&
               trainingGreen &&
               liveGreen &&
               !inspectorState.developerAgentBusy {
                log(
                    "Arena açık-dünya problemi buldu; Developer Agent candidate düzeltme için otomatik başlatılıyor"
                )
                runDeveloperAgent()
            } else if !arenaCurrent ||
                      !trainingGreen ||
                      !liveGreen {
                let staleStatus =
                    DeveloperAgentStatus(
                        state: "stale_diagnostics",
                        message:
                            "Developer kararı için güncel sürüm diagnostic'leri gerekli. App: " +
                            currentAppVersion +
                            " • Arena: " +
                            report.appVersion +
                            " • Training: " +
                            (inspectorState.trainingLabReport?.appVersion ?? "yok") +
                            " • Live: " +
                            (inspectorState.liveResearchEvalReport?.appVersion ?? "yok"),
                        branch: nil,
                        worktree: nil
                    )

                inspectorState.developerAgentStatus = staleStatus
                developerBridge.writeStatus(
                    staleStatus
                )
                log(
                    "Developer Agent no_change kapısı reddedildi: diagnostic sürümleri güncel değil"
                )
            } else if !arenaNeedsDevelopment &&
                      !inspectorState.developerAgentBusy {
                let greenStatus =
                    DeveloperAgentStatus(
                        state: "no_change",
                        message:
                            "Training, Live Research ve Arena güncel sürümde yeşil; candidate değişiklik gerekmiyor.",
                        branch: nil,
                        worktree: nil
                    )

                inspectorState.developerAgentStatus = greenStatus
                developerBridge.writeStatus(
                    greenStatus
                )
            }
        }
    }

    func runScreenPerceptionProbe() {
        guard !inspectorState.screenPerceptionBusy else { return }

        inspectorState.screenPerceptionBusy = true
        inspectorState.screenPerceptionStatus =
            "Ekran yakalanıyor ve yerel olarak analiz ediliyor…"
        screenPerceptionStore.saveStatus(
            "running|Ekran yakalanıyor ve yerel olarak analiz ediliyor…"
        )
        log("Screen Perception Probe başladı")

        Task {
            do {
                let report =
                    try await screenPerception.observe(
                        goal:
                            "Aktif ekrandaki uygulama durumunu, görünen ana içeriği ve güvenilir doğrulama sinyallerini açıkla."
                    )

                inspectorState.screenPerceptionReport = report
                try screenPerceptionStore.save(report)

                inspectorState.screenPerceptionStatus =
                    String(report.recognizedText.count) +
                    " metin satırı • " +
                    String(report.visibleWindows.count) +
                    " pencere • probe başarılı"

                screenPerceptionStore.saveStatus(
                    "success|" +
                    String(report.recognizedText.count) +
                    " metin satırı|" +
                    String(report.visibleWindows.count) +
                    " pencere"
                )

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Screen Perception raporu hazır • Mentora gönderilebilir"

                log(
                    "Screen Perception Probe tamamlandı: " +
                    String(report.pixelWidth) +
                    "×" +
                    String(report.pixelHeight) +
                    " • " +
                    String(report.recognizedText.count) +
                    " metin satırı"
                )
            } catch {
                inspectorState.screenPerceptionStatus =
                    "Screen Perception başarısız: " +
                    error.localizedDescription

                screenPerceptionStore.saveStatus(
                    "failed|" +
                    error.localizedDescription
                )

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Screen Perception hata raporu hazır • Mentora gönderilebilir"

                registerDebugIncident(
                    source: "perception.screen",
                    message: inspectorState.screenPerceptionStatus,
                    evidence: error.localizedDescription,
                    progress: .investigating
                )

                log(inspectorState.screenPerceptionStatus)
            }

            inspectorState.screenPerceptionBusy = false
        }
    }

    func runDesktopControlProbe() {
        guard
            !inspectorState.desktopControlBusy,
            pendingDeveloperToolApproval == nil
        else {
            return
        }

        guard
            developerToolSafetyPolicy
                .requiresApproval(
                    .desktopControlProbe
                )
        else {
            executeDesktopControlProbe()
            return
        }

        pendingDeveloperToolApproval =
            PendingDeveloperToolApproval(
                action:
                    .desktopControlProbe,
                title:
                    "Desktop Control Probe",
                reason:
                    "Bu test Notlar uygulamasını gerçekten açacak veya öne getirecek ve foreground durumunu doğrulayacak.",
                targetSummary:
                    "Notes • com.apple.Notes • /System/Applications/Notes.app"
            )

        inspectorState.desktopControlStatus =
            "Onay bekleniyor • Notlar henüz açılmadı."
        log(
            "Developer Tool approval gate: Desktop Control Probe"
        )
    }

    private func executeDesktopControlProbe() {
        guard !inspectorState.desktopControlBusy else { return }

        inspectorState.desktopControlBusy = true
        inspectorState.desktopControlStatus =
            "Accessibility kontrol ediliyor; Notlar güvenli test için açılıp doğrulanıyor…"
        desktopControlStore.saveStatus(
            "running|Accessibility kontrolü ve uygulama açma testi çalışıyor."
        )
        log("Desktop Control Probe başladı")

        Task {
            do {
                let report =
                    try await desktopControl
                        .probeOpenApplication(
                            named: "Notlar",
                            preferredBundleIdentifier:
                                "com.apple.Notes"
                        )

                inspectorState.desktopControlReport = report
                try desktopControlStore.save(report)

                inspectorState.desktopControlStatus =
                    (report.launchOrActivateSucceeded
                        ? "Notlar açıldı/öne geldi"
                        : "Notlar doğrulanamadı") +
                    " • AX " +
                    (report.accessibilityTrusted
                        ? "izinli"
                        : "izin bekliyor") +
                    " • Screen " +
                    (report.screenVerifiedFrontmost
                        ? "doğrulandı"
                        : "doğrulanamadı")

                desktopControlStore.saveStatus(
                    "success|" +
                    "activate=" +
                    String(report.launchOrActivateSucceeded) +
                    "|ax=" +
                    String(report.accessibilityTrusted) +
                    "|screen=" +
                    String(report.screenVerifiedFrontmost)
                )

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Desktop Control probe raporu hazır • Mentora gönderilebilir"

                log(
                    "Desktop Control Probe tamamlandı: " +
                    inspectorState.desktopControlStatus
                )
            } catch {
                inspectorState.desktopControlStatus =
                    "Desktop Control başarısız: " +
                    error.localizedDescription

                desktopControlStore.saveStatus(
                    "failed|" +
                    error.localizedDescription
                )

                inspectorState.mentorTraceReady = true
                inspectorState.mentorTraceStatus =
                    "Desktop Control hata raporu hazır • Mentora gönderilebilir"

                registerDebugIncident(
                    source: "desktop.app",
                    message: inspectorState.desktopControlStatus,
                    evidence: error.localizedDescription,
                    progress: .investigating
                )

                log(inspectorState.desktopControlStatus)
            }

            inspectorState.desktopControlBusy = false
        }
    }

    private func startNextLearningJobIfNeeded() {
        guard
            !inspectorState.developerAgentBusy,
            pendingDeveloperToolApproval == nil
        else {
            return
        }

        let liveDeveloperStatus =
            developerBridge
                .readStatus()
                .freshForApp(
                    currentAppVersionString
                )

        if liveDeveloperStatus
            .isLearningActive {
            inspectorState
                .developerAgentStatus =
                liveDeveloperStatus
            return
        }

        guard let next =
            learningQueueStore.nextQueued(
                from: inspectorState.learningQueueJobs
            )
        else {
            return
        }

        guard let briefURL =
            learningQueueStore
                .materializeBrief(
                    for: next
                )
        else {
            if let index =
                inspectorState.learningQueueJobs.firstIndex(
                    where: {
                        $0.id == next.id
                    }
                ) {
                inspectorState.learningQueueJobs[index]
                    .state = .failed
                inspectorState.learningQueueJobs[index]
                    .updatedAt = Date()
                inspectorState.learningQueueJobs[index]
                    .lastStatus =
                        "Immutable öğrenme brief'i oluşturulamadı."
                learningQueueStore.save(
                    inspectorState.learningQueueJobs
                )
            }

            log(
                "Learning Queue brief oluşturulamadı: " +
                next.capabilityID
            )
            return
        }

        if let index =
            inspectorState.learningQueueJobs.firstIndex(
                where: {
                    $0.id == next.id
                }
            ) {
            inspectorState.learningQueueJobs[index]
                .state = .running
            inspectorState.learningQueueJobs[index]
                .updatedAt = Date()
            inspectorState.learningQueueJobs[index]
                .lastStatus =
                    "Developer Agent worker'a verildi."
            learningQueueStore.save(
                inspectorState.learningQueueJobs
            )
        }

        activeLearningJobID = next.id

        log(
            "Learning Queue worker başlatılıyor • " +
            next.capabilityID +
            " • " +
            (
                next.learningPath?
                    .title ??
                "Öğrenme"
            ) +
            " • job=" +
            next.shortID
        )

        runDeveloperAgent(
            learningJob: next,
            learningJobBriefURL:
                briefURL
        )
    }

    func runDeveloperAgent(
        learningJob: AgentLearningJob? = nil,
        learningJobBriefURL: URL? = nil,
        developerTask: AgentDeveloperTaskDescriptor? = nil,
        approvedSystemEffect: String? = nil
    ) {
        guard !inspectorState.developerAgentBusy else {
            if let learningJob {
                log(
                    "Developer Agent meşgul; job sırada kalıyor • " +
                    learningJob.shortID
                )
            }
            return
        }

        let liveDeveloperStatus =
            developerBridge
                .readStatus()
                .freshForApp(
                    currentAppVersionString
                )

        if liveDeveloperStatus
            .isLearningActive {
            inspectorState
                .developerAgentStatus =
                liveDeveloperStatus

            if let learningJob {
                log(
                    "Aktif Developer Agent run'ı korunuyor; yeni job sırada kalıyor • " +
                    learningJob.shortID +
                    " • run=" +
                    (
                        liveDeveloperStatus
                            .runID ??
                        "unknown"
                    )
                )
            } else {
                log(
                    "Developer Agent zaten aktif • run=" +
                    (
                        liveDeveloperStatus
                            .runID ??
                        "unknown"
                    )
                )
            }
            return
        }

        inspectorState.developerAgentBusy = true

        let initialMessage: String
        if let developerTask {
            initialMessage =
                developerTask.title +
                " • kontrollü developer görevi başlatılıyor"
        } else if let learningJob {
            let pathTitle =
                learningJob.learningPath?
                    .title ??
                "Öğrenme"

            initialMessage =
                learningJob.capabilityName +
                " • " +
                pathTitle +
                " başlatılıyor • job=" +
                learningJob.shortID
        } else {
            initialMessage =
                "Developer Agent diagnostic'leri inceliyor…"
        }

        inspectorState.developerAgentStatus =
            DeveloperAgentStatus(
                state: "running",
                message:
                    initialMessage,
                branch: nil,
                worktree: nil
            )

        developerBridge.writeStatus(
            inspectorState.developerAgentStatus
        )

        log(
            developerTask != nil
                ? "Developer Agent kontrollü task başlatıldı • " +
                    (developerTask?.id ?? "unknown")
                : (
                    learningJob == nil
                        ? "Developer Agent başlatıldı"
                        : "Developer Agent Learning Queue job'u başlatıldı"
                  )
        )

        Task {
            let monitor = Task {
                @MainActor [weak self] in

                while !Task.isCancelled {
                    guard
                        let self,
                        self.inspectorState.developerAgentBusy
                    else {
                        break
                    }

                    let liveStatus =
                        self.developerBridge
                            .readStatus()

                    if liveStatus.state != "idle" {
                        self.inspectorState.developerAgentStatus =
                            liveStatus

                        self.updateRunningLearningJob(
                            with: liveStatus
                        )

                        if liveStatus.state ==
                            "repairing_cline" ||
                           liveStatus.state ==
                            "repairing_runtime" ||
                           liveStatus.state ==
                            "provider_platform_bug" ||
                           liveStatus.state ==
                            "sdk_fallback_preparing" ||
                           liveStatus.state ==
                            "sdk_fallback_running" {
                            self.registerDebugIncident(
                                source:
                                    "Developer Agent",
                                message:
                                    liveStatus.message,
                                evidence:
                                    liveStatus.state,
                                progress:
                                    .recovering
                            )
                        }
                    }

                    try? await Task.sleep(
                        for: .milliseconds(
                            700
                        )
                    )
                }
            }

            let status =
                await developerBridge.run(
                    learningJobBriefURL:
                        learningJobBriefURL,
                    developerTaskURL:
                        developerTask?.url,
                    approvedSystemEffect:
                        approvedSystemEffect
                )

            monitor.cancel()

            inspectorState.developerAgentStatus =
                status
            inspectorState.developerAgentBusy =
                false

            if status.state ==
                "system_action_approval_required" {
                let request =
                    developerSystemEffectRequest(
                        from:
                            status.message
                    )

                pauseActiveLearningJobForDeveloperApproval(
                    DeveloperAgentStatus(
                        state:
                            status.state,
                        message:
                            request.reason,
                        branch:
                            status.branch,
                        worktree:
                            status.worktree,
                        appVersion:
                            status.appVersion,
                        updatedAt:
                            status.updatedAt,
                        runID:
                            status.runID
                    )
                )

                pendingDeveloperLearningJob =
                    learningJob
                pendingDeveloperLearningJobBriefURL =
                    learningJobBriefURL
                pendingDeveloperTask =
                    developerTask

                if developerToolSafetyPolicy
                    .requiresApproval(
                        .developerSystemEffects
                    ) {
                    pendingDeveloperToolApproval =
                        PendingDeveloperToolApproval(
                            action:
                                .developerSystemEffects,
                            title:
                                "Developer Agent sistem işlemi",
                            reason:
                                request.reason,
                            targetSummary:
                                developerSystemEffectTargetSummary(
                                    request.token
                                ),
                            approvalToken:
                                request.token
                        )
                }

                log(
                    "Developer Tool approval gate: " +
                    request.token +
                    " • " +
                    request.reason
                )
                return
            }

            finishActiveLearningJob(
                with: status
            )

            switch status.state {
            case "ready_for_review",
                 "recovered_candidate_ready":
                if let developerTask {
                    postAssistantMessage(
                        developerTask.title +
                        " geliştirici görevi tamamlandı ve candidate incelemeye hazır. Mentor Sync sonrası review edilebilir."
                    )
                }
                resolveDebugIncident(
                    summary:
                        "Developer Agent recovery/öğrenme adayını build doğrulamasından geçirdi."
                )
                log(
                    "Developer Agent adayı incelemeye hazır: " +
                    (status.branch ??
                        "branch bilinmiyor")
                )

            case "no_change":
                resolveDebugIncident(
                    summary:
                        "Diagnostic recovery gerektirmedi; mevcut sistem sağlıklı."
                )
                log(
                    "Developer Agent değişiklik gerekmedi sonucuna vardı"
                )

            case "setup_required",
                 "setup_node",
                 "setup_homebrew",
                 "setup_node_upgrade",
                 "setup_node_supported",
                 "setup_cline",
                 "setup_cline_repair",
                 "setup_cline_auth",
                 "setup_local_ai":
                registerDebugIncident(
                    source: "Developer Agent",
                    message: status.message,
                    evidence: status.state,
                    progress: .escalated
                )
                log(
                    "Developer Agent kurulumu/recovery tamamlanmalı"
                )

            case "build_failed",
                 "recovered_candidate_build_failed":
                registerDebugIncident(
                    source: "Developer Agent",
                    message: status.message,
                    evidence: status.branch,
                    progress: .escalated
                )
                log(
                    "Developer Agent adayı build geçmedi: " +
                    (status.branch ??
                        "branch bilinmiyor")
                )

            case "failed",
                 "sdk_failed",
                 "sdk_watchdog_timeout",
                 "sdk_tool_protocol_failed",
                 "local_tool_probe_failed",
                 "local_storage_low",
                 "local_agent_failed",
                 "local_agent_tool_protocol_failed",
                 "local_agent_iteration_limit",
                 "local_agent_watchdog_timeout",
                 "local_ai_failed",
                 "local_model_failed",
                 "no_change_unverified",
                 "candidate_recovery_failed":
                registerDebugIncident(
                    source: "Developer Agent",
                    message: status.message,
                    evidence: status.state,
                    exitCode:
                        status.message
                            .contains("137")
                            ? 137
                            : nil,
                    progress: .escalated
                )
                log(
                    "Developer Agent durumu: " +
                    status.message
                )

            default:
                log(
                    "Developer Agent durumu: " +
                    status.message
                )
            }

            startNextLearningJobIfNeeded()
        }
    }

    private func developerSystemEffectRequest(
        from raw: String
    ) -> (
        token: String,
        reason: String
    ) {
        if let separatorRange =
            raw.range(
                of: "@@"
            ) {
            let token =
                String(
                    raw[..<separatorRange.lowerBound]
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            let reason =
                String(
                    raw[separatorRange.upperBound...]
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if !token.isEmpty {
                return (
                    token,
                    reason.isEmpty
                        ? "Developer Agent sistem etkisi oluşturan bir adım çalıştırmak istiyor."
                        : reason
                )
            }
        }

        return (
            "developer-system-effect",
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
                ? "Developer Agent sistem etkisi oluşturan bir adım çalıştırmak istiyor."
                : raw
        )
    }

    private func developerSystemEffectTargetSummary(
        _ token: String
    ) -> String {
        if token.hasPrefix(
            "ollama-model-pull:"
        ) {
            let model =
                String(
                    token.dropFirst(
                        "ollama-model-pull:".count
                    )
                )

            return
                "Ollama modeli • " +
                model
        }

        switch token {
        case "brew-install-node22":
            return "Homebrew • Node.js 22 kurulumu"
        case "brew-upgrade-ollama":
            return "Homebrew • Ollama güncellemesi + servis yeniden başlatma"
        case "brew-install-ollama":
            return "Homebrew • Ollama kurulumu"
        case "ollama-service-start":
            return "Yerel servis • Ollama serve"
        case "cline-repair-global":
            return "Cline CLI • doctor fix / global npm onarımı"
        case "cline-auth-terminal":
            return "Terminal • Cline/OpenAI kimlik doğrulama akışı"
        case "cline-sdk-local-install":
            return "KRALİ Developer çalışma alanı • @cline/sdk kurulumu"
        default:
            return "Developer sistem adımı • " + token
        }
    }

    func approvePendingDeveloperToolApproval() {
        guard let approval =
            pendingDeveloperToolApproval
        else {
            return
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text:
                    "Onaylıyorum: " +
                    approval.title
            )
        )

        pendingDeveloperToolApproval = nil

        switch approval.action {
        case .desktopControlProbe:
            executeDesktopControlProbe()

        case .developerSystemEffects:
            let learningJob =
                pendingDeveloperLearningJob
            let briefURL =
                pendingDeveloperLearningJobBriefURL
            let developerTask =
                pendingDeveloperTask

            pendingDeveloperLearningJob = nil
            pendingDeveloperLearningJobBriefURL = nil
            pendingDeveloperTask = nil

            resumeActiveLearningJobAfterDeveloperApproval()

            runDeveloperAgent(
                learningJob:
                    learningJob,
                learningJobBriefURL:
                    briefURL,
                developerTask:
                    developerTask,
                approvedSystemEffect:
                    approval.approvalToken
            )
        }

        log(
            "Developer Tool approval kullanıcı tarafından onaylandı • " +
            approval.action.rawValue
        )
    }

    func cancelPendingDeveloperToolApproval() {
        guard let approval =
            pendingDeveloperToolApproval
        else {
            return
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text:
                    "İptal: " +
                    approval.title
            )
        )

        pendingDeveloperToolApproval = nil

        switch approval.action {
        case .desktopControlProbe:
            inspectorState.desktopControlStatus =
                "İptal edildi • fiziksel uygulama açma testi çalıştırılmadı."

        case .developerSystemEffects:
            let rejectedDeveloperTask =
                pendingDeveloperTask

            requeueActiveLearningJobAfterDeveloperApprovalRejection(
                approval.reason
            )
            pendingDeveloperLearningJob = nil
            pendingDeveloperLearningJobBriefURL = nil
            pendingDeveloperTask = nil

            let rejectedStatus =
                DeveloperAgentStatus(
                    state:
                        "system_action_rejected",
                    message:
                        rejectedDeveloperTask == nil
                            ? "Kullanıcı sistem etkisi oluşturan Developer Agent adımını onaylamadı. Öğrenme işi capability failure sayılmadan sırada tutuluyor."
                            : "Kullanıcı sistem etkisi oluşturan Developer Agent adımını onaylamadı. Kontrollü geliştirici görevi herhangi bir fiziksel/sistem işlemi uygulanmadan durduruldu.",
                    branch: nil,
                    worktree: nil,
                    appVersion:
                        currentAppVersionString,
                    updatedAt:
                        Date()
                )

            inspectorState.developerAgentStatus =
                rejectedStatus
            developerBridge.writeStatus(
                rejectedStatus
            )
        }

        postAssistantMessage(
            "İşlemi iptal ettim. Developer aracının fiziksel/sistem etkisi oluşturan adımı uygulanmadı."
        )

        log(
            "Developer Tool approval kullanıcı tarafından reddedildi • " +
            approval.action.rawValue
        )
    }

    private func pauseActiveLearningJobForDeveloperApproval(
        _ status: DeveloperAgentStatus
    ) {
        guard
            let activeLearningJobID,
            let index =
                inspectorState.learningQueueJobs
                    .firstIndex(
                        where: {
                            $0.id ==
                                activeLearningJobID
                        }
                    )
        else {
            return
        }

        inspectorState.learningQueueJobs[index]
            .state = .queued
        inspectorState.learningQueueJobs[index]
            .updatedAt = Date()
        inspectorState.learningQueueJobs[index]
            .lastStatus =
                "Sistem işlemi için kullanıcı onayı bekleniyor: " +
                status.message

        learningQueueStore.save(
            inspectorState.learningQueueJobs
        )
    }

    private func resumeActiveLearningJobAfterDeveloperApproval() {
        guard
            let activeLearningJobID,
            let index =
                inspectorState.learningQueueJobs
                    .firstIndex(
                        where: {
                            $0.id ==
                                activeLearningJobID
                        }
                    )
        else {
            return
        }

        inspectorState.learningQueueJobs[index]
            .state = .running
        inspectorState.learningQueueJobs[index]
            .updatedAt = Date()
        inspectorState.learningQueueJobs[index]
            .lastStatus =
                "Kullanıcı sistem işlemini onayladı; Developer Agent devam ediyor."

        learningQueueStore.save(
            inspectorState.learningQueueJobs
        )
    }

    private func requeueActiveLearningJobAfterDeveloperApprovalRejection(
        _ reason: String
    ) {
        guard
            let activeLearningJobID,
            let index =
                inspectorState.learningQueueJobs
                    .firstIndex(
                        where: {
                            $0.id ==
                                activeLearningJobID
                        }
                    )
        else {
            self.activeLearningJobID = nil
            return
        }

        inspectorState.learningQueueJobs[index]
            .state = .queued
        inspectorState.learningQueueJobs[index]
            .updatedAt = Date()
        inspectorState.learningQueueJobs[index]
            .lastStatus =
                "Kullanıcı sistem işlemini onaylamadı; fiziksel adım uygulanmadı ve öğrenme işi capability failure sayılmadan sırada tutuluyor: " +
                reason

        learningQueueStore.save(
            inspectorState.learningQueueJobs
        )

        self.activeLearningJobID = nil
    }

    private func updateRunningLearningJob(
        with status: DeveloperAgentStatus
    ) {
        guard
            let activeLearningJobID,
            let index =
                inspectorState.learningQueueJobs
                    .firstIndex(
                        where: {
                            $0.id ==
                                activeLearningJobID
                        }
                    )
        else {
            return
        }

        inspectorState.learningQueueJobs[index]
            .updatedAt = Date()
        inspectorState.learningQueueJobs[index]
            .branch = status.branch
        inspectorState.learningQueueJobs[index]
            .worktree = status.worktree
        inspectorState.learningQueueJobs[index]
            .lastStatus = status.message

        learningQueueStore.save(
            inspectorState.learningQueueJobs
        )
    }

    private func finishActiveLearningJob(
        with status: DeveloperAgentStatus
    ) {
        guard
            let activeLearningJobID,
            let index =
                inspectorState.learningQueueJobs
                    .firstIndex(
                        where: {
                            $0.id ==
                                activeLearningJobID
                        }
                    )
        else {
            self.activeLearningJobID =
                nil
            return
        }

        let state:
            AgentLearningJobState

        switch status.state {
        case "ready_for_review",
             "recovered_candidate_ready":
            state = .readyForReview

        case "no_change":
            state = .completed

        default:
            state = .failed
        }

        inspectorState.learningQueueJobs[index]
            .state = state
        inspectorState.learningQueueJobs[index]
            .updatedAt = Date()
        inspectorState.learningQueueJobs[index]
            .branch = status.branch
        inspectorState.learningQueueJobs[index]
            .worktree = status.worktree
        inspectorState.learningQueueJobs[index]
            .lastStatus = status.message

        learningQueueStore.save(
            inspectorState.learningQueueJobs
        )

        log(
            "Learning Queue job tamamlandı • " +
            inspectorState.learningQueueJobs[index]
                .capabilityID +
            " • " +
            state.title
        )

        self.activeLearningJobID =
            nil
    }

    private func registerDebugIncident(
        source: String,
        message: String,
        evidence: String? = nil,
        exitCode: Int? = nil,
        progress: AgentDebugProgress
    ) {
        let incident = debugRecoveryCenter.classify(
            source: source,
            message: message,
            evidence: evidence,
            exitCode: exitCode,
            progress: progress
        )

        inspectorState.debugIncident = incident

        log(
            "Debug/Recovery: " +
            incident.kind.title +
            " • " +
            incident.progress.title +
            " • " +
            incident.source
        )
    }

    private func resolveDebugIncident(
        summary: String
    ) {
        guard let incident = inspectorState.debugIncident else {
            return
        }

        inspectorState.debugIncident = debugRecoveryCenter.recovered(
            from: incident,
            summary: summary
        )

        log(
            "Debug/Recovery düzeldi: " +
            incident.source
        )
    }

    func syncMentorTrace() {
        guard !inspectorState.mentorSyncBusy else { return }

        guard !busy else {
            inspectorState.mentorTraceStatus =
                "Mevcut görev tamamlanmadan Mentor gönderilemez; eski Mentor kaydı gönderilmedi."
            return
        }

        let hasTrace = fileManager.fileExists(
            atPath: mentorTraceStore.latestURL.path
        )
        let hasTrainingReport = fileManager.fileExists(
            atPath: trainingLabStore.outputURL.path
        )
        let hasLiveEvalReport = fileManager.fileExists(
            atPath: liveResearchEvalStore.outputURL.path
        )

        guard hasTrace || hasTrainingReport || hasLiveEvalReport else {
            inspectorState.mentorTraceReady = false
            inspectorState.mentorTraceStatus =
                "Önce bir KRALİ görevi, Training Lab veya Live Research Eval çalıştır."
            return
        }

        let scriptPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent/Scripts/publish-mentor-trace.command"
            )
            .path

        guard fileManager.fileExists(atPath: scriptPath) else {
            inspectorState.mentorTraceStatus =
                "Mentor sync scripti bulunamadı. Önce uygulamayı güncelle."
            return
        }

        inspectorState.mentorSyncBusy = true
        inspectorState.mentorTraceStatus = "Mentor diagnostics GitHub'a aktarılıyor…"

        Task {
            let result = await Task.detached(
                priority: .utility
            ) {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(
                    fileURLWithPath: "/bin/zsh"
                )
                process.arguments = [scriptPath]
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()

                    let outputData =
                        outputPipe.fileHandleForReading
                            .readDataToEndOfFile()
                    let errorData =
                        errorPipe.fileHandleForReading
                            .readDataToEndOfFile()

                    process.waitUntilExit()

                    let output = String(
                        data: outputData,
                        encoding: .utf8
                    ) ?? ""
                    let errorOutput = String(
                        data: errorData,
                        encoding: .utf8
                    ) ?? ""

                    return (
                        Int(process.terminationStatus),
                        errorOutput.isEmpty
                            ? output
                            : output + "\n" + errorOutput
                    )
                } catch {
                    return (
                        -1,
                        error.localizedDescription
                    )
                }
            }
            .value

            inspectorState.mentorSyncBusy = false

            if result.0 == 0 {
                inspectorState.mentorTraceStatus =
                    "Mentor diagnostics GitHub'a aktarıldı • kaynak branch değiştirilmedi."
                log("Mentor trace GitHub'a senkronlandı")
            } else {
                let compact = result.1
                    .split(separator: "\n")
                    .suffix(3)
                    .joined(separator: " ")

                inspectorState.mentorTraceStatus =
                    "Mentor sync başarısız: " +
                    (compact.isEmpty
                        ? "çıkış kodu \(result.0)"
                        : compact)

                log("Mentor sync başarısız")
            }
        }
    }

    private func synthesisOutputMeetsGoal(
        userInput: String,
        goal: AgentGoalProfile,
        output: String
    ) -> Bool {
        let input = normalize(userInput)
        let response = normalize(output)

        if response.contains(
            "hedefi analiz ettim fakat mevcut yerel araclardan biriyle guvenilir bicimde eslestiremedim"
        ) ||
        response.contains(
            "su an en guvenli planim"
        ) {
            return false
        }

        if goal.outcomes.contains(.compose),
           containsAny(input, [
                "3 bölüm", "3 bolum"
           ]) {
            let hasRequestedSections =
                containsAny(response, ["açılış", "acilis"]) &&
                containsAny(response, ["ana mesaj", "ana bölüm", "ana bolum"]) &&
                containsAny(response, ["kapanış", "kapanis"])

            guard hasRequestedSections else {
                return false
            }
        }

        if containsAny(input, [
            "düzgün türkçeyle", "duzgun turkceyle",
            "yazım hatalarını düzelt", "yazim hatalarini duzelt",
            "metni düzelt", "metni duzelt"
        ]) {
            let knownErrors = [
                "şuan", "birşey", " yada ",
                "herkez", "kapanışda"
            ]

            if knownErrors.contains(
                where: { response.contains($0) }
            ) {
                return false
            }
        }

        guard goal.outcomes.contains(.transform) else {
            return true
        }

        if containsAny(input, [
            "senaryo", "senaryoya", "senaryosuna",
            "çekim plan", "cekim plan"
        ]) {
            let hasScenarioShape = containsAny(response, [
                "saniye", "sahne", "çekim", "cekim",
                "0-", "0–", "0 -", "0 –"
            ])

            guard hasScenarioShape else {
                return false
            }
        }

        let durationPattern = #"([0-9]{1,3})\s*saniye"#

        if let regex = try? NSRegularExpression(
            pattern: durationPattern
        ) {
            let range = NSRange(
                input.startIndex..<input.endIndex,
                in: input
            )

            if let match = regex.firstMatch(
                in: input,
                range: range
            ),
            let durationRange = Range(
                match.range(at: 1),
                in: input
            ) {
                let duration = String(
                    input[durationRange]
                )

                let hasRequestedDuration =
                    response.contains(duration + " saniye") ||
                    response.contains(duration + " saniyelik")

                let hasTimeline =
                    response.contains("0-") ||
                    response.contains("0–") ||
                    response.contains("0 -") ||
                    response.contains("0 –")

                if !hasRequestedDuration && !hasTimeline {
                    return false
                }
            }
        }

        return true
    }

    private func shouldUseIntelligence(
        goal: AgentGoalProfile,
        verification: AgentVerificationResult
    ) -> Bool {
        guard verification.state != .attention else {
            return false
        }

        if goal.outcomes.contains(.analyze) ||
           goal.outcomes.contains(.ideate) ||
           goal.outcomes.contains(.compose) ||
           goal.outcomes.contains(.transform) ||
           goal.outcomes.contains(.research) {
            return true
        }

        if goal.outcomes.contains(.explain) &&
           verification.state != .attention {
            return true
        }

        return false
    }

    private func appendSuggestion(
        to reply: String,
        suggestion: String?
    ) -> String {
        guard let suggestion, !suggestion.isEmpty else {
            return reply
        }

        return reply + "\n\nÖnerim: " + suggestion
    }

    private func conversationReply(for text: String) -> String {
        let t = normalize(text)

        if containsAny(t, ["nasılsın", "nasilsin", "naber", "ne haber"]) {
            if let root = selectedRootURL {
                return "İyiyim, hazırım. Şu an “\(root.lastPathComponent)” çalışma alanını hatırlıyorum ve \(indexedFiles.count) dosyayı yerel olarak görebiliyorum."
            }

            return "İyiyim, hazırım. Şu an aktif bir çalışma klasörü seçili değil; istersen bir alan seçip birlikte inceleyebiliriz."
        }

        if containsAny(t, ["ne yapıyorsun", "ne yapiyorsun"]) {
            if let root = selectedRootURL {
                return "Şu an “\(root.lastPathComponent)” çalışma alanını takip ediyorum. \(indexedFiles.count) dosya indeksli; yeni bir hedef verdiğinde önce ne istediğini analiz edip gerekli kabiliyetleri kendim seçeceğim."
            }

            return "Şu an yeni bir hedef bekliyorum. Bir görev verdiğinde önce hedefi ve bağlamı analiz edip gereken kabiliyetleri kendim seçeceğim."
        }

        return "Selam. Hazırım; sadece komut beklemek yerine hedefini anlamaya, seçenekleri düşünmeye ve uygun yolu seçmeye çalışacağım."
    }

    private func assessWorkspace() -> String {
        guard let root = selectedRootURL else {
            return "Önce bir çalışma klasörü seçmeliyim. Sonra hiçbir dosyayı değiştirmeden yapıyı inceleyip birkaç alternatif önerebilirim."
        }

        ensureWorkspaceIndexed()

        var observations: [String] = [
            "\(indexedFiles.count) dosya",
            "\(imageCount) görsel",
            "\(videoCount) video",
            "\(documentCount) belge",
            "\(projectCount) proje dosyası"
        ]

        if screenshotCount > 0 {
            observations.append("\(screenshotCount) ekran görüntüsü")
        }

        var ideas: [String] = []

        if screenshotCount >= 5 {
            ideas.append("Ekran görüntülerini ayrı klasöre toplamak düşük riskli ve geri alınabilir bir ilk adım.")
        }

        if videoCount > 0 {
            ideas.append("Videoları en yeni veya belirli bir tarihe göre ayırıp yalnızca ilgili çekimleri öne çıkarabilirim.")
        }

        if documentCount > 0 {
            ideas.append("Belgeleri tür veya tarihe göre gruplandırmadan önce sadece listeleyip dağınıklığın kaynağını gösterebilirim.")
        }

        if ideas.isEmpty {
            ideas.append("Şimdilik değişiklik yapmak yerine son eklenen dosyaları inceleyip en yararlı düzenleme adımını seçebiliriz.")
        }

        return "“\(root.lastPathComponent)” alanını inceledim: " +
            observations.joined(separator: ", ") +
            ".\n\nDüşündüğüm seçenekler:\n• " +
            ideas.joined(separator: "\n• ") +
            "\n\nDosyalarda değişiklik yapmadım."
    }

    // MARK: - File Selection & Indexing

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "KRALİ'nin çalışacağı klasörü seç"
        panel.message = "KRALİ bu sürümde gerçek dosya işlemlerini yalnızca seçtiğin klasörün doğrudan içindeki dosyalarda yapar."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        selectedRootURL = url
        UserDefaults.standard.set(url.path, forKey: selectedRootKey)
        pendingFileAction = nil
        lastUndoAction = nil
        workspaceIndexReady = false
        workspaceIndexUpdatedAt = nil
        indexSelectedFolder()

        log("Çalışma klasörü seçildi: \(url.lastPathComponent)")
    }

    func indexSelectedFolder() {
        guard let root = selectedRootURL else {
            workspaceIndexReady = false
            indexedFiles = []
            indexedFolders = []
            return
        }

        let snapshot = workspaceIndexer.index(
            root: root
        )

        indexedFiles = snapshot.files
        indexedFolders = snapshot.folders
        workspaceIndexReady = true
        workspaceIndexUpdatedAt = Date()

        if snapshot.reachedSafetyLimit {
            log(
                "İndeks güvenlik sınırına ulaştı: 5000 öğe"
            )
        }

        let screenshots =
            indexedFiles.filter(\.isScreenshot).count

        log(
            "\(indexedFiles.count) dosya ve " +
            "\(indexedFolders.count) klasör indekslendi"
        )
        log(
            "\(screenshots) ekran görüntüsü adayı bulundu"
        )
    }

    private func ensureWorkspaceIndexed() {
        guard selectedRootURL != nil else {
            return
        }

        if workspaceIndexReady,
           let workspaceIndexUpdatedAt,
           Date().timeIntervalSince(
                workspaceIndexUpdatedAt
           ) < workspaceIndexFreshness {
            return
        }

        indexSelectedFolder()
    }

    var screenshotCount: Int {
        indexedFiles.filter(\.isScreenshot).count
    }

    var imageCount: Int {
        let extensions = Set(["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "gif"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var videoCount: Int {
        let extensions = Set(["mov", "mp4", "m4v", "avi", "mkv", "webm", "mts", "m2ts"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var projectCount: Int {
        let extensions = Set(["prproj", "aep", "psd", "ai", "indd", "fcpxml"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    var documentCount: Int {
        let extensions = Set(["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "numbers", "key"])
        return indexedFiles.filter { extensions.contains($0.fileExtension) }.count
    }

    private func restoreSelectedFolder() {
        guard let path = UserDefaults.standard.string(forKey: selectedRootKey),
              !path.isEmpty else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            UserDefaults.standard.removeObject(forKey: selectedRootKey)
            return
        }

        selectedRootURL = URL(
            fileURLWithPath: path,
            isDirectory: true
        )
        workspaceIndexReady = false
        workspaceIndexUpdatedAt = nil
        indexedFiles = []
        indexedFolders = []
        log(
            "Çalışma klasörü yolu geri yüklendi; indeks gerektiğinde oluşturulacak: " +
            (selectedRootURL?.lastPathComponent ?? path)
        )
    }

    // MARK: - Local File Search

    func revealFile(_ file: FileRecord) {
        guard fileManager.fileExists(atPath: file.url.path) else {
            log("Finder'da gösterilemedi: dosya artık mevcut değil")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([file.url])
        log("Finder'da gösterildi: \(file.name)")
    }

    private func isFileSearchIntent(_ text: String) -> Bool {
        if fileQueryParser
            .parse(text)
            .isFileSearchRequest {
            return true
        }

        let actionWords = [
            "bul", "ara", "göster", "listele",
            "nerede", "hangileri", "hangi dosya"
        ]

        let fileWords = [
            "dosya", "pdf", "video", "görsel", "gorsel",
            "resim", "fotoğraf", "fotograf", "proje",
            "belge", "doküman", "dokuman", "logo",
            "ekran görünt", "ekran gorunt", "ekran resmi"
        ]

        return containsAny(text, actionWords) && containsAny(text, fileWords)
    }

    func revealFolder(_ folder: FolderRecord) {
        guard fileManager.fileExists(atPath: folder.url.path) else {
            log("Finder'da gösterilemedi: klasör artık mevcut değil")
            return
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.url.path)
        log("Finder'da klasör açıldı: \(folder.name)")
    }

    private func executeCompoundFileTask(
        for rawText: String,
        decision: AgentDecision
    ) -> String {
        let parsedQuery =
            fileQueryParser.parse(
                rawText
            )

        if !parsedQuery.scopeIsExplicit,
           selectedRootURL == nil {
            fileSearchResults = []
            return "Bu çok adımlı görevde konum belirtilmediği için önce bir varsayılan çalışma klasörü seçmeliyim."
        }

        if parsedQuery.scopeIsExplicit {
            log(
                "Compound File Task explicit scope kullanıyor • " +
                parsedQuery.scope.title +
                " • selectedWorkspace override edilmedi"
            )
        }

        let searchDecision = AgentDecision(
            intent: .fileSearch,
            target: decision.target,
            dateRange: decision.dateRange,
            dateField: decision.dateField,
            sortMode: decision.sortMode,
            route: decision.route + ["Search"],
            goal: decision.goal,
            selectedPlan: "Zincirin ilk adımı olarak hedef dosyaları salt-okunur bul.",
            alternatives: decision.alternatives,
            proactiveSuggestion: nil,
            usePreviousResults: decision.usePreviousResults,
            resultSelection: nil
        )

        log("Zincir 1/3: hedef dosyalar aranıyor")
        let searchReply = searchIndexedFiles(
            for: rawText,
            decision: searchDecision
        )

        guard !fileSearchResults.isEmpty else {
            log("Zincir durdu: arama sonucu yok")
            return searchReply
        }

        log("Zincir 2/3: adaylar kısa listeye indiriliyor")

        var candidates = fileSearchResults

        if decision.sortMode == .newestFirst {
            candidates.sort {
                let left = $0.modificationDate ?? $0.creationDate ?? .distantPast
                let right = $1.modificationDate ?? $1.creationDate ?? .distantPast
                return left > right
            }
        }

        let shortlistCount = min(3, candidates.count)
        candidates = Array(candidates.prefix(shortlistCount))
        fileSearchResults = candidates
        fileSearchTitle = "KRALİ kısa liste • \(decision.goal)"

        log("Zincir 3/3: kısa liste mevcut metadata ile değerlendiriliyor")

        let lines = candidates.enumerated().map { index, file in
            let date = file.modificationDate ?? file.creationDate
            let dateText: String

            if let date {
                dateText = date.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            } else {
                dateText = "tarih bilinmiyor"
            }

            return "\(index + 1). \(file.name) • .\(file.fileExtension) • \(dateText)"
        }
        .joined(separator: "\n")

        let text = normalize(rawText)
        let asksForSuitability = containsAny(text, [
            "uygun", "değerlendir", "degerlendir",
            "hangileri", "hangisi", "öner", "oner"
        ])

        if asksForSuitability {
            return "Adayları buldum ve kısa listeyi \(shortlistCount) öğeye indirdim.\n\n\(lines)\n\nŞu an yapabildiğim ön seçim dosya türü ve oluşturma/değiştirilme zamanı gibi metadata'ya dayanıyor. Görüntü içeriği, netlik, kadraj, hareket ve ses analizi henüz bağlı olmadığı için “kurguya en uygun” aday konusunda kesin içerik değerlendirmesi yapmıyorum. Bu kısa liste, sonraki görsel analiz katmanı için doğru başlangıç kümesi."
        }

        return "Hedefleri buldum ve \(shortlistCount) adaylık kısa liste oluşturdum.\n\n\(lines)"
    }

    private func openPreviousResult(
        selection: AgentResultSelection?
    ) -> String {
        if !fileSearchResults.isEmpty {
            let file: FileRecord
            switch selection ?? .first {
            case .first:
                file = fileSearchResults[0]
            case .last:
                file = fileSearchResults[fileSearchResults.count - 1]
            }

            revealFile(file)
            return "Önceki sonuçlardan “\(file.name)” dosyasını Finder'da gösterdim."
        }

        if !folderSearchResults.isEmpty {
            let folder: FolderRecord
            switch selection ?? .first {
            case .first:
                folder = folderSearchResults[0]
            case .last:
                folder = folderSearchResults[folderSearchResults.count - 1]
            }

            revealFolder(folder)
            return "Önceki sonuçlardan “\(folder.name)” klasörünü Finder'da açtım."
        }

        return "Referans verebileceğim önceki bir arama sonucu kalmamış. Önce dosya veya klasör araması yapalım."
    }

    private func suggestFromPreviousResults() -> String {
        if !fileSearchResults.isEmpty {
            let candidate = fileSearchResults.max { left, right in
                let leftDate = left.modificationDate ?? left.creationDate ?? .distantPast
                let rightDate = right.modificationDate ?? right.creationDate ?? .distantPast
                return leftDate < rightDate
            } ?? fileSearchResults[0]

            log("Bağlamdan çalışma adayı seçildi: \(candidate.name)")
            return "Önceki sonuçlar içinde başlangıç adayı olarak “\(candidate.name)” dosyasını öne çıkarıyorum. Mevcut metadata içinde en güncel görünen aday bu. Sağdaki sonuçtan açabilir veya “ilkini aç / sonuncusunu aç” diyebilirsin."
        }

        if !folderSearchResults.isEmpty {
            let candidate = folderSearchResults.max { left, right in
                let leftDate = left.modificationDate ?? left.creationDate ?? .distantPast
                let rightDate = right.modificationDate ?? right.creationDate ?? .distantPast
                return leftDate < rightDate
            } ?? folderSearchResults[0]

            log("Bağlamdan klasör adayı seçildi: \(candidate.name)")
            return "Önceki klasör sonuçları içinde “\(candidate.name)” en güncel aday olarak öne çıkıyor. Sağdaki sonuçtan açabilir veya “ilkini aç / sonuncusunu aç” diyebilirsin."
        }

        return "Önceki sonuç kalmadığı için seçim yapamıyorum. Önce ilgili dosya veya klasörleri bulalım."
    }

    private func searchIndexedFolders(
        for rawText: String,
        decision: AgentDecision
    ) -> String {
        guard let root = selectedRootURL else {
            folderSearchResults = []
            fileSearchResults = []
            fileSearchTitle = ""
            return "Önce bir çalışma klasörü seç. Klasör aramasını seçili alanın içinde yapacağım."
        }

        ensureWorkspaceIndexed()

        let text =
            normalize(rawText)

        let directNamedMatches =
            indexedFolders.filter { folder in
                let name =
                    normalize(folder.name)
                let path =
                    normalize(
                        folder.relativePath
                    )

                guard name.count >= 2 else {
                    return false
                }

                return
                    text.contains(name) ||
                    (
                        !path.isEmpty &&
                        text.contains(path)
                    )
            }

        var results: [FolderRecord]

        if !directNamedMatches.isEmpty {
            results =
                directNamedMatches
        } else {
            let queryTokens =
                folderQueryTokens(
                    from: text
                )

            if queryTokens.isEmpty {
                results = indexedFolders
            } else {
                let scored =
                    indexedFolders.compactMap {
                        folder
                        -> (
                            FolderRecord,
                            Int
                        )? in

                        let corpus =
                            normalize(
                                folder.name +
                                " " +
                                folder.relativePath
                            )

                        let score =
                            queryTokens.filter {
                                corpus.contains($0)
                            }
                            .count

                        return score > 0
                            ? (folder, score)
                            : nil
                    }

                let bestScore =
                    scored.map {
                        $0.1
                    }
                    .max() ?? 0

                results =
                    scored
                        .filter {
                            $0.1 ==
                                bestScore
                        }
                        .map {
                            $0.0
                        }
            }
        }

        if let range = decision.dateRange {
            results = results.filter { folder in
                switch decision.dateField {
                case .created:
                    guard let date = folder.creationDate else { return false }
                    return range.contains(date)
                case .modified:
                    guard let date = folder.modificationDate else { return false }
                    return range.contains(date)
                case .either:
                    let createdMatch = folder.creationDate.map(range.contains) ?? false
                    let modifiedMatch = folder.modificationDate.map(range.contains) ?? false
                    return createdMatch || modifiedMatch
                }
            }
        }

        if decision.sortMode == .newestFirst {
            results.sort {
                let left = $0.creationDate ?? $0.modificationDate ?? .distantPast
                let right = $1.creationDate ?? $1.modificationDate ?? .distantPast
                return left > right
            }
        }

        folderSearchResults = results
        fileSearchResults = []
        fileSearchTitle = decision.goal

        log("Yerel klasör araması: \(decision.goal)")
        log("\(results.count) klasör eşleşmesi bulundu")

        guard !results.isEmpty else {
            return "“\(root.lastPathComponent)” içinde \(decision.goal) için eşleşme bulamadım."
        }

        let preview = results.prefix(5).map(\.name).joined(separator: ", ")
        let extra = results.count > 5 ? " ve \(results.count - 5) klasör daha" : ""

        return "\(results.count) klasör buldum: \(preview)\(extra). Sağdaki sonuçlardan klasörü Finder'da açabilirsin."
    }

    private func searchIndexedFiles(
        for rawText: String,
        decision: AgentDecision
    ) -> String {
        let parsedQuery =
            fileQueryParser.parse(rawText)

        let outcome =
            fileSearchCoordinator.search(
                query: parsedQuery,
                decision: decision,
                selectedWorkspace:
                    selectedRootURL,
                previousResults:
                    decision.usePreviousResults
                    ? fileSearchResults
                    : []
            )

        lastFileSearchOutcome = outcome
        fileSearchResults = outcome.files
        folderSearchResults = []
        fileSearchTitle = outcome.title

        let extensionSummary =
            outcome.query.extensions.isEmpty
                ? "∅"
                : outcome.query.extensions
                    .sorted()
                    .joined(separator: ",")

        let filenameQuerySummary =
            outcome.query.filenameQuery.isEmpty
                ? "∅"
                : outcome.query.filenameQuery

        let limitSummary =
            outcome.query.resultLimit
                .map(String.init) ??
            "∅"

        let prohibitionValues =
            outcome.query.prohibitions
                .map(\.rawValue)
                .sorted()

        let prohibitionSummary =
            prohibitionValues.isEmpty
                ? "∅"
                : prohibitionValues
                    .joined(separator: ",")

        let searchLogParts = [
            "Yerel dosya araması: " +
                outcome.title,
            "target=" +
                String(
                    describing:
                        decision.target
                ),
            "scope=" +
                outcome.query.scope.title,
            "extensions=" +
                extensionSummary,
            "filenameQuery=" +
                filenameQuerySummary,
            "sort=" +
                String(
                    describing:
                        outcome.query.sortMode
                ),
            "limit=" +
                limitSummary,
            "output=" +
                outcome.query
                    .outputProjection
                    .rawValue,
            "prohibitions=" +
                prohibitionSummary,
            "status=" +
                outcome.status.rawValue
        ]

        log(
            searchLogParts
                .joined(separator: " • ")
        )

        if let rootName = outcome.rootName {
            log(
                "Dosya arama kökü: " +
                rootName
            )
        }

        if outcome.reachedSafetyLimit {
            log(
                "Dosya arama indeksi güvenlik sınırına ulaştı"
            )
        }

        log(
            String(outcome.resultCount) +
            " eşleşme bulundu"
        )

        if decision.usePreviousResults {
            log(
                "Bağlam filtresi önceki sonuç kümesine uygulandı"
            )
        }

        switch outcome.status {
        case .matched:
            if outcome.query
                .outputProjection ==
                .namesOnly {
                return outcome.files
                    .map {
                        "• " + $0.name
                    }
                    .joined(
                        separator: "\n"
                    )
            }

            if outcome.query
                .prohibitions
                .contains(.open) {
                return outcome.message
            }

            return outcome.message +
                " Sağdaki sonuçlardan istediğini Finder'da gösterebilirsin."

        case .noResults,
             .workspaceMissing,
             .unsupportedScope,
             .inaccessibleScope:
            return outcome.message
        }
    }

    private func turkishDayMonth(from text: String) -> (day: Int, month: Int, monthName: String)? {
        let months: [(name: String, number: Int)] = [
            ("ocak", 1), ("şubat", 2), ("subat", 2), ("mart", 3),
            ("nisan", 4), ("mayıs", 5), ("mayis", 5), ("haziran", 6),
            ("temmuz", 7), ("ağustos", 8), ("agustos", 8),
            ("eylül", 9), ("eylul", 9), ("ekim", 10),
            ("kasım", 11), ("kasim", 11), ("aralık", 12), ("aralik", 12)
        ]

        for month in months where text.contains(month.name) {
            let tokens = text
                .replacingOccurrences(of: month.name, with: " \(month.name) ")
                .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .map(String.init)

            guard let monthIndex = tokens.firstIndex(of: month.name) else { continue }

            let candidateIndexes = [monthIndex - 1, monthIndex + 1]
            for index in candidateIndexes where tokens.indices.contains(index) {
                if let day = Int(tokens[index]), (1...31).contains(day) {
                    return (day, month.number, month.name)
                }
            }
        }

        return nil
    }

    private func matches(day: Int, month: Int, date: Date?) -> Bool {
        guard let date else { return false }
        let components = Calendar.current.dateComponents([.day, .month], from: date)
        return components.day == day && components.month == month
    }

    private func folderQueryTokens(
        from text: String
    ) -> [String] {
        let stopWords = Set([
            "bana", "su", "bu", "bir",
            "klasor", "klasoru",
            "klasorune", "klasorunde",
            "folder", "masaustundeki",
            "masaustu", "desktop",
            "bul", "ara", "goster",
            "ac", "kaydet", "yaz",
            "dosya", "txt", "metin",
            "olarak", "analiz", "ile",
            "birlikte", "ekle", "icin",
            "uygulama", "uygulamasini"
        ])

        return text
            .split(whereSeparator: {
                $0.isWhitespace ||
                $0.isPunctuation
            })
            .map(String.init)
            .filter {
                $0.count >= 2 &&
                !stopWords.contains($0)
            }
    }

    // MARK: - Real File Actions

    private func prepareScreenshotOrganizeAction() -> String {
        guard let root = selectedRootURL else {
            log("Dosya işlemi için klasör seçimi bekleniyor")
            return "Önce sağdaki “Klasör seç ve indeksle” ile Masaüstü klasörünü seç. Bu sürüm dosyaları yalnızca senin seçtiğin klasör içinde değiştirecek."
        }

        ensureWorkspaceIndexed()

        let screenshots = indexedFiles.filter {
            $0.isScreenshot &&
            $0.url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL
        }

        guard !screenshots.isEmpty else {
            log("Ekran görüntüsü bulunamadı")
            return "\(root.lastPathComponent) içinde doğrudan duran ekran görüntüsü bulamadım."
        }

        let destination = root.appendingPathComponent("Ekran Görüntüleri", isDirectory: true)

        let preview = screenshots
            .prefix(5)
            .map { "• \($0.name)" }
            .joined(separator: "\n")

        let extraCount = max(0, screenshots.count - 5)
        let extraLine = extraCount > 0 ? "\n… ve \(extraCount) dosya daha" : ""

        pendingFileAction = PendingFileAction(
            title: "Ekran görüntülerini toparla",
            detail: "\(screenshots.count) ekran görüntüsü “Ekran Görüntüleri” klasörüne taşınacak.\n\n\(preview)\(extraLine)",
            sourceURLs: screenshots.map(\.url),
            destinationFolderURL: destination
        )

        log("\(screenshots.count) ekran görüntüsü bulundu")
        log("Gerçek dosya taşıma işlemi onay bekliyor")

        let sampleNames = screenshots
            .prefix(3)
            .map(\.name)
            .joined(separator: ", ")

        return "\(screenshots.count) ekran görüntüsü buldum. İlk adaylar: \(sampleNames). “Ekran Görüntüleri” klasörüne taşımak için onayını bekliyorum."
    }

    func approvePendingFileAction() -> String {
        guard let action = pendingFileAction else {
            return "Onay bekleyen bir dosya işlemi yok."
        }

        guard let root = selectedRootURL else {
            pendingFileAction = nil
            return "Çalışma klasörü artık seçili değil; işlemi durdurdum."
        }

        do {
            try fileManager.createDirectory(
                at: action.destinationFolderURL,
                withIntermediateDirectories: true
            )
        } catch {
            log("Hedef klasör oluşturulamadı: \(error.localizedDescription)")
            return "Hedef klasörü oluşturamadım: \(error.localizedDescription)"
        }

        var moves: [FileMoveRecord] = []
        var failed = 0

        for source in action.sourceURLs {
            // Safety: only direct children of the user-selected root are movable.
            guard source.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else {
                failed += 1
                continue
            }

            guard fileManager.fileExists(atPath: source.path) else {
                failed += 1
                continue
            }

            let preferred = action.destinationFolderURL.appendingPathComponent(source.lastPathComponent)
            let destination = collisionSafeURL(preferred)

            do {
                try fileManager.moveItem(at: source, to: destination)
                moves.append(
                    FileMoveRecord(
                        originalURL: source,
                        movedURL: destination
                    )
                )
            } catch {
                failed += 1
                log("Taşınamadı: \(source.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        pendingFileAction = nil

        if !moves.isEmpty {
            lastUndoAction = UndoFileAction(moves: moves)
        }

        workspaceIndexReady = false
        fileSearchCoordinator.invalidate(
            root: selectedRootURL
        )
        indexSelectedFolder()

        log("\(moves.count) dosya gerçekten taşındı")

        if failed > 0 {
            log("\(failed) dosya taşınamadı")
        }

        if moves.isEmpty {
            return "Hiçbir dosyayı taşıyamadım. Activity bölümündeki hatalara bakabiliriz."
        }

        if failed == 0 {
            return "\(moves.count) ekran görüntüsünü “Ekran Görüntüleri” klasörüne taşıdım. İstersen “geri al” diyebilirsin."
        }

        return "\(moves.count) dosyayı taşıdım, \(failed) dosyada hata oluştu. Başarılı taşıma işlemlerini “geri al” komutuyla geri çevirebilirsin."
    }

    func cancelPendingFileAction() {
        guard pendingFileAction != nil else { return }
        pendingFileAction = nil
        log("Bekleyen dosya işlemi kullanıcı tarafından iptal edildi")
        postAssistantMessage(
            "Dosya işlemini iptal ettim."
        )
    }

    func undoLastFileAction() -> String {
        guard let undo = lastUndoAction else {
            return "Geri alınabilecek bir dosya işlemi yok."
        }

        var restored = 0
        var failed = 0

        for move in undo.moves.reversed() {
            guard fileManager.fileExists(atPath: move.movedURL.path) else {
                failed += 1
                continue
            }

            let target = collisionSafeURL(move.originalURL)

            do {
                try fileManager.moveItem(at: move.movedURL, to: target)
                restored += 1
            } catch {
                failed += 1
                log("Geri alınamadı: \(move.movedURL.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        lastUndoAction = nil
        workspaceIndexReady = false
        fileSearchCoordinator.invalidate(
            root: selectedRootURL
        )
        indexSelectedFolder()

        log("\(restored) dosya işlemi geri alındı")

        if failed == 0 {
            return "\(restored) dosyayı önceki konumuna geri taşıdım."
        }

        return "\(restored) dosyayı geri aldım, \(failed) dosyada hata oluştu."
    }

    private func collisionSafeURL(_ preferred: URL) -> URL {
        guard fileManager.fileExists(atPath: preferred.path) else {
            return preferred
        }

        let directory = preferred.deletingLastPathComponent()
        let ext = preferred.pathExtension
        let base = preferred.deletingPathExtension().lastPathComponent

        var counter = 2

        while true {
            let name = ext.isEmpty
                ? "\(base) \(counter)"
                : "\(base) \(counter).\(ext)"

            let candidate = directory.appendingPathComponent(name)

            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            counter += 1
        }
    }

    // MARK: - Memory

    func addMemory(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !memories.contains(text) {
            memories.append(text)
            saveMemory()
        }

        contextMemoryEntries = contextMemoryStore.upsertRule(
            text,
            in: contextMemoryEntries
        )
        contextMemoryStore.save(contextMemoryEntries)
        contextMemoryStatus =
            "\(contextMemoryEntries.count) bağlam kaydı hazır."

        log("Yeni çalışma kuralı yapılandırılmış hafızaya kaydedildi")
    }

    private func memoryIntents(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let range = trimmed.range(
            of: "öğret:",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            return cleanedMemory(String(trimmed[range.upperBound...]))
                .map { [$0] } ?? []
        }

        let lower = normalize(trimmed)

        let explicitTriggers = [
            "bunu unutma",
            "aklinda tut",
            "aklında tut",
            "bunu hatirla",
            "bunu hatırla",
            "hatirla",
            "hatırla"
        ]

        if explicitTriggers.contains(where: { lower.contains($0) }) {
            var rule = trimmed

            for trigger in explicitTriggers {
                rule = rule.replacingOccurrences(
                    of: trigger,
                    with: "",
                    options: [.caseInsensitive, .diacriticInsensitive]
                )
            }

            return cleanedMemory(rule).map { [$0] } ?? []
        }

        if lower.hasPrefix("bundan sonra ") {
            return cleanedMemory(
                String(trimmed.dropFirst("bundan sonra ".count))
            ).map { [$0] } ?? []
        }

        let workflowRule =
            containsAny(lower, [
                "çalışma biçimini", "calisma bicimini",
                "çalışma şeklini", "calisma seklini",
                "bu yöntemi", "bu yontemi",
                "bu düzeni", "bu duzeni",
                "bu yaklaşımı", "bu yaklasimi"
            ]) &&
            containsAny(lower, [
                "ileride", "benzer", "için de kullan",
                "icin de kullan", "aynı şekilde kullan",
                "ayni sekilde kullan"
            ])

        let scopeRule =
            containsAny(lower, [
                "başka markalara", "baska markalara",
                "başka markaya", "baska markaya",
                "otomatik uygulama", "markaya özel",
                "markaya ozel"
            ])

        guard workflowRule || scopeRule else {
            return []
        }

        let normalizedSeparators = trimmed
            .replacingOccurrences(
                of: ". Ama ",
                with: ".",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
            .replacingOccurrences(
                of: ". Fakat ",
                with: ".",
                options: [.caseInsensitive, .diacriticInsensitive]
            )

        return normalizedSeparators
            .components(separatedBy: ".")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .compactMap(cleanedMemory)
            .filter { !$0.isEmpty }
    }

    private func cleanedMemory(_ raw: String) -> String? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }

    private func loadMemory() {
        if let saved = UserDefaults.standard.stringArray(forKey: memoryKey),
           !saved.isEmpty {
            memories = saved
        } else {
            memories = [
                "Ana projeyi doğrudan değiştirme; çalışma kopyasında ilerle.",
                "Basit işleri yerelde çöz; karmaşık problemde gerekirse güçlü modele danış."
            ]
        }
    }

    private func saveMemory() {
        UserDefaults.standard.set(memories, forKey: memoryKey)
    }

    // MARK: - Intent Helpers

    private func chooseModules(for text: String) -> [String] {
        let t = normalize(text)
        var modules = ["Core"]

        if containsAny(t, ["dosya", "klasör", "çekim", "bul", "ara", "göster", "listele", "logo", "arşiv", "masaüst", "masaustu", "ekran görünt", "ekran gorunt", "ekran resmi", "toparla", "taşı", "tasi"]) {
            modules.append("File Memory")
        }

        if isFileSearchIntent(t) {
            modules.append("File Search")
        }

        if isScreenshotOrganizeIntent(t) || pendingFileAction != nil {
            modules.append("File Actions")
        }

        if !isFileSearchIntent(t) && containsAny(t, ["reels", "video", "kurgu", "premiere", "altyaz", "export", "sequence"]) {
            modules += ["Director", "Premiere"]
        }

        if containsAny(t, ["mail", "gmail", "17:55", "faruk", "muammer"]) {
            modules.append("Work/Mail")
        }

        if containsAny(t, ["chatgpt", "openai", "hata", "sorun", "araştır", "bilmiyorsan"]) {
            modules.append("Research/OpenAI")
        }

        if containsAny(t, ["öğret", "bundan sonra", "tercih", "hep böyle", "unutma", "aklında tut", "hatırla"]) {
            modules.append("Learning")
        }

        return Array(NSOrderedSet(array: modules)) as? [String] ?? modules
    }

    private func isScreenshotOrganizeIntent(_ t: String) -> Bool {
        let screenshot = containsAny(t, ["ekran görünt", "ekran gorunt", "ekran resmi", "screenshot", "screen shot"])
        let action = containsAny(t, ["toparla", "taşı", "tasi", "klasöre", "klasore", "düzenle", "duzenle"])
        return screenshot && action
    }

    private func isApproval(_ t: String) -> Bool {
        let exact = [
            "evet",
            "onayla",
            "tamam",
            "devam",
            "yap",
            "olur",
            "taşı",
            "tasi",
            "onaylıyorum",
            "onayliyorum"
        ]
        return exact.contains(t)
    }

    private func isRejection(_ t: String) -> Bool {
        let exact = [
            "hayır",
            "hayir",
            "iptal",
            "vazgeç",
            "vazgec",
            "yapma"
        ]
        return exact.contains(t)
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased(with: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.contains($0) }
    }

    private func log(_ text: String) {
        activities.insert(ActivityItem(text: text), at: 0)

        if activities.count > 120 {
            activities.removeLast()
        }
    }
}
