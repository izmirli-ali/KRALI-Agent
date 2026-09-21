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
    @Published var currentTaskGraph: AgentTaskGraph?
    @Published var taskGraphStatus = "Henüz görev grafiği yok."
    @Published var currentProblemResolution: AgentProblemResolution?
    @Published var currentReflectionSummary: String?
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
    private let missionNormalizer = AgentMissionNormalizer()
    private let problemSolver = AgentProblemSolver()
    private let capabilityGapResolver = AgentCapabilityGapResolver()
    private let verifier = AgentVerifier()
    private let capabilityRegistry = AgentCapabilityRegistry()
    private let goalInterpreter = AgentGoalInterpreter()
    private let responseComposer = AgentResponseComposer()
    private let routeBuilder = AgentRouteBuilder()
    private let capabilityLearner = AgentCapabilityLearner()
    private let learningStore = AgentLearningStore()
    private let webResearchService = AgentWebResearchService()
    private let webSourceReader = AgentWebSourceReader()
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
    private let learningQueueStore = AgentLearningQueueStore()
    private let debugRecoveryCenter = AgentDebugRecoveryCenter()
    private let localIntelligence = AgentLocalIntelligence()
    private let subscriptionIntelligence = AgentSubscriptionIntelligence()
    private let contextMemoryStore = AgentContextMemoryStore()
    private let conversationStore = ConversationStore()
    private let workspaceIndexer = AgentWorkspaceIndexer()
    private let fileQueryParser = AgentFileQueryParser()
    private let fileSearchCoordinator =
        AgentFileSearchCoordinator()
    private let diagnosticsLoader = AgentDiagnosticsLoader()
    private let workspaceIndexFreshness: TimeInterval = 45
    private var workspaceIndexUpdatedAt: Date?
    private var inspectorStateForwarder: AnyCancellable?
    private var lastDecision: AgentDecision?
    private var activeLearningJobID: UUID?

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

        capabilityLearningBacklog = learningStore.load()
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

            if let recovered =
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

        let recalledContextMemories =
            contextMemoryStore.relevant(
                to: text,
                from: contextMemoryEntries,
                limit: 4
            )

        let executionContextMemories =
            contextMemoryStore.executionContext(
                to: text,
                from: recalledContextMemories,
                limit: 4
            )

        // Only execution-safe context is allowed to influence routing,
        // planning and verification. Broader recall may still exist in the
        // persistent store but must not poison an unrelated new task.
        activeContextMemories =
            executionContextMemories

        if !executionContextMemories.isEmpty {
            contextMemoryStatus =
                "\(executionContextMemories.count) güvenli bağlam kaydı bu tura taşındı."
            log(
                "Bağlam hafızası: " +
                executionContextMemories
                    .map(\.title)
                    .joined(separator: " • ")
            )
        } else if !recalledContextMemories.isEmpty {
            contextMemoryStatus =
                "Önceki görev bağlamları bulundu ancak yeni hedef bağımsız olduğu için izole edildi."
            log(
                "Bağlam firewall: önceki görev bağlamları bu tura taşınmadı"
            )
        } else {
            contextMemoryStatus =
                "Bu tur için ilgili önceki bağlam bulunmadı."
        }

        appendConversationMessage(
            ChatMessage(
                role: .user,
                text: text
            )
        )

        let decision = brain.analyze(
            text,
            context: brainContext()
        )

        let goalProfile = goalInterpreter.interpret(
            text,
            decision: decision,
            context: brainContext()
        )

        currentGoal = goalProfile.summary
        currentPlan = decision.selectedPlan
        currentAlternatives = decision.alternatives
        lastDecision = decision

        let capabilities = capabilityRegistry.select(
            for: text,
            decision: decision,
            context: brainContext(),
            goal: goalProfile
        )
        selectedCapabilities = capabilities

        let webResearchAvailable =
            capabilityRegistry.all.first(
                where: { $0.id == "research.web" }
            )?.isAvailable == true

        let learningPlans = capabilityLearner.makePlans(
            for: capabilities,
            webResearchAvailable: webResearchAvailable
        )
        capabilityLearningPlans = learningPlans
        capabilityLearningBacklog = learningStore.merge(
            existing: capabilityLearningBacklog,
            plans: learningPlans,
            capabilities: capabilities
        )

        let executionPlan = planner.makePlan(
            decision: decision,
            context: brainContext(),
            capabilities: capabilities,
            learningPlans: learningPlans,
            goal: goalProfile
        )

        let deterministicGraph =
            deterministicProblemGraph(
                goal: goalProfile,
                plan: executionPlan
            )

        currentTaskGraph =
            deterministicGraph

        let deterministicResolution =
            problemSolver.solve(
                graph: deterministicGraph,
                capabilities:
                    capabilityRegistry.all,
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
                    capabilities: capabilityRegistry.all,
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
                    capabilities: capabilityRegistry.all,
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
                            capabilityRegistry.all
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
            resolvedLearningPlans = capabilityLearner.makePlans(
                for: resolvedCapabilities,
                webResearchAvailable: webResearchAvailable
            )
            resolvedExecutionPlan = semanticExecutionPlan(
                mission,
                capabilities: resolvedCapabilities,
                goal: resolvedGoal
            )

            let compiledTaskGraph =
                taskOrchestrator.compile(
                    mission: mission,
                    capabilities:
                        capabilityRegistry.all
                )

            currentTaskGraph =
                compiledTaskGraph

            let problemResolution =
                problemSolver.solve(
                    graph: compiledTaskGraph,
                    capabilities:
                        capabilityRegistry.all,
                    observations:
                        problemSolverObservations()
                )

            currentProblemResolution =
                problemResolution
            currentReflectionSummary =
                problemResolution.reflection

            currentCapabilityGaps =
                capabilityGapResolver.resolve(
                    graph:
                        compiledTaskGraph,
                    capabilities:
                        capabilityRegistry.all
                )

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

        var baseReply: String

        if let mission = semanticMission {
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
                            capabilities:
                                capabilityRegistry.all
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

                    log(
                        "Runtime Capability Gap: " +
                        gap.capabilityID +
                        " • " +
                        gap.reason
                    )
                }
            }
        } else if resolvedGoal.outcomes.contains(.research),
                  resolvedCapabilities.contains(where: {
                      $0.id == "research.web" && $0.isAvailable
                  }) {
            baseReply = await performWebResearch(
                query: webResearchQuery(from: text)
            )
        } else {
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
                    completedSemanticStepIndexes
            )
        } else {
            completeActionSteps()
        }

        let verification: AgentVerificationResult
        if resolvedExecutionPlan.requiresVerification {
            setVerificationStep(.running)
            verificationState = .checking
            verificationSummary = "Sonuç kontrol ediliyor…"

            verification = verifier.verify(
                decision: decision,
                currentUserInput: text,
                goal: resolvedGoal,
                semanticMission: semanticMission,
                snapshot: verificationSnapshot(
                    executedCapabilityIDs:
                        executedSemanticCapabilities
                )
            )

            verificationState = verification.state
            verificationSummary = verification.summary

            if verification.state == .attention {
                setVerificationStep(.attention)
                fallbackPlan = verification.fallback ?? resolvedExecutionPlan.fallback
            } else if verification.state == .partial {
                setVerificationStep(.partial)
                fallbackPlan = nil
            } else {
                setVerificationStep(.completed)
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

        if verification.state == .attention,
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

        if shouldUseIntelligence(
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
           inspectorState.debugIncident == nil &&
           lastFileSearchOutcome == nil {
            registerDebugIncident(
                source: "verifier",
                message: finalVerification.summary,
                evidence: finalVerification.fallback,
                progress: .investigating
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

        if !currentCapabilityGaps.isEmpty {
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
            guard ids.contains("research.web") ||
                  ids.contains("browser.control") else {
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

        let resolved = capabilityRegistry.resolve(ids: ids)

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
                    capabilityRegistry.all
            )

        var outputs: [String] = []
        var stepEvidence: [Int: String] = [:]
        var executed = Set<String>()
        var completedStepIndexes = Set<Int>()
        var didFileSearch = false

        for (stepIndex, step) in mission.steps.enumerated() {
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

            if graphStep.requiresApproval {
                let approvalMessage =
                    "Kullanıcı onayı bekleniyor: " +
                    step.title

                stepEvidence[stepIndex] =
                    approvalMessage
                outputs.append(
                    approvalMessage
                )
                log(
                    "Task Graph approval gate: " +
                    String(stepIndex) +
                    " • " +
                    step.capabilityID +
                    " • " +
                    step.operation
                )
                continue
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
                let scopedSearchInput =
                    [
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

                let searchInput =
                    scopedSearchInput.isEmpty
                        ? userInput
                        : scopedSearchInput

                let searchDecision =
                    semanticFileSearchDecision(
                        mission: mission,
                        userInput: searchInput
                    )

                let searchReply: String
                if searchDecision.target ==
                    .folder {
                    searchReply =
                        searchIndexedFolders(
                            for: searchInput,
                            decision:
                                searchDecision
                        )
                } else {
                    searchReply =
                        searchIndexedFiles(
                            for: searchInput,
                            decision:
                                searchDecision
                        )
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
                do {
                    let result =
                        try await desktopControl
                            .openOrFocusApplication(
                                from: userInput
                            )

                    let verified =
                        result
                            .launchOrActivateSucceeded &&
                        result
                            .frontmostVerified

                    inspectorState.desktopControlStatus =
                        result
                            .resolvedApplicationName +
                        (
                            verified
                                ? " açıldı/öne geldi • görsel ön plan doğrulandı"
                                : " açıldı fakat gerçek ön plan doğrulaması başarısız"
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
                    capabilityRegistry.all
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

    private func semanticFileSearchDecision(
        mission: AgentSemanticMission,
        userInput: String
    ) -> AgentDecision {
        let corpus = normalizeSemanticText(
            (
                [userInput, mission.objective] +
                mission.steps.flatMap {
                    [$0.title, $0.purpose, $0.operation]
                }
            )
            .joined(separator: " ")
        )

        let target: AgentTargetKind
        if containsSemanticAny(
            corpus,
            [
                "video", "cekim", "kurgu", "reels",
                "premiere", "klip"
            ]
        ) {
            target = .video
        } else if containsSemanticAny(
            corpus,
            [
                "gorsel", "fotograf", "resim", "logo",
                "tasarim", "photoshop"
            ]
        ) {
            target = .image
        } else if corpus.contains("pdf") {
            target = .pdf
        } else if containsSemanticAny(
            corpus,
            ["proje", "project"]
        ) {
            target = .project
        } else if containsSemanticAny(
            corpus,
            ["belge", "dokuman", "document"]
        ) {
            target = .document
        } else if containsSemanticAny(
            corpus,
            ["klasor", "folder"]
        ) {
            target = .folder
        } else {
            target = .any
        }

        let newest = containsSemanticAny(
            corpus,
            [
                "son cekim", "en yeni", "en son", "latest",
                "recent", "dunku", "bugunku", "yeni cekim"
            ]
        )

        return AgentDecision(
            intent: .fileSearch,
            target: target,
            dateRange: nil,
            dateField: .either,
            sortMode: newest ? .newestFirst : .relevance,
            route: ["Core", "Goal", "Context", "Files"],
            goal: mission.objective,
            selectedPlan:
                "Semantic mission için gerekli yerel dosya kapsamını salt-okunur tara.",
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
        completedMissionStepIndexes: Set<Int>
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

                if !isStepCapabilityAvailable(
                    executionSteps[index]
                ) {
                    executionSteps[index].state = .blocked
                } else if completedMissionStepIndexes.contains(
                    semanticStepIndex
                ) &&
                executedCapabilityIDs.contains(capabilityID) {
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
                    capabilityRegistry.all
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
                        capability?.risk ==
                            .external ||
                        capability?.risk ==
                            .reversibleWrite
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
        taskGraphStatus = "Yeni görev için görev grafiği bekleniyor."
        currentProblemResolution = nil
        currentReflectionSummary = nil
        currentCapabilityGaps = []
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
                incident.message
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

        if decision.target == .folder,
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
                    " klasör gözlemledim. İlk klasör arama stratejisi sonuç üretmediği için mevcut doğrulanmış workspace indeksini yeniden kullandım: " +
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
                    "Çelişki algılandı: workspace indeksi " +
                    String(
                        indexedFolders.count
                    ) +
                    " klasör gözlemledi fakat birincil arama 0 sonuç verdi. Yeni capability öğrenmek yerine doğrulanmış indeks kanıtı yeniden kullanıldı."

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
                                "reuse-evidence:contradiction",
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

        guard hasRelaxableConstraint else { return nil }

        let recoveryDecision = AgentDecision(
            intent: decision.intent,
            target: decision.target,
            dateRange: nil,
            dateField: .either,
            sortMode: decision.sortMode,
            route: decision.route + ["Plan B"],
            goal: "Daha geniş kapsamda " + decision.goal,
            selectedPlan: "İlk aramada sonuç çıkmadığı için tarih / önceki-sonuç kısıtını kaldır ve aynı hedefi seçili çalışma alanında salt-okunur yeniden ara.",
            alternatives: decision.alternatives,
            proactiveSuggestion: nil,
            usePreviousResults: false,
            resultSelection: nil
        )

        log("Plan B deneniyor: arama kapsamı güvenli biçimde genişletiliyor")

        let reply: String
        if recoveryDecision.intent == .compoundFileTask {
            reply = executeCompoundFileTask(
                for: text,
                decision: recoveryDecision
            )
        } else if recoveryDecision.target == .folder {
            reply = searchIndexedFolders(
                for: text,
                decision: recoveryDecision
            )
        } else {
            reply = searchIndexedFiles(
                for: text,
                decision: recoveryDecision
            )
        }

        let verification = verifier.verify(
            decision: recoveryDecision,
            currentUserInput: text,
            goal: goal,
            snapshot: verificationSnapshot()
        )

        return RecoveryAttempt(
            reply: reply,
            verification: verification,
            summary: "Tarih / önceki sonuç kısıtı kaldırılarak aynı hedef seçili çalışma alanında yeniden arandı."
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
        query: String
    ) async -> String {
        webResearchStatus = "Web araştırılıyor…"
        log("Web Research başladı")

        do {
            let report = try await webResearchService.search(
                query,
                limit: 5
            )

            let evidence = await webSourceReader.read(
                report.results,
                query: query,
                limit: 4
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
                queueInteractiveAccessCapability()

                var reply =
                    "Hedefin doğrudan adresini çözdüm: " +
                    resolved.url.absoluteString +
                    "\n\nAncak bu kaynak canlı içeriğini statik web isteğine açmadığı için güncel veriyi doğrulayamadım."

                reply +=
                    "\n\nKRALİ bunu 'hedef yok' diye yorumlamıyor; bir sonraki gerekli yetkinlik olarak güvenli tarayıcı/oturum erişimini öğrenme kuyruğuna aldı."

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
            let browser = capabilityRegistry.all.first(
                where: { $0.id == "browser.control" }
            ),
            !selectedCapabilities.contains(
                where: { $0.id == browser.id }
            )
        else {
            return
        }

        selectedCapabilities.append(browser)

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
                semanticMission: currentSemanticMission,
                semanticPlannerProvider:
                    currentSemanticPlannerProvider,
                taskGraph:
                    currentTaskGraph,
                problemResolution:
                    currentProblemResolution,
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
        inspectorState.trainingLabStatus = "KRALİ kendi temel yeterlilik testlerini çalıştırıyor…"
        log("Training Lab başladı")

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
            "KRALİ açık-dünya görevlerini planner + reviewer ile test ediyor…"
        log("KRALİ Arena başladı")

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
        guard !inspectorState.developerAgentBusy else {
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
        learningJobBriefURL: URL? = nil
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

        inspectorState.developerAgentBusy = true

        let initialMessage: String
        if let learningJob {
            initialMessage =
                learningJob.capabilityName +
                " için öğrenme işi başlatılıyor • job=" +
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
            learningJob == nil
                ? "Developer Agent başlatıldı"
                : "Developer Agent Learning Queue job'u başlatıldı"
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
                        learningJobBriefURL
                )

            monitor.cancel()

            inspectorState.developerAgentStatus =
                status
            inspectorState.developerAgentBusy =
                false

            finishActiveLearningJob(
                with: status
            )

            switch status.state {
            case "ready_for_review",
                 "recovered_candidate_ready":
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
        inspectorState.mentorTraceStatus = "Mentor kaydı private GitHub'a aktarılıyor…"

        Task {
            let result = await Task.detached(
                priority: .utility
            ) {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(
                    fileURLWithPath: "/bin/zsh"
                )
                process.arguments = [scriptPath]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading
                        .readDataToEndOfFile()

                    let output = String(
                        data: data,
                        encoding: .utf8
                    ) ?? ""

                    return (
                        Int(process.terminationStatus),
                        output
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
                    "Mentor kaydı GitHub'a aktarıldı • bana “mentor kaydına bak” diyebilirsin."
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
        guard selectedRootURL != nil else {
            fileSearchResults = []
            return "Bu çok adımlı görev için önce bir çalışma klasörü seçmeliyim."
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

        log(
            "Yerel dosya araması: " +
            outcome.title +
            " • scope=" +
            outcome.query.scope.title +
            " • extensions=" +
            (
                outcome.query.extensions.isEmpty
                    ? "∅"
                    : outcome.query.extensions
                        .sorted()
                        .joined(separator: ",")
            ) +
            " • filenameQuery=" +
            (
                outcome.query.filenameQuery.isEmpty
                    ? "∅"
                    : outcome.query.filenameQuery
            ) +
            " • status=" +
            outcome.status.rawValue
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
