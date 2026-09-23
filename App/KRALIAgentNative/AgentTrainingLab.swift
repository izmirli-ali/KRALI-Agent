import Foundation

enum TrainingScenarioTier: String, Codable, Hashable {
    case core
    case northStar
}

struct TrainingScenarioResult: Identifiable, Codable, Hashable {
    var id: String { scenarioID }

    let scenarioID: String
    let title: String
    let tier: TrainingScenarioTier
    let prompt: String
    let passed: Bool
    let goal: String
    let route: [String]
    let selectedCapabilities: [String]
    let unavailableCapabilities: [String]
    let diagnostics: [String]
}

struct TrainingLabReport: Codable, Hashable {
    let createdAt: Date
    let appVersion: String
    let total: Int
    let passed: Int
    let failed: Int
    let corePassed: Int
    let coreTotal: Int
    let northStarPassed: Int
    let northStarTotal: Int
    let results: [TrainingScenarioResult]
}

private struct TrainingScenario {
    let id: String
    let title: String
    let tier: TrainingScenarioTier
    let prompt: String
    let context: AgentContextSnapshot
    let requiredOutcomes: Set<AgentGoalOutcome>
    let requiredCapabilities: Set<String>
    let forbiddenCapabilities: Set<String>
    let requiredRouteStages: Set<String>
    let requiredStepTitles: [String]
    let requiredLearningCapabilities: Set<String>
    let minimumResearchConceptGroups: Int
    let minimumMandatoryResearchConceptGroups: Int
    var minimumDirectResearchCandidates: Int = 0
}

struct AgentTrainingLab {
    private let brain = AgentBrain()
    private let goalInterpreter = AgentGoalInterpreter()
    private let capabilityRegistry = AgentCapabilityRegistry()
    private let capabilityLearner = AgentCapabilityLearner()
    private let planner = AgentPlanner()
    private let routeBuilder = AgentRouteBuilder()
    private let researchQueryPlanner = AgentResearchQueryPlanner()
    private let verifier = AgentVerifier()
    private let languageResolver =
        AgentNaturalLanguageResolver()
    private let taskOrchestrator =
        AgentTaskOrchestrator()
    private let missionNormalizer =
        AgentMissionNormalizer()
    private let capabilityGapResolver =
        AgentCapabilityGapResolver()
    private let problemSolver =
        AgentProblemSolver()
    private let outcomePlanner =
        AgentOutcomePlanner()
    private let fileQueryParser =
        AgentFileQueryParser()

    func run() -> TrainingLabReport {
        let scenarios = makeScenarios()
        var results: [TrainingScenarioResult] = []

        let webResearchAvailable =
            capabilityRegistry.all.first(
                where: { $0.id == "research.web" }
            )?.isAvailable == true

        for scenario in scenarios {
            let decision = brain.analyze(
                scenario.prompt,
                context: scenario.context
            )

            let goal = goalInterpreter.interpret(
                scenario.prompt,
                decision: decision,
                context: scenario.context
            )

            let capabilities = capabilityRegistry.select(
                for: scenario.prompt,
                decision: decision,
                context: scenario.context,
                goal: goal
            )

            let learningPlans = capabilityLearner.makePlans(
                for: capabilities,
                webResearchAvailable: webResearchAvailable
            )

            let plan = planner.makePlan(
                decision: decision,
                context: scenario.context,
                capabilities: capabilities,
                learningPlans: learningPlans,
                goal: goal
            )

            let route = routeBuilder.build(
                goal: goal,
                capabilities: capabilities,
                learningPlans: learningPlans,
                requiresVerification: plan.requiresVerification
            )

            let result = evaluate(
                scenario,
                goal: goal,
                capabilities: capabilities,
                learningPlans: learningPlans,
                plan: plan,
                route: route
            )

            results.append(result)
        }

        results.append(
            memoryTransformSourceResolutionResult()
        )
        results.append(
            namedTopicMemoryIsolationResult()
        )
        results.append(
            newBrandIntroductionIsolationResult()
        )
        results.append(
            executionContextFirewallResult()
        )
        results.append(
            staleGoalVerifierIsolationResult()
        )
        results.append(
            semanticExecutionVerifierResult()
        )
        results.append(
            shortAppOpenLanguageResult()
        )
        results.append(
            inflectedAppNameLanguageResult()
        )
        results.append(
            candidateAliasSuffixIsolationResult()
        )
        results.append(
            semanticExactAliasSafetyResult()
        )
        results.append(
            strictExternalApprovalResult()
        )
        results.append(
            typoAppNameLanguageResult()
        )
        results.append(
            duplicateApplicationAliasMergeResult()
        )
        results.append(
            localizedApplicationDisplayTargetResult()
        )
        results.append(
            prohibitedAppMutationDoesNotAddWorkflowResult()
        )
        results.append(
            appOpenIntentRoutingResult(
                id: "mail-app-open-routing",
                title: "Mail uygulaması açma intent ayrımı",
                prompt: "Mail'i aç",
                forbiddenCapabilityID:
                    "mail.work"
            )
        )
        results.append(
            appOpenIntentRoutingResult(
                id: "finder-app-open-routing",
                title: "Finder uygulaması açma intent ayrımı",
                prompt: "Finder'ı aç",
                forbiddenCapabilityID:
                    "files.reveal"
            )
        )
        results.append(
            mailWorkflowRoutingResult()
        )
        results.append(
            crossProviderTaskGraphResult()
        )
        results.append(
            externalCommitApprovalGraphResult()
        )
        results.append(
            compoundCommandBypassesFastPathResult()
        )
        results.append(
            compoundMissionNormalizationResult()
        )
        results.append(
            genericAppWorkflowGapResult()
        )
        results.append(
            genericAppWorkflowStrategySafetyResult()
        )
        results.append(
            compoundAppTargetExtractionResult()
        )
        results.append(
            secondaryNounAppIsolationResult()
        )
        results.append(
            browserWorkflowContractResult()
        )
        results.append(
            runtimeProviderFailureEscalationResult()
        )
        results.append(
            learningQueueDeduplicationResult()
        )
        results.append(
            nonCommitWorkflowApprovalResult()
        )
        results.append(
            capabilityGapClassificationResult()
        )
        results.append(
            fileQueryDesktopScopeResult()
        )
        results.append(
            fileQueryDownloadsPDFResult()
        )
        results.append(
            fileQuerySubstringSafetyResult()
        )
        results.append(
            fileQueryArchiveExtensionResult()
        )
        results.append(
            fileQueryInflectedBrainIntentResult()
        )
        results.append(
            fileSemanticMetamorphicFamilyResult()
        )
        results.append(
            problemSolverUsesExistingStrategyBeforeLearningResult()
        )
        results.append(
            problemSolverReflectionChoosesAnotherSafeStrategyResult()
        )
        results.append(
            outcomePlannerPublicResearchAvoidsBrowserLearningResult()
        )
        results.append(
            outcomePlannerMutationStillRequiresRealCapabilityResult()
        )
        results.append(
            explicitDomainDirectResearchCandidateResult()
        )
        results.append(
            outcomeStrategyChainOrderingResult()
        )
        results.append(
            webTargetDoesNotBecomeApplicationNameResult()
        )
        results.append(
            exhaustedOutcomeOpensRealCapabilityGapResult()
        )

        let core = results.filter { $0.tier == .core }
        let northStar = results.filter { $0.tier == .northStar }

        return TrainingLabReport(
            createdAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            total: results.count,
            passed: results.filter(\.passed).count,
            failed: results.filter { !$0.passed }.count,
            corePassed: core.filter(\.passed).count,
            coreTotal: core.count,
            northStarPassed: northStar.filter(\.passed).count,
            northStarTotal: northStar.count,
            results: results
        )
    }

    private func exhaustedOutcomeOpensRealCapabilityGapResult()
        -> TrainingScenarioResult {
        let gap =
            capabilityGapResolver
                .resolveExhaustedOutcomeCapability(
                    capabilityID:
                        "browser.control",
                    objective:
                        "example.com ana başlığını öğren",
                    attemptSummaries: [
                        "research.web: kanıt yok",
                        "system.open.url + perception.screen: ekran doğrulanamadı"
                    ],
                    capabilities:
                        capabilityRegistry.all
                )

        var diagnostics: [String] = []

        if gap == nil {
            diagnostics.append(
                "Outcome stratejileri tükendiği halde browser.control gerçek capability gap olarak açılmadı."
            )
        }

        if gap?.kind !=
            .integration {
            diagnostics.append(
                "browser.control exhausted gap integration olarak sınıflandırılmadı."
            )
        }

        if !(gap?
            .candidateCapabilityIDs
            .isEmpty ?? false) {
            diagnostics.append(
                "Tükenmiş stratejiler tekrar candidate olarak gap'e taşındı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "outcome-exhaustion-opens-capability-gap",
            title:
                "Outcome stratejileri tükenince gerçek capability gap açılmalı",
            tier: .core,
            prompt:
                "example.com sitesine gir ve sayfadaki ana başlığı bana söyle",
            passed: diagnostics.isEmpty,
            goal:
                "Mevcut güvenli yollar runtime'da başarısızsa ancak o zaman browser.control Learning Gateway'e geç",
            route: [
                "Core",
                "Outcome",
                "Strategy Chain",
                "Learning Gate"
            ],
            selectedCapabilities: [],
            unavailableCapabilities: [
                "browser.control"
            ],
            diagnostics: diagnostics
        )
    }

    private func explicitDomainDirectResearchCandidateResult()
        -> TrainingScenarioResult {
        let prompt =
            "example.com sitesine gir ve sayfadaki ana başlığı bana söyle"

        let plan =
            researchQueryPlanner.plan(
                prompt
            )

        var diagnostics: [String] = []

        if !plan.directCandidates
            .contains(
                where: {
                    $0.url.host?
                        .lowercased() ==
                        "example.com"
                }
            ) {
            diagnostics.append(
                "Açık domain direct research candidate'a çevrilmedi."
            )
        }

        if !plan.preferredDomains
            .contains(
                "example.com"
            ) {
            diagnostics.append(
                "Açık domain preferred domain olarak korunmadı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "explicit-domain-direct-research",
            title:
                "Açık domain doğrudan kaynağa çözülmeli",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Arama motoruna bağımlı kalmadan explicit URL/domain kaynağını önce doğrudan oku",
            route: [
                "Core",
                "Outcome",
                "Research"
            ],
            selectedCapabilities: [
                "research.web"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func outcomeStrategyChainOrderingResult()
        -> TrainingScenarioResult {
        let prompt =
            "example.com sitesine gir ve sayfadaki ana başlığı bana söyle"

        let goal = AgentGoalProfile(
            summary:
                "example.com ana başlığını öğren",
            outcomes: [
                .open,
                .research,
                .explain
            ],
            requiredCapabilityIDs: [
                "core.reasoning",
                "context.local",
                "browser.control",
                "desktop.app"
            ],
            isCompound: true
        )

        let resolution =
            outcomePlanner.resolve(
                contract:
                    outcomePlanner.makeContract(
                        userInput:
                            prompt,
                        goal:
                            goal,
                        mission:
                            nil
                    ),
                capabilities:
                    capabilityRegistry.all
            )

        let strategies =
            resolution
                .orderedExecutableStrategies(
                    for:
                        "public-information"
                )

        var diagnostics: [String] = []

        if strategies.first?
            .kind !=
            .publicResearch {
            diagnostics.append(
                "Outcome chain'in ilk stratejisi research.web değil."
            )
        }

        if strategies.dropFirst()
            .first?
            .kind !=
            .openURLAndObserve {
            diagnostics.append(
                "research.web sonrasında system.open.url + perception.screen fallback'i yok."
            )
        }

        if strategies.contains(
            where: {
                $0.requiresLearning
            }
        ) {
            diagnostics.append(
                "Learning stratejisi executable safe strategy zincirine karıştı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "outcome-strategy-chain-order",
            title:
                "Outcome stratejileri güvenli sırayla denenmeli",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "research.web → system.open.url + perception.screen → gerekirse Learning",
            route: [
                "Core",
                "Outcome",
                "Strategy Chain"
            ],
            selectedCapabilities:
                strategies
                    .flatMap(
                        \.capabilityIDs
                    )
                    .uniquedForTraining(),
            unavailableCapabilities: [
                "browser.control"
            ],
            diagnostics: diagnostics
        )
    }

    private func webTargetDoesNotBecomeApplicationNameResult()
        -> TrainingScenarioResult {
        let prompt =
            "example.com sitesine gir ve sayfadaki ana başlığı bana söyle"

        let explicitAppPrompt =
            "Safari'yi aç ve example.com sitesine gir"

        var diagnostics: [String] = []

        if languageResolver
            .applicationTargetPhrase(
                from: prompt
            ) != nil {
            diagnostics.append(
                "Domain/site ifadesi yanlışlıkla uygulama hedefi olarak çözüldü."
            )
        }

        if languageResolver
            .webURL(
                from: prompt
            )?
            .host?
            .lowercased() !=
            "example.com" {
            diagnostics.append(
                "Web hedefi example.com olarak çözülemedi."
            )
        }

        let explicitApp =
            languageResolver
                .applicationTargetPhrase(
                    from:
                        explicitAppPrompt
                )

        if explicitApp == nil ||
           !languageResolver
            .normalized(
                explicitApp ?? ""
            )
            .contains(
                "safari"
            ) {
            diagnostics.append(
                "Açık Safari hedefi web workflow filtresi yüzünden kayboldu."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "web-target-not-application-name",
            title:
                "Domain hedefi uygulama adı sanılmamalı",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Web hedefini URL olarak çöz; yalnız açık app hedefi varsa uygulama resolver'a ver",
            route: [
                "Core",
                "Language",
                "Outcome"
            ],
            selectedCapabilities: [
                "system.open.url",
                "perception.screen"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func outcomePlannerPublicResearchAvoidsBrowserLearningResult()
        -> TrainingScenarioResult {
        let prompt =
            "example.com sitesine gir ve sayfadaki ana başlığı bana söyle"

        let goal = AgentGoalProfile(
            summary:
                "example.com ana başlığını öğren",
            outcomes: [
                .open,
                .research,
                .explain
            ],
            requiredCapabilityIDs: [
                "core.reasoning",
                "context.local",
                "browser.control",
                "desktop.app"
            ],
            isCompound: true
        )

        let contract =
            outcomePlanner.makeContract(
                userInput: prompt,
                goal: goal,
                mission: nil
            )

        let resolution =
            outcomePlanner.resolve(
                contract: contract,
                capabilities:
                    capabilityRegistry.all
            )

        var diagnostics: [String] = []

        if !resolution.isFullyCovered {
            diagnostics.append(
                "Public bilgi outcome'u mevcut capability'lerle kapsanamadı."
            )
        }

        if !resolution
            .chosenStrategies
            .contains(
                where: {
                    $0.kind ==
                        .publicResearch &&
                    $0.capabilityIDs
                        .contains(
                            "research.web"
                        )
                }
            ) {
            diagnostics.append(
                "research.web public bilgi için outcome stratejisi olarak seçilmedi."
            )
        }

        if !resolution
            .suppressedLearningCapabilityIDs
            .contains(
                "browser.control"
            ) {
            diagnostics.append(
                "browser.control yalnız araç olmasına rağmen Learning gate tarafından bastırılmadı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "outcome-public-research-before-browser-learning",
            title:
                "Public bilgi outcome'u browser Learning'den önce çözülmeli",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Başarı kriterini research.web ile karşıla; browser yalnız araçsa Learning açma",
            route: [
                "Core",
                "Outcome",
                "Strategy",
                "Research",
                "Verify"
            ],
            selectedCapabilities:
                resolution
                    .chosenStrategies
                    .flatMap(
                        \.capabilityIDs
                    )
                    .uniquedForTraining(),
            unavailableCapabilities:
                resolution
                    .suppressedLearningCapabilityIDs
                    .sorted(),
            diagnostics: diagnostics
        )
    }

    private func outcomePlannerMutationStillRequiresRealCapabilityResult()
        -> TrainingScenarioResult {
        let prompt =
            "Premiere'de aktif sequence içindeki boşlukları temizle"

        let goal = AgentGoalProfile(
            summary:
                "timeline boşluklarını temizle",
            outcomes: [
                .edit
            ],
            requiredCapabilityIDs: [
                "core.reasoning",
                "context.local",
                "premiere.control"
            ],
            isCompound: false
        )

        let contract =
            outcomePlanner.makeContract(
                userInput: prompt,
                goal: goal,
                mission: nil
            )

        let resolution =
            outcomePlanner.resolve(
                contract: contract,
                capabilities:
                    capabilityRegistry.all
            )

        var diagnostics: [String] = []

        if !contract.requiresMutation {
            diagnostics.append(
                "Gerçek edit görevi mutation outcome olarak sınıflandırılmadı."
            )
        }

        if resolution.isFullyCovered {
            diagnostics.append(
                "premiere.control available değilken mutation outcome yanlışlıkla fully covered sayıldı."
            )
        }

        if !resolution
            .chosenStrategies
            .contains(
                where: {
                    $0.requiresLearning &&
                    $0.capabilityIDs
                        .contains(
                            "premiere.control"
                        )
                }
            ) {
            diagnostics.append(
                "Gerçek mutation capability eksikliği Learning stratejisine yükseltilmedi."
            )
        }

        if resolution
            .suppressedLearningCapabilityIDs
            .contains(
                "premiere.control"
            ) {
            diagnostics.append(
                "Mutation capability yanlışlıkla Learning gate tarafından bastırıldı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "outcome-mutation-requires-real-capability",
            title:
                "Gerçek değişiklik outcome'u capability yoksa Learning istemeli",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Salt-okunur alternatiflerle gerçek edit capability eksikliğini gizleme",
            route: [
                "Core",
                "Outcome",
                "Learning Gate"
            ],
            selectedCapabilities:
                resolution
                    .chosenStrategies
                    .flatMap(
                        \.capabilityIDs
                    )
                    .uniquedForTraining(),
            unavailableCapabilities: [
                "premiere.control"
            ],
            diagnostics: diagnostics
        )
    }

    private func problemSolverUsesExistingStrategyBeforeLearningResult()
        -> TrainingScenarioResult {
        let step = AgentTaskGraphStep(
            index: 0,
            title: "Public web sayfasını oku",
            capabilityID: "browser.control",
            operation: "public site page read inspect",
            role: .retrieve,
            dependsOn: [],
            risk: .external,
            isAvailable: false,
            requiresApproval: false
        )

        let graph = AgentTaskGraph(
            objective:
                "Public bir web sayfasındaki bilgiyi oku",
            steps: [step]
        )

        let resolution =
            problemSolver.solve(
                graph: graph,
                capabilities:
                    capabilityRegistry.all,
                observations: []
            )

        var diagnostics: [String] = []

        if resolution.chosenStrategy?
            .requiresLearning == true {
            diagnostics.append(
                "Mevcut güvenli alternatifler varken Problem Solver Learning stratejisini seçti."
            )
        }

        let executableAlternatives =
            resolution.strategies.filter {
                $0.executableNow &&
                !$0.requiresLearning
            }

        if executableAlternatives.isEmpty {
            diagnostics.append(
                "Blocked browser step için mevcut capability'lerden hiçbir çözüm stratejisi üretilmedi."
            )
        }

        if !resolution.strategies.contains(
            where: {
                $0.kind ==
                    .publicResearch ||
                $0.kind ==
                    .screenObservation ||
                $0.kind ==
                    .genericAppWorkflow
            }
        ) {
            diagnostics.append(
                "Public/read-only problem için generic çözüm alternatifleri eksik."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "problem-solver-before-learning",
            title:
                "Problem Solver Learning'den önce mevcut stratejileri denemeli",
            tier: .core,
            prompt:
                "Public web sayfasındaki bilgiyi oku",
            passed: diagnostics.isEmpty,
            goal:
                "Mevcut güvenli capability kombinasyonunu öğrenmeden önce seç",
            route: [
                "Core",
                "Problem Solver",
                "Strategy"
            ],
            selectedCapabilities:
                executableAlternatives
                    .flatMap(
                        \.capabilityIDs
                    )
                    .uniquedForTraining(),
            unavailableCapabilities: [
                "browser.control"
            ],
            diagnostics: diagnostics
        )
    }

    private func problemSolverReflectionChoosesAnotherSafeStrategyResult()
        -> TrainingScenarioResult {
        let step = AgentTaskGraphStep(
            index: 0,
            title: "Uygulamadaki görünür bilgiyi oku",
            capabilityID: "browser.control",
            operation:
                "observe active application visible state",
            role: .retrieve,
            dependsOn: [],
            risk: .external,
            isAvailable: false,
            requiresApproval: false
        )

        let initial =
            problemSolver.strategiesForStep(
                step,
                capabilities:
                    capabilityRegistry.all,
                dependencyEvidence: ""
            )

        guard let first =
            initial.first(
                where: {
                    $0.executableNow &&
                    !$0.requiresLearning
                }
            )
        else {
            return TrainingScenarioResult(
                scenarioID:
                    "problem-solver-reflection",
                title:
                    "Problem Solver başarısız stratejiden sonra yeniden planlamalı",
                tier: .core,
                prompt:
                    "Uygulamadaki görünür bilgiyi oku",
                passed: false,
                goal:
                    "İkinci güvenli stratejiyi seç",
                route: [
                    "Core",
                    "Problem Solver",
                    "Reflection"
                ],
                selectedCapabilities: [],
                unavailableCapabilities: [
                    "browser.control"
                ],
                diagnostics: [
                    "İlk güvenli strateji üretilemedi."
                ]
            )
        }

        let reflected =
            problemSolver.reflection(
                step: step,
                attemptedStrategyIDs: [
                    first.id
                ],
                dependencyEvidence: "",
                capabilities:
                    capabilityRegistry.all
            )

        var diagnostics: [String] = []

        if reflected.chosenStrategyID ==
            first.id {
            diagnostics.append(
                "Reflection başarısız ilk stratejiyi tekrar seçti."
            )
        }

        if reflected.chosenStrategy?
            .requiresLearning == true,
           initial.filter({
                $0.executableNow &&
                !$0.requiresLearning &&
                $0.id != first.id
           }).isEmpty == false {
            diagnostics.append(
                "Denenmemiş güvenli strateji varken Learning'e geçildi."
            )
        }

        if reflected.reflection == nil {
            diagnostics.append(
                "Reflection gerekçesi üretilmedi."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "problem-solver-reflection",
            title:
                "Problem Solver başarısız stratejiden sonra yeniden planlamalı",
            tier: .core,
            prompt:
                "Uygulamadaki görünür bilgiyi oku",
            passed: diagnostics.isEmpty,
            goal:
                "Başarısız ilk stratejiden sonra denenmemiş güvenli çözümü seç",
            route: [
                "Core",
                "Problem Solver",
                "Reflection"
            ],
            selectedCapabilities:
                reflected.chosenStrategy?
                    .capabilityIDs ?? [],
            unavailableCapabilities: [
                "browser.control"
            ],
            diagnostics: diagnostics
        )
    }

    private func fileQueryDesktopScopeResult()
        -> TrainingScenarioResult {
        let prompt =
            "masaüstündeki dosyaları bul"
        let query =
            fileQueryParser.parse(prompt)

        var diagnostics: [String] = []

        if query.scope != .desktop {
            diagnostics.append(
                "Masaüstü kapsamı desktop olarak ayrıştırılmadı."
            )
        }

        if !query.filenameQuery.isEmpty {
            diagnostics.append(
                "Scope/komut kelimeleri filename query'ye sızdı: " +
                query.filenameQuery
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-query-desktop-scope",
            title:
                "Dosya sorgusunda Masaüstü kapsamını ayırma",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Scope=Desktop, filenameQuery=boş",
            route: [
                "Core",
                "Files",
                "Query Parser"
            ],
            selectedCapabilities: [
                "files.search"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func fileQueryDownloadsPDFResult()
        -> TrainingScenarioResult {
        let prompt =
            "indirilenlerdeki PDF'leri bul"
        let query =
            fileQueryParser.parse(prompt)

        var diagnostics: [String] = []

        if query.scope != .downloads {
            diagnostics.append(
                "İndirilenler kapsamı downloads olarak ayrıştırılmadı."
            )
        }

        if !query.filenameQuery.isEmpty {
            diagnostics.append(
                "Dosya türü/scope kelimeleri filename query'ye sızdı: " +
                query.filenameQuery
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-query-downloads-pdf",
            title:
                "Dosya türünü filename sorgusundan ayırma",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Scope=Downloads, PDF target ayrı, filenameQuery=boş",
            route: [
                "Core",
                "Files",
                "Query Parser"
            ],
            selectedCapabilities: [
                "files.search",
                "files.metadata"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func fileQuerySubstringSafetyResult()
        -> TrainingScenarioResult {
        let prompt =
            "bu sunum dosyasını bul"
        let query =
            fileQueryParser.parse(prompt)

        var diagnostics: [String] = []

        if query.filenameQuery != "sunum" {
            diagnostics.append(
                "Token-temelli temizlik beklenen 'sunum' sorgusunu üretmedi: " +
                query.filenameQuery
            )
        }

        let actionProbe =
            fileQueryParser.parse(
                "bu dosyayı bul"
            )

        if actionProbe.filenameQuery.contains("l") {
            diagnostics.append(
                "'bu' tokenı 'bul' fiilinin içinden substring olarak silindi."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-query-substring-safety",
            title:
                "Dosya sorgusunda substring silme regresyonu",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Tam token temizliği; filenameQuery=sunum",
            route: [
                "Core",
                "Files",
                "Query Parser"
            ],
            selectedCapabilities: [
                "files.search"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func fileQueryArchiveExtensionResult()
        -> TrainingScenarioResult {
        let prompt =
            "indirilenlerdeki zip dosyalarını bul"
        let query =
            fileQueryParser.parse(prompt)

        var diagnostics: [String] = []

        if query.scope != .downloads ||
           !query.scopeIsExplicit {
            diagnostics.append(
                "İndirilenler explicit scope olarak çözümlenmedi."
            )
        }

        if query.extensions != Set(["zip"]) {
            diagnostics.append(
                "ZIP uzantısı structured type filter olarak çözümlenmedi: " +
                query.extensions.sorted()
                    .joined(separator: ",")
            )
        }

        if !query.filenameQuery.isEmpty {
            diagnostics.append(
                "ZIP/type/scope kelimeleri filename query'ye sızdı: " +
                query.filenameQuery
            )
        }

        if !query.isFileSearchRequest {
            diagnostics.append(
                "Structured query file-search isteği olarak işaretlenmedi."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-query-archive-extension",
            title:
                "Arşiv uzantısını structured filtreye ayırma",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Scope=Downloads, extensions=zip, filenameQuery=boş",
            route: [
                "Core",
                "Files",
                "Query Parser"
            ],
            selectedCapabilities: [
                "files.search",
                "files.metadata"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func fileQueryInflectedBrainIntentResult()
        -> TrainingScenarioResult {
        let prompt =
            "indirilenlerdeki zipleri bul"

        let decision = brain.analyze(
            prompt,
            context: context(
                hasWorkspace: true
            )
        )

        let query =
            fileQueryParser.parse(prompt)

        var diagnostics: [String] = []

        if decision.intent != .fileSearch {
            diagnostics.append(
                "Brain çekimli ZIP sorgusunu fileSearch intent olarak seçmedi."
            )
        }

        if query.extensions != Set(["zip"]) {
            diagnostics.append(
                "Çekimli ZIP tokenı uzantı filtresine dönüşmedi."
            )
        }

        if !query.filenameQuery.isEmpty {
            diagnostics.append(
                "Çekimli ZIP sorgusunda filename query boş kalmadı: " +
                query.filenameQuery
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-query-inflected-brain-intent",
            title:
                "Çekimli uzantı sorgusunu fileSearch intent'e yönlendirme",
            tier: .core,
            prompt: prompt,
            passed: diagnostics.isEmpty,
            goal:
                "Brain + parser aynı structured file intent'i paylaşmalı",
            route: decision.route,
            selectedCapabilities: [
                "files.search"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func fileSemanticMetamorphicFamilyResult()
        -> TrainingScenarioResult {
        let cases: [(
            id: String,
            prompt: String,
            scope: AgentFileSearchScope,
            target: AgentTargetKind,
            sortMode: AgentSortMode,
            dateField: AgentDateField,
            resultLimit: Int?,
            output: AgentFileOutputProjection,
            extensions: Set<String>,
            prohibitions: Set<AgentFileQueryProhibition>
        )] = [
            (
                id: "desktop-image-modified",
                prompt:
                    "Masaüstündeki en son değiştirilen görsel dosyasının sadece adını söyle. Dosyayı açma veya değiştirme.",
                scope: .desktop,
                target: .image,
                sortMode: .newestFirst,
                dateField: .modified,
                resultLimit: 1,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.open, .modify]
            ),
            (
                id: "downloads-pdf-created",
                prompt:
                    "İndirilenler klasöründeki son indirilen PDF dosyasının yalnızca adını ver. Dosyayı açma.",
                scope: .downloads,
                target: .pdf,
                sortMode: .newestFirst,
                dateField: .created,
                resultLimit: 1,
                output: .namesOnly,
                extensions: ["pdf"],
                prohibitions: [.open]
            ),
            (
                id: "documents-document-modified",
                prompt:
                    "Belgeler klasöründeki bugün değiştirilen belgelerin isimlerini listele; hiçbirini değiştirme.",
                scope: .documents,
                target: .document,
                sortMode: .relevance,
                dateField: .modified,
                resultLimit: nil,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.modify]
            ),
            (
                id: "desktop-video-modified",
                prompt:
                    "Masaüstündeki son değiştirilen videonun adını göster, dosyayı açma.",
                scope: .desktop,
                target: .video,
                sortMode: .newestFirst,
                dateField: .modified,
                resultLimit: 1,
                output: .namesOnly,
                extensions: [],
                prohibitions: [.open]
            ),
            (
                id: "downloads-archive-created",
                prompt:
                    "İndirilenler'deki son indirilen ZIP dosyasının sadece ismini söyle; taşıma veya silme.",
                scope: .downloads,
                target: .any,
                sortMode: .newestFirst,
                dateField: .created,
                resultLimit: 1,
                output: .namesOnly,
                extensions: ["zip"],
                prohibitions: [.move, .delete]
            )
        ]

        var diagnostics: [String] = []
        var selectedCapabilityIDs = Set<String>()

        for test in cases {
            let query =
                fileQueryParser.parse(
                    test.prompt
                )

            let decision =
                brain.analyze(
                    test.prompt,
                    context:
                        context(
                            hasWorkspace: true
                        )
                )

            let goal =
                goalInterpreter.interpret(
                    test.prompt,
                    decision: decision,
                    context:
                        context(
                            hasWorkspace: true
                        )
                )

            let actualTarget =
                fileQueryParser
                    .resolveTargetEntity(
                        test.prompt
                    )

            if decision.intent != .fileSearch {
                diagnostics.append(
                    "[intent][\(test.id)] fileSearch seçilmedi."
                )
            }

            if !query.isFileSearchRequest {
                diagnostics.append(
                    "[intent][\(test.id)] structured query retrieval contract üretmedi."
                )
            }

            if query.scope != test.scope ||
               !query.scopeIsExplicit {
                diagnostics.append(
                    "[scope][\(test.id)] beklenen explicit scope korunmadı."
                )
            }

            if actualTarget != test.target {
                diagnostics.append(
                    "[entity][\(test.id)] hedef entity yanlış çözüldü."
                )
            }

            if query.sortMode != test.sortMode ||
               query.dateField != test.dateField ||
               query.resultLimit != test.resultLimit {
                diagnostics.append(
                    "[rank][\(test.id)] ordering/date/limit semantic contract uyuşmuyor."
                )
            }

            if query.outputProjection != test.output {
                diagnostics.append(
                    "[output][\(test.id)] output projection korunmadı."
                )
            }

            if query.extensions != test.extensions {
                diagnostics.append(
                    "[entity][\(test.id)] extension/type filtresi uyuşmuyor."
                )
            }

            if !test.prohibitions
                .isSubset(
                    of:
                        query.prohibitions
                ) {
                diagnostics.append(
                    "[safety][\(test.id)] kullanıcı prohibitions eksik çözüldü."
                )
            }

            if !goal.requiredCapabilityIDs
                .contains(
                    "files.search"
                ) {
                diagnostics.append(
                    "[capability][\(test.id)] files.search capability contract'a taşınmadı."
                )
            }

            selectedCapabilityIDs.formUnion(
                goal.requiredCapabilityIDs
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "file-semantic-metamorphic-family",
            title:
                "Aynı dosya hedefini farklı cümlelerle otomatik sınama",
            tier: .core,
            prompt:
                "5 semantic varyasyon: scope/entity/rank/output/safety",
            passed: diagnostics.isEmpty,
            goal:
                "Tek senaryoya hard-code yazmadan aynı semantic contract'ı farklı ifadelerde koru",
            route: [
                "Core",
                "Gym",
                "Semantic Contract",
                "Files",
                "Verify"
            ],
            selectedCapabilities:
                selectedCapabilityIDs
                    .sorted(),
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func namedTopicMemoryIsolationResult()
        -> TrainingScenarioResult {
        let store = AgentContextMemoryStore()

        let estafizResearch = AgentContextMemoryEntry(
            kind: .research,
            title:
                "estafizsym instagram sayfasını incele ve bana detaylı bir rapor sun",
            summary:
                "Estafiz SYM; Reformer ve Klinik Pilates odaklı marka araştırması.",
            userInput:
                "estafizsym instagram sayfasını incele ve bana detaylı bir rapor sun",
            goal:
                "güncel kaynaklarla araştır"
        )

        let estafizIdeas = AgentContextMemoryEntry(
            kind: .task,
            title:
                "bu hesap için az önce söylediklerinden 3 özgün reels fikri çıkar",
            summary:
                "@estafizsym için Reformer ve Klinik Pilates konumlandırmasına dayalı üç Reels fikri.",
            userInput:
                "bu hesap için az önce söylediklerinden 3 özgün reels fikri çıkar",
            goal:
                "bağımsız fikir ve çıkarım üret"
        )

        let sonyComparison = AgentContextMemoryEntry(
            kind: .task,
            title:
                "Sony A7 IV ile Fuji X-T5 arasında video açısından temel farklar neler?",
            summary:
                "Sony ve Fuji video özelliklerinin karşılaştırması; profesyonel video üretimi ve renk profilleri.",
            userInput:
                "Sony A7 IV ile Fuji X-T5 arasında video açısından temel farklar neler?",
            goal:
                "bulguları analiz et"
        )

        let query =
            "Estafiz için 30 saniyelik bir Reels çekim planı hazırla. 3 bölüm olsun: açılış, ana mesaj ve kapanış."

        let selected = store.relevant(
            to: query,
            from: [
                sonyComparison,
                estafizResearch,
                estafizIdeas
            ],
            limit: 4
        )

        var diagnostics: [String] = []

        if selected.contains(
            where: { $0.id == sonyComparison.id }
        ) {
            diagnostics.append(
                "Açık Estafiz görevi sırasında alakasız Sony/Fuji bağlamı geri çağrıldı."
            )
        }

        if !selected.contains(
            where: {
                $0.id == estafizResearch.id ||
                $0.id == estafizIdeas.id
            }
        ) {
            diagnostics.append(
                "Estafiz ile ilgili bağlam bulunamadı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "named-topic-memory-isolation",
            title:
                "Adı verilen konuyu alakasız hafızadan ayırma",
            tier: .core,
            prompt: query,
            passed: diagnostics.isEmpty,
            goal:
                "Estafiz bağlamını seç; alakasız kamera hafızasını dışarıda bırak",
            route: [
                "Core",
                "Context",
                "Memory"
            ],
            selectedCapabilities: [
                "context.local",
                "core.reasoning"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func executionContextFirewallResult()
        -> TrainingScenarioResult {
        let store = AgentContextMemoryStore()

        let staleTask = AgentContextMemoryEntry(
            kind: .task,
            title:
                "mail uygulamasını aç son gelen maili kontrol et",
            summary:
                "Önceki görevden kalmış, bu yeni görev için güvenilir olmayan sentez metni.",
            userInput:
                "mail uygulamasını aç son gelen maili kontrol et",
            goal:
                "önceki mail görevini yürüt"
        )

        let persistentRule = AgentContextMemoryEntry(
            kind: .userRule,
            title: "Çalışma kuralı",
            summary:
                "Mail gönderiminde dış dünyaya göndermeden önce kullanıcı onayı iste."
        )

        let query =
            "Mail uygulamasını aç, son gelen maili incele ve cevap taslağı hazırla."

        let recalled = store.relevant(
            to: query,
            from: [
                staleTask,
                persistentRule
            ],
            limit: 4
        )

        let executionContext =
            store.executionContext(
                to: query,
                from: recalled,
                limit: 4
            )

        var diagnostics: [String] = []

        if executionContext.contains(
            where: { $0.id == staleTask.id }
        ) {
            diagnostics.append(
                "Bağımsız yeni görevde önceki task metni execution/synthesis bağlamına sızdı."
            )
        }

        if recalled.contains(
            where: { $0.id == persistentRule.id }
        ) &&
           !executionContext.contains(
                where: { $0.id == persistentRule.id }
           ) {
            diagnostics.append(
                "Kalıcı kullanıcı kuralı execution bağlamından yanlışlıkla çıkarıldı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "execution-context-firewall",
            title:
                "Yeni görev sentezini eski task metninden ayırma",
            tier: .core,
            prompt: query,
            passed: diagnostics.isEmpty,
            goal:
                "Yalnız açık devam referansında önceki task/research metnini taşı",
            route: [
                "Core",
                "Context",
                "Verify"
            ],
            selectedCapabilities: [
                "context.local",
                "core.reasoning"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func newBrandIntroductionIsolationResult()
        -> TrainingScenarioResult {
        let store = AgentContextMemoryStore()

        let estafizResearch = AgentContextMemoryEntry(
            kind: .research,
            title: "estafizsym instagram sayfasını incele",
            summary:
                "Estafiz Reformer ve Klinik Pilates marka araştırması.",
            userInput:
                "estafizsym instagram sayfasını incele ve detaylı rapor sun",
            goal: "markayı araştır"
        )

        let estafizTask = AgentContextMemoryEntry(
            kind: .task,
            title: "Estafiz için Reels çalışması",
            summary:
                "Estafiz'e özel sosyal medya video çalışma planı.",
            userInput:
                "Estafiz için sosyal medya videosu hazırla",
            goal: "içerik üret"
        )

        let query =
            "dönerci ahmet adında bir markamız var. Bu marka hakkında bir sosyal medya tasarımı hazırlamak istiyorum."

        let selected = store.relevant(
            to: query,
            from: [
                estafizTask,
                estafizResearch
            ],
            limit: 4
        )

        let decision = brain.analyze(
            query,
            context: context(
                relevantMemoryCount: 2,
                lastMemoryGoal:
                    "Estafiz için sosyal medya içeriği üret"
            )
        )

        var diagnostics: [String] = []

        if !selected.isEmpty {
            diagnostics.append(
                "Açıkça yeni marka tanıtıldığı halde eski Estafiz task/research hafızası geri çağrıldı."
            )
        }

        if decision.goal ==
            "Önceki görev bağlamını kullanarak devam et" {
            diagnostics.append(
                "Yeni marka isteği eski görev continuation'ı olarak yorumlandı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "new-brand-introduction-isolation",
            title:
                "Yeni markayı eski marka bağlamından ayırma",
            tier: .core,
            prompt: query,
            passed: diagnostics.isEmpty,
            goal:
                "Yeni markayı bağımsız hedef olarak ele al",
            route: [
                "Core",
                "Goal",
                "Context"
            ],
            selectedCapabilities: [
                "core.reasoning",
                "context.local"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func memoryTransformSourceResolutionResult()
        -> TrainingScenarioResult {
        let store = AgentContextMemoryStore()

        let research = AgentContextMemoryEntry(
            kind: .research,
            title: "estafizsym instagram sayfasını incele",
            summary:
                "@estafizsym Reformer ve Klinik Pilates hesabı için doğrulanmış araştırma özeti.",
            userInput:
                "estafizsym instagram sayfasını incele ve bana detaylı bir rapor sun",
            goal:
                "güncel kaynaklarla araştır → sonucu ve gerekçeyi açıkla"
        )

        let ideas = AgentContextMemoryEntry(
            kind: .task,
            title: "3 özgün Reels fikri",
            summary:
                "1. Aynı hareket, üç farklı beden. 2. Vücudunun küçük sinyalleri. 3. Reformer dedektifi.",
            userInput:
                "bu hesap için az önce söylediklerinden 3 özgün reels fikri çıkar",
            goal:
                "bağımsız fikir ve çıkarım üret"
        )

        let priorTransform = AgentContextMemoryEntry(
            kind: .task,
            title: "önceki dönüşüm denemesi",
            summary:
                "Birden çok alternatif fikir üretildi; tek fikrin senaryoya dönüşümü tamamlanmadı.",
            userInput:
                "şimdi Estafiz'e dön, az önceki Reels fikirlerinden birincisini 30 saniyelik çekim senaryosuna çevir",
            goal:
                "önceki çıktıyı istenen formata dönüştür"
        )

        let query =
            "şimdi Estafiz'e dön, az önceki Reels fikirlerinden birincisini 30 saniyelik çekim senaryosuna çevir"

        let selected = store.relevant(
            to: query,
            from: [
                priorTransform,
                research,
                ideas
            ],
            limit: 3
        )

        var diagnostics: [String] = []

        if selected.first?.id != ideas.id {
            diagnostics.append(
                "Dönüşüm için kaynak fikir listesi ilk bağlam olarak seçilmedi."
            )
        }

        if selected.contains(
            where: { $0.id == priorTransform.id }
        ) {
            diagnostics.append(
                "Önceki dönüşüm denemesi kaynak bağlama yeniden sızdı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "context-transform-source-resolution",
            title:
                "Dönüşüm kaynağını doğru hafızadan seçme",
            tier: .core,
            prompt: query,
            passed: diagnostics.isEmpty,
            goal:
                "referans verilen önceki fikir listesini kaynak olarak seç",
            route: [
                "Core",
                "Context",
                "Memory"
            ],
            selectedCapabilities: [
                "context.local",
                "core.reasoning"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func shortAppOpenLanguageResult()
        -> TrainingScenarioResult {
        let prompt = "spotifyı aç"
        let score =
            languageResolver.bestAliasScore(
                input: prompt,
                aliases: ["Spotify"]
            )
        let passed =
            languageResolver.isSimpleOpenCommand(
                prompt
            ) &&
            languageResolver
                .isConfidentAliasMatch(
                    score: score,
                    input: prompt
                )

        return TrainingScenarioResult(
            scenarioID:
                "natural-language-short-app-open",
            title:
                "Kısa uygulama açma komutunu algılama",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "uygulama kelimesi olmadan hedef uygulamayı aç",
            route: ["Core", "Desktop"],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Kısa app-open komutu güvenilir biçimde çözülemedi."
                ]
        )
    }

    private func inflectedAppNameLanguageResult()
        -> TrainingScenarioResult {
        let prompt = "takvimi aç"
        let score =
            languageResolver.bestAliasScore(
                input: prompt,
                aliases: ["Takvim"]
            )
        let passed =
            languageResolver.isSimpleOpenCommand(
                prompt
            ) &&
            languageResolver
                .isConfidentAliasMatch(
                    score: score,
                    input: prompt
                )

        return TrainingScenarioResult(
            scenarioID:
                "natural-language-inflected-app-name",
            title:
                "Türkçe ekli uygulama adını çözme",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Türkçe belirtme ekini uygulama adından ayır",
            route: ["Core", "Desktop"],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Türkçe ekli uygulama adı normalize edilemedi."
                ]
        )
    }

    private func candidateAliasSuffixIsolationResult()
        -> TrainingScenarioResult {
        let canonicalAliasScore =
            languageResolver.bestAliasScore(
                input: "exampl",
                aliases: ["Example"]
            )

        let inflectedUserScore =
            languageResolver.bestAliasScore(
                input: "takvimi",
                aliases: ["Takvim"]
            )

        let passed =
            canonicalAliasScore < 1.0 &&
            inflectedUserScore == 1.0

        var diagnostics: [String] = []

        if canonicalAliasScore >= 1.0 {
            diagnostics.append(
                "Candidate alias Türkçe suffix stripping ile yapay exact forma dönüştürüldü."
            )
        }

        if inflectedUserScore < 1.0 {
            diagnostics.append(
                "Kullanıcı tarafındaki Türkçe çekim çözümleme regression oluşturdu."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "candidate-alias-suffix-isolation",
            title:
                "Candidate aliaslarında Türkçe suffix stripping izolasyonu",
            tier: .core,
            prompt:
                "Canonical app aliaslarını dil-spesifik ek kurallarıyla değiştirme",
            passed: passed,
            goal:
                "Türkçe ek çözümünü yalnız kullanıcı girdisine uygula; canonical candidate aliaslarını bozma",
            route: [
                "Core",
                "Language",
                "Desktop"
            ],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func semanticExactAliasSafetyResult()
        -> TrainingScenarioResult {
        let exact =
            languageResolver
                .isExactApplicationAliasMatch(
                    input: "Example",
                    aliases: [
                        "Example",
                        "Örnek"
                    ]
                )

        let fuzzy =
            languageResolver
                .isExactApplicationAliasMatch(
                    input: "Exampl",
                    aliases: [
                        "Example"
                    ]
                )

        let passed =
            exact &&
            !fuzzy

        return TrainingScenarioResult(
            scenarioID:
                "semantic-app-exact-alias-safety",
            title:
                "Semantic uygulama hedefinde exact alias güvenlik kapısı",
            tier: .core,
            prompt:
                "Semantic isim varyantı yalnız gerçek canonical alias ile birebir eşleşirse candidate seç",
            passed: passed,
            goal:
                "Fuzzy/prefix benzerliğinin semantic uygulama seçimini tetiklemesini engelle",
            route: [
                "Core",
                "Language",
                "Desktop",
                "Safety"
            ],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Semantic exact alias gate fuzzy/prefix eşleşmeye izin verdi veya exact aliası reddetti."
                ]
        )
    }

    private func strictExternalApprovalResult()
        -> TrainingScenarioResult {
        let desktop =
            capabilityRegistry.all.first {
                $0.id == "desktop.app"
            }
        let reveal =
            capabilityRegistry.all.first {
                $0.id == "files.reveal"
            }
        let research =
            capabilityRegistry.all.first {
                $0.id == "research.web"
            }

        let desktopApproval =
            taskOrchestrator
                .approvalReason(
                    title:
                        "Uygulama kontrolü",
                    operation:
                        "capability.contract",
                    capability:
                        desktop
                )

        let revealApproval =
            taskOrchestrator
                .approvalReason(
                    title:
                        "Finder'da göster",
                    operation:
                        "files.reveal",
                    capability:
                        reveal
                )

        let researchApproval =
            taskOrchestrator
                .approvalReason(
                    title:
                        "Web araştır",
                    operation:
                        "research.web",
                    capability:
                        research
                )

        let passed =
            desktopApproval != nil &&
            revealApproval != nil &&
            researchApproval == nil

        var diagnostics: [String] = []

        if desktopApproval == nil {
            diagnostics.append(
                "desktop.app capability.contract Strict Approval kapısını atladı."
            )
        }

        if revealApproval == nil {
            diagnostics.append(
                "Finder görünür etkileşimi Strict Approval kapısını atladı."
            )
        }

        if researchApproval != nil {
            diagnostics.append(
                "Salt-okunur statik web araştırması gereksiz kullanıcı onayına bağlandı."
            )
        }

        return TrainingScenarioResult(
            scenarioID:
                "strict-external-action-approval",
            title:
                "Dış kullanıcı etkileşimlerinde Strict Approval",
            tier: .core,
            prompt:
                "Kullanıcı cihazında görünür işlem yapmadan önce chat onayı iste",
            passed: passed,
            goal:
                "Uygulama/Finder gibi kullanıcı yüzeylerini onaysız değiştirme; salt-okunur araştırmayı bloklama",
            route: [
                "Core",
                "Safety",
                "Approval"
            ],
            selectedCapabilities: [
                "desktop.app",
                "files.reveal"
            ],
            unavailableCapabilities: [],
            diagnostics: diagnostics
        )
    }

    private func typoAppNameLanguageResult()
        -> TrainingScenarioResult {
        let prompt = "spotfiy aç"
        let score =
            languageResolver.bestAliasScore(
                input: prompt,
                aliases: ["Spotify"]
            )
        let passed =
            languageResolver.isSimpleOpenCommand(
                prompt
            ) &&
            languageResolver
                .isConfidentAliasMatch(
                    score: score,
                    input: prompt
                )

        return TrainingScenarioResult(
            scenarioID:
                "natural-language-typo-app-name",
            title:
                "Küçük yazım hatalı uygulama adını çözme",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "küçük yazım hatasını güvenli fuzzy eşleşmeyle düzelt",
            route: ["Core", "Desktop"],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Yakın yazım hatası güven eşiğini geçemedi."
                ]
        )
    }

    private func duplicateApplicationAliasMergeResult()
        -> TrainingScenarioResult {
        let aliases =
            languageResolver
                .mergedAliases(
                    [
                        ["Example", "Example"],
                        ["Örnek", " example "]
                    ]
                )

        let score =
            languageResolver
                .bestAliasScore(
                    input:
                        "örnek uygulamasını aç",
                    aliases: aliases
                )

        let passed =
            aliases.contains("Example") &&
            aliases.contains("Örnek") &&
            aliases.count == 2 &&
            languageResolver
                .isConfidentAliasMatch(
                    score: score,
                    input: "örnek"
                )

        return TrainingScenarioResult(
            scenarioID:
                "duplicate-application-localized-alias-merge",
            title:
                "Aynı bundle için yerelleştirilmiş uygulama aliaslarını koruma",
            tier: .core,
            prompt:
                "Örnek uygulamasını aç",
            passed: passed,
            goal:
                "Çalışan uygulama ve disk kaynaklarından gelen aynı bundle aliaslarını kaybetmeden birleştir",
            route: [
                "Core",
                "Desktop"
            ],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Duplicate bundle birleştirmesi yerelleştirilmiş aliası kaybetti."
                ]
        )
    }

    private func localizedApplicationDisplayTargetResult()
        -> TrainingScenarioResult {
        let settingsPrompt =
            "Sistem Ayarları uygulamasını aç ve gerçekten ön planda olduğunu doğrula."

        let safariPrompt =
            "Safari’yi aç. Başka hiçbir işlem yapma."

        let settings =
            languageResolver
                .applicationTargetDisplayPhrase(
                    from: settingsPrompt
                )

        let safari =
            languageResolver
                .applicationTargetDisplayPhrase(
                    from: safariPrompt
                )

        let passed =
            settings == "Sistem Ayarları" &&
            safari == "Safari"

        return TrainingScenarioResult(
            scenarioID:
                "localized-application-display-target",
            title:
                "LaunchServices için kullanıcıdaki uygulama adını koruma",
            tier: .core,
            prompt: settingsPrompt,
            passed: passed,
            goal:
                "Yerelleştirilmiş uygulama adını normalize etmeden macOS çözümleyicisine aktar",
            route: [
                "Core",
                "Desktop",
                "LaunchServices"
            ],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Yerelleştirilmiş uygulama hedefi korunamadı: settings=" +
                    (settings ?? "nil") +
                    " safari=" +
                    (safari ?? "nil")
                ]
        )
    }

    private func prohibitedAppMutationDoesNotAddWorkflowResult()
        -> TrainingScenarioResult {
        let prompt =
            "Sistem Ayarları uygulamasını aç ve gerçekten ön planda olduğunu doğrula. Herhangi bir ayarı değiştirme."

        let snapshot =
            context(
                hasWorkspace: true,
                videoCount: 0
            )

        let decision =
            brain.analyze(
                prompt,
                context: snapshot
            )

        let goal =
            goalInterpreter.interpret(
                prompt,
                decision: decision,
                context: snapshot
            )

        let rawMission =
            AgentSemanticMission(
                objective: prompt,
                outcomes:
                    goal.outcomes
                        .map(\.rawValue)
                        .sorted(),
                steps: [],
                requiredCapabilityIDs:
                    Array(
                        goal.requiredCapabilityIDs
                    )
                    .sorted(),
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 0.9
            )

        let normalized =
            missionNormalizer.normalize(
                rawMission,
                userInput: prompt,
                capabilities:
                    capabilityRegistry.all
            )

        let required =
            Set(
                normalized
                    .requiredCapabilityIDs
            )

        let passed =
            required.contains(
                "desktop.app"
            ) &&
            !required.contains(
                "app.workflow"
            ) &&
            !normalized.steps.contains {
                $0.capabilityID ==
                    "app.workflow"
            }

        return TrainingScenarioResult(
            scenarioID:
                "prohibited-app-mutation-no-workflow",
            title:
                "Negatif uygulama talimatını workflow isteği saymama",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Yalnız uygulamayı aç ve foreground doğrula; yasaklanan değişikliği capability isteği sayma",
            route: [
                "Core",
                "Goal",
                "Desktop"
            ],
            selectedCapabilities:
                normalized
                    .requiredCapabilityIDs,
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Negatif 'değiştirme' talimatı app.workflow capability'sini yanlışlıkla ekledi."
                ]
        )
    }

    private func appOpenIntentRoutingResult(
        id: String,
        title: String,
        prompt: String,
        forbiddenCapabilityID: String
    ) -> TrainingScenarioResult {
        let snapshot = context(
            hasWorkspace: true,
            videoCount: 0
        )

        let decision = brain.analyze(
            prompt,
            context: snapshot
        )
        let goal = goalInterpreter.interpret(
            prompt,
            decision: decision,
            context: snapshot
        )
        let capabilities =
            capabilityRegistry.select(
                for: prompt,
                decision: decision,
                context: snapshot,
                goal: goal
            )
        let ids = Set(
            capabilities.map(\.id)
        )

        let passed =
            ids.contains("desktop.app") &&
            !ids.contains(
                forbiddenCapabilityID
            )

        return TrainingScenarioResult(
            scenarioID: id,
            title: title,
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "uygulama açma isteğini uygulama capability'sine yönlendir",
            route: [
                "Core",
                "Desktop"
            ],
            selectedCapabilities:
                capabilities.map(\.id),
            unavailableCapabilities:
                capabilities
                    .filter { !$0.isAvailable }
                    .map(\.id),
            diagnostics: passed
                ? []
                : [
                    "App-open intent yanlış capability ailesine yönlendirildi: " +
                    ids.sorted()
                        .joined(separator: ", ")
                ]
        )
    }

    private func mailWorkflowRoutingResult()
        -> TrainingScenarioResult {
        let prompt =
            "Bugün yaptıklarımı müdürüme göndermek için mail taslağı hazırla."
        let snapshot = context(
            hasWorkspace: true,
            videoCount: 0
        )
        let decision = brain.analyze(
            prompt,
            context: snapshot
        )
        let goal = goalInterpreter.interpret(
            prompt,
            decision: decision,
            context: snapshot
        )
        let capabilities =
            capabilityRegistry.select(
                for: prompt,
                decision: decision,
                context: snapshot,
                goal: goal
            )
        let ids = Set(
            capabilities.map(\.id)
        )

        let passed =
            ids.contains("mail.work") &&
            !ids.contains("desktop.app")

        return TrainingScenarioResult(
            scenarioID:
                "mail-workflow-routing",
            title:
                "Mail uygulaması ile mail iş akışını ayırma",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "mail taslağı isteğini iletişim capability'sine yönlendir",
            route: [
                "Core",
                "Mail"
            ],
            selectedCapabilities:
                capabilities.map(\.id),
            unavailableCapabilities:
                capabilities
                    .filter { !$0.isAvailable }
                    .map(\.id),
            diagnostics: passed
                ? []
                : [
                    "Mail workflow ile Mail.app açma intent'i ayrıştırılamadı."
                ]
        )
    }

    private func crossProviderTaskGraphResult()
        -> TrainingScenarioResult {
        let mission = AgentSemanticMission(
            objective:
                "Bir uygulamadaki mevcut içeriği oku, dış kaynaktan zenginleştir, analiz et ve çalışma alanına metin dosyası olarak kaydet.",
            outcomes: [
                "open",
                "research",
                "analyze",
                "compose"
            ],
            steps: [
                AgentSemanticMissionStep(
                    title: "Uygulamayı aç",
                    purpose:
                        "Kaynak uygulamayı görünür hale getir.",
                    capabilityID:
                        "desktop.app",
                    operation:
                        "app.open",
                    dependsOn: []
                ),
                AgentSemanticMissionStep(
                    title: "Mevcut içeriği oku",
                    purpose:
                        "Uygulamadaki mevcut içeriği kanıt olarak çıkar.",
                    capabilityID:
                        "perception.screen",
                    operation:
                        "screen.read",
                    dependsOn: [0]
                ),
                AgentSemanticMissionStep(
                    title: "Dış bilgiyi araştır",
                    purpose:
                        "Önceki adımda çözülen içeriği dış kaynaklarla zenginleştir.",
                    capabilityID:
                        "research.web",
                    operation:
                        "web.research",
                    dependsOn: [1]
                ),
                AgentSemanticMissionStep(
                    title: "Analiz et",
                    purpose:
                        "Okunan ve araştırılan içeriği birlikte analiz et.",
                    capabilityID:
                        "core.reasoning",
                    operation:
                        "content.analyze",
                    dependsOn: [1, 2]
                ),
                AgentSemanticMissionStep(
                    title: "Metin dosyasına yaz",
                    purpose:
                        "Analiz çıktısını hedef çalışma alanına yeni bir metin dosyası olarak kaydet.",
                    capabilityID:
                        "files.write.text",
                    operation:
                        "file.write.text",
                    dependsOn: [3]
                )
            ],
            requiredCapabilityIDs: [
                "desktop.app",
                "perception.screen",
                "research.web",
                "core.reasoning",
                "files.write.text"
            ],
            requiresUserInput: false,
            userInputReason: nil,
            confidence: 1
        )

        let graph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    capabilityRegistry.all
            )

        let roles =
            Dictionary(
                uniqueKeysWithValues:
                    graph.steps.map {
                        ($0.index, $0.role)
                    }
            )

        let passed =
            graph.steps.count == 5 &&
            roles[0] == .act &&
            roles[1] == .observe &&
            roles[2] == .retrieve &&
            roles[3] == .transform &&
            roles[4] == .persist &&
            graph.blockedCapabilityIDs
                .isEmpty &&
            graph.approvalStepIndexes
                .isEmpty

        return TrainingScenarioResult(
            scenarioID:
                "task-graph-cross-provider-dataflow",
            title:
                "Cross-provider veri akışı görev grafiği",
            tier: .core,
            prompt:
                "Uygulama verisini oku, araştır, analiz et ve dosyaya yaz.",
            passed: passed,
            goal:
                "Provider bağımsız dependency zinciri kur",
            route: [
                "Core",
                "Desktop",
                "Screen",
                "Research",
                "Files"
            ],
            selectedCapabilities:
                graph.steps.map(
                    \.capabilityID
                ),
            unavailableCapabilities:
                graph.blockedCapabilityIDs,
            diagnostics: passed
                ? []
                : [
                    "Cross-provider task graph rol/dependency/blocked capability sözleşmesi bozuldu."
                ]
        )
    }

    private func externalCommitApprovalGraphResult()
        -> TrainingScenarioResult {
        let mission = AgentSemanticMission(
            objective:
                "Bir iletiyi oku, analiz et, cevap taslağı hazırla ve kullanıcı onayından sonra gönder.",
            outcomes: [
                "analyze",
                "compose",
                "communicate"
            ],
            steps: [
                AgentSemanticMissionStep(
                    title: "İletiyi oku",
                    purpose:
                        "Son gelen iletiyi salt-okunur al.",
                    capabilityID:
                        "mail.work",
                    operation:
                        "mail.read",
                    dependsOn: []
                ),
                AgentSemanticMissionStep(
                    title: "İçeriği analiz et",
                    purpose:
                        "Okunan içeriğe göre yapılması gerekeni değerlendir.",
                    capabilityID:
                        "core.reasoning",
                    operation:
                        "content.analyze",
                    dependsOn: [0]
                ),
                AgentSemanticMissionStep(
                    title: "Cevap taslağı hazırla",
                    purpose:
                        "Analiz sonucuna uygun cevap taslağı oluştur.",
                    capabilityID:
                        "mail.work",
                    operation:
                        "mail.draft",
                    dependsOn: [1]
                ),
                AgentSemanticMissionStep(
                    title: "Gönder",
                    purpose:
                        "Hazırlanan taslağı kullanıcı onayından sonra dış dünyaya gönder.",
                    capabilityID:
                        "mail.work",
                    operation:
                        "mail.send",
                    dependsOn: [2]
                )
            ],
            requiredCapabilityIDs: [
                "mail.work",
                "core.reasoning"
            ],
            requiresUserInput: false,
            userInputReason: nil,
            confidence: 1
        )

        let graph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    capabilityRegistry.all
            )

        let passed =
            graph.approvalStepIndexes ==
                [3] &&
            graph.steps[0]
                .requiresApproval == false &&
            graph.steps[2]
                .requiresApproval == false &&
            graph.steps[3]
                .requiresApproval == true &&
            graph.blockedCapabilityIDs ==
                ["mail.work"]

        return TrainingScenarioResult(
            scenarioID:
                "task-graph-external-commit-approval",
            title:
                "External commit öncesi kullanıcı onayı",
            tier: .core,
            prompt:
                "Oku, analiz et, taslak oluştur; gönderimi onay kapısında durdur.",
            passed: passed,
            goal:
                "Hazırlık step'lerini commit step'inden ayır",
            route: [
                "Core",
                "Mail",
                "Approval"
            ],
            selectedCapabilities:
                graph.steps.map(
                    \.capabilityID
                ),
            unavailableCapabilities:
                graph.blockedCapabilityIDs,
            diagnostics: passed
                ? []
                : [
                    "External commit approval gate yanlış step'e uygulandı."
                ]
        )
    }

    private func compoundCommandBypassesFastPathResult()
        -> TrainingScenarioResult {
        let prompt =
            "Mail uygulamasını aç, son gelen maili incele, ne yapmamız gerektiğini analiz et ve cevap taslağı hazırla."

        let passed =
            !languageResolver
                .isSimpleOpenCommand(
                    prompt
                )

        return TrainingScenarioResult(
            scenarioID:
                "compound-command-bypasses-app-fast-path",
            title:
                "Karmaşık komutu basit app-open'dan ayırma",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Çok adımlı hedefi semantic task graph planner'a bırak",
            route: [
                "Core",
                "Plan"
            ],
            selectedCapabilities: [],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Karmaşık görev yanlışlıkla basit app-open fast path'e düştü."
                ]
        )
    }

    private func compoundMissionNormalizationResult()
        -> TrainingScenarioResult {
        let prompt =
            "Bir uygulamayı aç, şu anda açık olan içeriği bul, bununla ilgili bilgiyi araştır, analiz et ve masaüstündeki proje klasörüne txt dosyası olarak kaydet."

        let staleMission =
            AgentSemanticMission(
                objective: prompt,
                outcomes: [
                    "locate",
                    "organize"
                ],
                steps: [
                    AgentSemanticMissionStep(
                        title:
                            "Eski videoları bul",
                        purpose:
                            "Alakasız önceki görev kalıntısı.",
                        capabilityID:
                            "files.search",
                        operation:
                            "files.search",
                        dependsOn: []
                    ),
                    AgentSemanticMissionStep(
                        title:
                            "Finder'da göster",
                        purpose:
                            "Alakasız eski step.",
                        capabilityID:
                            "files.reveal",
                        operation:
                            "files.reveal",
                        dependsOn: [0]
                    )
                ],
                requiredCapabilityIDs: [
                    "files.search",
                    "files.reveal",
                    "files.move.reversible"
                ],
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 0.4
            )

        let normalized =
            missionNormalizer.normalize(
                staleMission,
                userInput: prompt,
                capabilities:
                    capabilityRegistry.all
            )

        let ids =
            Set(
                normalized
                    .requiredCapabilityIDs
            )

        let operations =
            normalized.steps.map(
                \.operation
            )

        let expectedIDs =
            Set([
                "context.local",
                "core.reasoning",
                "desktop.app",
                "perception.screen",
                "research.web",
                "files.search",
                "files.write.text"
            ])

        let expectedOperations = [
            "context.resolve",
            "app.open",
            "screen.read",
            "web.research",
            "content.analyze",
            "files.search.target-folder",
            "file.write.text"
        ]

        let passed =
            ids == expectedIDs &&
            operations ==
                expectedOperations &&
            !ids.contains(
                "files.move.reversible"
            ) &&
            !ids.contains(
                "files.reveal"
            )

        return TrainingScenarioResult(
            scenarioID:
                "compound-mission-current-goal-normalization",
            title:
                "Karmaşık görevi current goal'den yeniden kurma",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Stale capability/step kalıntılarını atıp gerçek cross-provider zinciri kur",
            route: [
                "Core",
                "Desktop",
                "Screen",
                "Research",
                "Files"
            ],
            selectedCapabilities:
                normalized
                    .requiredCapabilityIDs,
            unavailableCapabilities:
                normalized
                    .requiredCapabilityIDs
                    .filter { id in
                        capabilityRegistry.all
                            .first {
                                $0.id == id
                            }?
                            .isAvailable ==
                            false
                    },
            diagnostics: passed
                ? []
                : [
                    "Current-goal mission normalizer capability veya operation zincirini yanlış kurdu."
                ]
        )
    }

    private func genericAppWorkflowGapResult()
        -> TrainingScenarioResult {
        let prompt =
            "Takvim uygulamasını aç. Yarınki ilk etkinliği bul, başlığını ve saatini bana söyle. Ardından bu etkinlik için 15 dakika öncesine bir hatırlatma eklemeyi hazırla ama benden onay almadan hiçbir değişiklik yapma."

        let snapshot = context(
            hasWorkspace: false
        )

        let decision = brain.analyze(
            prompt,
            context: snapshot
        )

        let goal = goalInterpreter.interpret(
            prompt,
            decision: decision,
            context: snapshot
        )

        let rawMission = AgentSemanticMission(
            objective: prompt,
            outcomes: ["open"],
            steps: [
                AgentSemanticMissionStep(
                    title: "Uygulamayı aç",
                    purpose: "Takvim uygulamasını görünür hale getir.",
                    capabilityID: "desktop.app",
                    operation: "app.open",
                    dependsOn: []
                )
            ],
            requiredCapabilityIDs: [
                "desktop.app"
            ],
            requiresUserInput: false,
            userInputReason: nil,
            confidence: 0.5
        )

        let normalized =
            missionNormalizer.normalize(
                rawMission,
                userInput: prompt,
                capabilities:
                    capabilityRegistry.all
            )

        let graph =
            taskOrchestrator.compile(
                mission: normalized,
                capabilities:
                    capabilityRegistry.all
            )

        let gaps =
            capabilityGapResolver.resolve(
                graph: graph,
                capabilities:
                    capabilityRegistry.all
            )

        let normalizedIDs =
            Set(
                normalized
                    .requiredCapabilityIDs
            )

        let selected =
            Set(
                capabilityRegistry.select(
                    for: prompt,
                    decision: decision,
                    context: snapshot,
                    goal: goal
                )
                .map(\.id)
            )

        let passed =
            selected.contains(
                "app.workflow"
            ) &&
            normalizedIDs.contains(
                "app.workflow"
            ) &&
            normalized.steps.contains {
                $0.capabilityID ==
                    "app.workflow" &&
                $0.operation ==
                    "app.workflow.execute"
            } &&
            !graph.blockedCapabilityIDs
                .contains(
                    "app.workflow"
                ) &&
            !gaps.contains {
                $0.capabilityID ==
                    "app.workflow"
            }

        return TrainingScenarioResult(
            scenarioID:
                "generic-app-workflow-gap",
            title:
                "Bilinmeyen uygulama içi işi generic read-only strategy'ye yönlendirme",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Özel provider bilinmese de açma dışındaki uygulama içi hedefi gerçek observation strategy'sine taşı",
            route: [
                "Core",
                "Desktop",
                "Learn",
                "GapResolver"
            ],
            selectedCapabilities:
                normalized
                    .requiredCapabilityIDs,
            unavailableCapabilities:
                graph
                    .blockedCapabilityIDs,
            diagnostics: passed
                ? []
                : [
                    "Compound uygulama görevi available app.workflow strategy'sine bağlanmadı."
                ]
        )
    }

    private func genericAppWorkflowStrategySafetyResult()
        -> TrainingScenarioResult {
        let preparationPrompt =
            "Yarınki ilk kaydı bul ve değişikliği yalnız hazırla; onay almadan ekleme yapma."
        let directCommitPrompt =
            "Yarınki ilk kayda hatırlatma ekle ve kaydet."

        let preparationBlocked =
            AgentAppWorkflowStrategy.requestsExternalCommit(
                preparationPrompt
            )
        let directCommitBlocked =
            AgentAppWorkflowStrategy.requestsExternalCommit(
                directCommitPrompt
            )

        let passed =
            !preparationBlocked &&
            directCommitBlocked

        return TrainingScenarioResult(
            scenarioID:
                "generic-app-workflow-commit-safety",
            title:
                "Generic app workflow hazırlık ile dış commit'i ayırmalı",
            tier: .core,
            prompt: preparationPrompt,
            passed: passed,
            goal:
                "Salt-okunur observation ve uygulanmamış hazırlık serbest; doğrudan dış değişiklik yasak",
            route: [
                "Desktop",
                "ScreenPerception",
                "AppWorkflow",
                "Verify"
            ],
            selectedCapabilities: [
                "desktop.app",
                "perception.screen",
                "app.workflow"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "app.workflow commit güvenlik ayrımı preparation/direct-commit beklentisini karşılamadı."
                ]
        )
    }

    private func compoundAppTargetExtractionResult()
        -> TrainingScenarioResult {
        let prompt =
            "Takvim uygulamasını aç. Yarınki ilk etkinliği bul, başlığını ve saatini bana söyle."

        let extracted =
            languageResolver
                .applicationTargetPhrase(
                    from: prompt
                )

        let passed =
            extracted ==
                "takvim"

        return TrainingScenarioResult(
            scenarioID:
                "compound-app-target-extraction",
            title:
                "Karmaşık komuttan uygulama hedefini ayırma",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Desktop provider'a tüm görev yerine yalnız hedef uygulama adını gönder",
            route: [
                "Core",
                "Goal",
                "Desktop"
            ],
            selectedCapabilities: [
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Beklenen uygulama hedefi 'takvim', bulunan: " +
                    (extracted ?? "nil")
                ]
        )
    }

    private func secondaryNounAppIsolationResult()
        -> TrainingScenarioResult {
        let prompt =
            "Sistem Ayarları uygulamasını aç. Bluetooth bölümüne git ve bağlı cihazları listele."

        let extracted =
            languageResolver
                .applicationTargetPhrase(
                    from: prompt
                )

        let passed =
            extracted ==
                "sistem ayarlari"

        return TrainingScenarioResult(
            scenarioID:
                "secondary-noun-app-isolation",
            title:
                "İkinci görev nesnesini uygulama adı sanmama",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Açılacak uygulamayı sonraki bölüm/cihaz adlarından ayır",
            route: [
                "Core",
                "Goal",
                "Desktop"
            ],
            selectedCapabilities: [
                "desktop.app",
                "app.workflow"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Beklenen uygulama hedefi 'sistem ayarlari', bulunan: " +
                    (extracted ?? "nil")
                ]
        )
    }

    private func browserWorkflowContractResult()
        -> TrainingScenarioResult {
        let prompt =
            "Safari’yi aç. example.com adresine git ve sayfadaki ana başlığı oku, bana söyle. Ardından yeni bir sekmede wikipedia.org adresini açmayı hazırla ama benden onay almadan yeni sekme açma."

        let snapshot =
            context(
                hasWorkspace: false
            )

        let decision =
            brain.analyze(
                prompt,
                context: snapshot
            )

        let goal =
            goalInterpreter.interpret(
                prompt,
                decision: decision,
                context: snapshot
            )

        let rawMission =
            AgentSemanticMission(
                objective: prompt,
                outcomes:
                    goal.outcomes
                        .map(\.rawValue)
                        .sorted(),
                steps: [],
                requiredCapabilityIDs:
                    Array(
                        goal
                            .requiredCapabilityIDs
                    )
                    .sorted(),
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 0.6
            )

        let normalized =
            missionNormalizer.normalize(
                rawMission,
                userInput: prompt,
                capabilities:
                    capabilityRegistry.all
            )

        let graph =
            taskOrchestrator.compile(
                mission: normalized,
                capabilities:
                    capabilityRegistry.all
            )

        let gaps =
            capabilityGapResolver.resolve(
                graph: graph,
                capabilities:
                    capabilityRegistry.all
            )

        let required =
            Set(
                normalized
                    .requiredCapabilityIDs
            )

        let passed =
            languageResolver
                .requestsBrowserWorkflow(
                    prompt
                ) &&
            languageResolver
                .applicationTargetPhrase(
                    from: prompt
                ) == "safari" &&
            required.contains(
                "desktop.app"
            ) &&
            required.contains(
                "browser.control"
            ) &&
            normalized.steps.contains {
                $0.capabilityID ==
                    "desktop.app"
            } &&
            normalized.steps.contains {
                $0.capabilityID ==
                    "browser.control"
            } &&
            graph.steps.first(
                where: {
                    $0.capabilityID ==
                        "browser.control"
                }
            )?.requiresApproval == false &&
            !normalized.steps.contains {
                $0.capabilityID ==
                    "app.workflow"
            } &&
            graph.blockedCapabilityIDs
                .contains(
                    "browser.control"
                ) &&
            gaps.contains {
                $0.capabilityID ==
                    "browser.control"
            }

        return TrainingScenarioResult(
            scenarioID:
                "browser-workflow-contract",
            title:
                "URL içeren tarayıcı görevini capability gap'e dönüştürme",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal:
                "Planner başarısız olsa bile desktop + browser contract üret ve Learn hattına geçir",
            route: [
                "Core",
                "Goal",
                "Desktop",
                "Browser",
                "Learn"
            ],
            selectedCapabilities:
                normalized
                    .requiredCapabilityIDs,
            unavailableCapabilities:
                graph
                    .blockedCapabilityIDs,
            diagnostics: passed
                ? []
                : [
                    "Safari/URL görevi desktop.app + browser.control contract'ına doğru normalize edilmedi veya salt-okunur gezinme gereksiz approval istedi."
                ]
        )
    }

    private func runtimeProviderFailureEscalationResult()
        -> TrainingScenarioResult {
        let mission =
            AgentSemanticMission(
                objective:
                    "Bir masaüstü uygulamasını aç ve içeriğini incele.",
                outcomes: [
                    "open",
                    "analyze"
                ],
                steps: [
                    AgentSemanticMissionStep(
                        title:
                            "Görev bağlamını hazırla",
                        purpose:
                            "Bağlamı hazırla.",
                        capabilityID:
                            "context.local",
                        operation:
                            "context.resolve",
                        dependsOn: []
                    ),
                    AgentSemanticMissionStep(
                        title:
                            "Uygulamayı aç",
                        purpose:
                            "İstenen uygulamayı görünür foreground'a getir.",
                        capabilityID:
                            "desktop.app",
                        operation:
                            "app.open",
                        dependsOn: [0]
                    ),
                    AgentSemanticMissionStep(
                        title:
                            "İçeriği incele",
                        purpose:
                            "Öndeki uygulamayı incele.",
                        capabilityID:
                            "app.workflow",
                        operation:
                            "app.workflow.execute",
                        dependsOn: [1]
                    )
                ],
                requiredCapabilityIDs: [
                    "context.local",
                    "desktop.app",
                    "app.workflow"
                ],
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 1
            )

        let graph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    capabilityRegistry.all
            )

        let gaps =
            capabilityGapResolver
                .resolveRuntimeFailures(
                    graph: graph,
                    completedStepIndexes: [0],
                    capabilities:
                        capabilityRegistry.all
                )

        let passed =
            gaps.count == 1 &&
            gaps.first?
                .capabilityID ==
                "desktop.app" &&
            gaps.first?
                .kind ==
                .strategy &&
            gaps.first?
                .developerBrief
                .contains(
                    "hard-code yazma"
                ) == true

        return TrainingScenarioResult(
            scenarioID:
                "runtime-provider-failure-escalation",
            title:
                "Available provider runtime hatasını Learn hattına eskale etme",
            tier: .core,
            prompt:
                mission.objective,
            passed: passed,
            goal:
                "Debug/retry sonrası tamamlanmayan root provider'ı generic runtime gap say",
            route: [
                "Core",
                "Debug",
                "GapResolver",
                "Learn"
            ],
            selectedCapabilities:
                gaps.map(
                    \.capabilityID
                ),
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Runtime'da başarısız desktop.app provider'ı tek root gap olarak üretilmedi."
                ]
        )
    }

    private func learningQueueDeduplicationResult()
        -> TrainingScenarioResult {
        let store =
            AgentLearningQueueStore()

        let desktopGap =
            CapabilityGapResolution(
                capabilityID:
                    "desktop.app",
                capabilityName:
                    "Uygulama kontrolü",
                kind: .strategy,
                reason:
                    "Provider available olmasına rağmen runtime step tamamlanamadı veya postcondition doğrulanamadı: desktop.app • app.open",
                candidateCapabilityIDs: [],
                researchGoal:
                    "Generic desktop resolver/provider hatasını araştır.",
                developerBrief:
                    "Tek uygulamaya hard-code yazmadan desktop.app provider'ını düzelt."
            )

        let browserGap =
            CapabilityGapResolution(
                capabilityID:
                    "browser.control",
                capabilityName:
                    "Tarayıcı kontrolü",
                kind: .integration,
                reason:
                    "Task Graph step 'Web hedefini tarayıcıda yürüt' için browser.control gerekiyor ancak provider available değil.",
                candidateCapabilityIDs: [],
                researchGoal:
                    "Generic browser provider araştır.",
                developerBrief:
                    "Generic browser.control provider geliştir."
            )

        var jobs =
            store.enqueue(
                gaps: [desktopGap],
                sourceGoal:
                    "Notlar uygulamasını aç.",
                into: [],
                persist: false
            )

        jobs =
            store.enqueue(
                gaps: [desktopGap],
                sourceGoal:
                    "Hesap Makinesi uygulamasını aç.",
                into: jobs,
                persist: false
            )

        jobs =
            store.enqueue(
                gaps: [browserGap],
                sourceGoal:
                    "Safari ile example.com adresine git.",
                into: jobs,
                persist: false
            )

        let desktopJobs =
            jobs.filter {
                $0.capabilityID ==
                    "desktop.app"
            }

        let next =
            store.nextQueued(
                from: jobs
            )

        let passed =
            jobs.count == 2 &&
            desktopJobs.count == 1 &&
            desktopJobs.first?
                .evidenceCount == 2 &&
            desktopJobs.first?
                .sourceGoals.count == 2 &&
            next?.capabilityID ==
                "desktop.app"

        return TrainingScenarioResult(
            scenarioID:
                "learning-queue-deduplication",
            title:
                "Aynı kök öğrenme hatasını birleştir, farklı capability'yi sıraya al",
            tier: .core,
            prompt:
                "Arka arkaya bağımsız görevlerden aynı desktop.app hatası ve ayrı browser.control gap'i üret.",
            passed: passed,
            goal:
                "Tek writer worker için fingerprint/dedupe kuyruğu oluştur",
            route: [
                "Debug",
                "LearningQueue",
                "DeveloperAgent"
            ],
            selectedCapabilities:
                jobs.map(
                    \.capabilityID
                ),
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Learning Queue aynı desktop.app kök hatasını birleştirmedi veya farklı browser gap'ini ayrı iş olarak korumadı."
                ]
        )
    }

    private func nonCommitWorkflowApprovalResult()
        -> TrainingScenarioResult {
        let mission =
            AgentSemanticMission(
                objective:
                    "Takvimde hatırlatmayı hazırla ama onay almadan hiçbir değişiklik yapma.",
                outcomes: [
                    "analyze"
                ],
                steps: [
                    AgentSemanticMissionStep(
                        title:
                            "Uygulama içi hedefi yürüt",
                        purpose:
                            "Hatırlatmayı yalnız hazırlık düzeyinde hazırla; kullanıcı onayı almadan dış dünyaya commit etmeden bekle.",
                        capabilityID:
                            "app.workflow",
                        operation:
                            "app.workflow.execute",
                        dependsOn: []
                    )
                ],
                requiredCapabilityIDs: [
                    "app.workflow"
                ],
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 1
            )

        let graph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    capabilityRegistry.all
            )

        let step =
            graph.steps.first

        let passed =
            step?.requiresApproval ==
                false &&
            step?.role == .act

        return TrainingScenarioResult(
            scenarioID:
                "non-commit-workflow-approval",
            title:
                "Hazırlık görevini dış dünya commit'i gibi onaya sokmama",
            tier: .core,
            prompt:
                mission.objective,
            passed: passed,
            goal:
                "Sadece gerçek commit eylemlerinde approval gate aç",
            route: [
                "Core",
                "Plan",
                "Approval"
            ],
            selectedCapabilities: [
                "app.workflow"
            ],
            unavailableCapabilities: [
                "app.workflow"
            ],
            diagnostics: passed
                ? []
                : [
                    "app.workflow hazırlık step'i yanlışlıkla approval bekliyor veya verify rolüne düştü."
                ]
        )
    }

    private func capabilityGapClassificationResult()
        -> TrainingScenarioResult {
        let mission =
            AgentSemanticMission(
                objective:
                    "Bir iletiyi oku ve cevap taslağı hazırla.",
                outcomes: [
                    "communicate"
                ],
                steps: [
                    AgentSemanticMissionStep(
                        title: "İletiyi oku",
                        purpose:
                            "İletiyi salt-okunur al.",
                        capabilityID:
                            "mail.work",
                        operation:
                            "mail.read",
                        dependsOn: []
                    )
                ],
                requiredCapabilityIDs: [
                    "mail.work"
                ],
                requiresUserInput: false,
                userInputReason: nil,
                confidence: 1
            )

        let graph =
            taskOrchestrator.compile(
                mission: mission,
                capabilities:
                    capabilityRegistry.all
            )

        let gaps =
            capabilityGapResolver.resolve(
                graph: graph,
                capabilities:
                    capabilityRegistry.all
            )

        let passed =
            gaps.count == 1 &&
            gaps.first?.capabilityID ==
                "mail.work" &&
            gaps.first?.kind ==
                .integration &&
            gaps.first?
                .developerBrief
                .contains(
                    "candidate branch"
                ) == true

        return TrainingScenarioResult(
            scenarioID:
                "capability-gap-classification",
            title:
                "Eksik provider'ı strategy/code/integration olarak sınıflandırma",
            tier: .core,
            prompt:
                "Unavailable provider için güvenli developer brief üret.",
            passed: passed,
            goal:
                "Capability gap'i self-evolution hattına hazırla",
            route: [
                "Core",
                "GapResolver"
            ],
            selectedCapabilities:
                gaps.map(
                    \.capabilityID
                ),
            unavailableCapabilities:
                gaps.map(
                    \.capabilityID
                ),
            diagnostics: passed
                ? []
                : [
                    "Capability Gap Resolver beklenen integration/developer brief sonucunu üretmedi."
                ]
        )
    }

    private func semanticExecutionVerifierResult()
        -> TrainingScenarioResult {
        let prompt = "Notlar uygulamasını aç."

        let decision = brain.analyze(
            prompt,
            context: context(
                hasWorkspace: true,
                videoCount: 0
            )
        )

        let goal = goalInterpreter.interpret(
            prompt,
            decision: decision,
            context: context(
                hasWorkspace: true,
                videoCount: 0
            )
        )

        let mission = AgentSemanticMission(
            objective: prompt,
            outcomes: ["open"],
            steps: [
                AgentSemanticMissionStep(
                    title: "Hedefi çöz",
                    purpose: "Kullanıcı hedefini çöz.",
                    capabilityID: "core.reasoning",
                    operation: "semantic.test",
                    dependsOn: []
                ),
                AgentSemanticMissionStep(
                    title: "Uygulamayı aç",
                    purpose: "İstenen uygulamayı aç.",
                    capabilityID: "desktop.app",
                    operation: "app.open",
                    dependsOn: [0]
                )
            ],
            requiredCapabilityIDs: [
                "core.reasoning",
                "context.local",
                "desktop.app"
            ],
            requiresUserInput: false,
            userInputReason: nil,
            confidence: 1
        )

        let result = verifier.verify(
            decision: decision,
            currentUserInput: prompt,
            goal: goal,
            semanticMission: mission,
            snapshot: AgentVerificationSnapshot(
                hasWorkspace: true,
                fileResultCount: 0,
                folderResultCount: 0,
                hasPendingAction: false,
                hasUndoAction: false,
                unavailableCapabilityIDs: [],
                selectedCapabilityIDs: [
                    "core.reasoning",
                    "context.local",
                    "desktop.app"
                ],
                executedCapabilityIDs: [
                    "core.reasoning",
                    "context.local"
                ],
                incompleteRequiredActionCapabilityIDs: [
                    "desktop.app"
                ],
                webResearchResultCount: 0,
                webResearchEvidenceCount: 0,
                webResearchUniqueDomainCount: 0,
                webResearchCanonicalEvidenceCount: 0,
                fileSearchOutcome: nil
            )
        )

        let passed =
            result.state == .attention &&
            result.summary.contains(
                "desktop.app"
            ) &&
            (
                result.summary.contains(
                    "tamamlanmadı"
                ) ||
                result.summary.contains(
                    "gerçekten yürütülmedi"
                )
            )

        return TrainingScenarioResult(
            scenarioID:
                "semantic-required-action-execution",
            title:
                "Verifier yürütülmeyen semantic action'ı başarılı saymamalı",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal: goal.summary,
            route: [],
            selectedCapabilities: [
                "core.reasoning",
                "context.local",
                "desktop.app"
            ],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "desktop.app yürütülmeden verifier passed/partial verdi."
                ]
        )
    }

    private func staleGoalVerifierIsolationResult()
        -> TrainingScenarioResult {
        let prompt =
            "Bu yaptığımız çalışma biçimini ileride benzer sosyal medya video işleri için de kullan. Ama Estafiz'e özel marka detaylarını başka markalara otomatik uygulama."

        let staleDecision = AgentDecision(
            intent: .fileSearch,
            target: .video,
            dateRange: nil,
            dateField: .either,
            sortMode: .relevance,
            route: ["Core", "Context", "File Search"],
            goal: "videoları bul",
            selectedPlan: "Seçili çalışma alanını salt-okunur tara",
            alternatives: [],
            proactiveSuggestion: nil,
            usePreviousResults: false,
            resultSelection: nil
        )

        let staleGoal = goalInterpreter.interpret(
            "videoları bul",
            decision: staleDecision,
            context: context(
                hasWorkspace: true,
                videoCount: 20
            )
        )

        let result = verifier.verify(
            decision: staleDecision,
            currentUserInput: prompt,
            goal: staleGoal,
            snapshot: AgentVerificationSnapshot(
                hasWorkspace: true,
                fileResultCount: 12,
                folderResultCount: 0,
                hasPendingAction: false,
                hasUndoAction: false,
                unavailableCapabilityIDs: [],
                selectedCapabilityIDs: [
                    "files.search",
                    "files.metadata"
                ],
                executedCapabilityIDs: [
                    "files.search",
                    "files.metadata"
                ],
                incompleteRequiredActionCapabilityIDs: [],
                webResearchResultCount: 0,
                webResearchEvidenceCount: 0,
                webResearchUniqueDomainCount: 0,
                webResearchCanonicalEvidenceCount: 0,
                fileSearchOutcome: nil
            )
        )

        let passed =
            result.state == .attention &&
            result.summary.contains("mevcut kullanıcı girdisiyle uyuşmuyor")

        return TrainingScenarioResult(
            scenarioID: "stale-goal-verifier-isolation",
            title: "Verifier eski dosya hedefini reddetmeli",
            tier: .core,
            prompt: prompt,
            passed: passed,
            goal: "Yeni kullanıcı girdisini stale fileSearch goal'ünden ayır",
            route: ["Core", "Goal", "Verify"],
            selectedCapabilities: ["core.reasoning"],
            unavailableCapabilities: [],
            diagnostics: passed
                ? []
                : [
                    "Verifier stale fileSearch hedefini mevcut memory komutundan ayıramadı."
                ]
        )
    }

    private func evaluate(
        _ scenario: TrainingScenario,
        goal: AgentGoalProfile,
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        plan: AgentExecutionPlan,
        route: [String]
    ) -> TrainingScenarioResult {
        var diagnostics: [String] = []

        let missingOutcomes = scenario.requiredOutcomes
            .subtracting(goal.outcomes)

        if !missingOutcomes.isEmpty {
            diagnostics.append(
                "Eksik hedef sonuçları: " +
                missingOutcomes
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        let selectedIDs = Set(
            capabilities.map(\.id)
        )

        let missingCapabilities =
            scenario.requiredCapabilities.subtracting(selectedIDs)

        if !missingCapabilities.isEmpty {
            diagnostics.append(
                "Seçilmemiş capability: " +
                missingCapabilities
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        let forbiddenSelected =
            scenario.forbiddenCapabilities.intersection(selectedIDs)

        if !forbiddenSelected.isEmpty {
            diagnostics.append(
                "Yanlış capability seçimi: " +
                forbiddenSelected
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        let missingRoute = scenario.requiredRouteStages
            .subtracting(Set(route))

        if !missingRoute.isEmpty {
            diagnostics.append(
                "Eksik rota aşaması: " +
                missingRoute
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        for requiredTitle in scenario.requiredStepTitles {
            let found = plan.steps.contains {
                normalize($0.title).contains(
                    normalize(requiredTitle)
                )
            }

            if !found {
                diagnostics.append(
                    "Plan adımı eksik: " + requiredTitle
                )
            }
        }

        let learningIDs = Set(
            learningPlans.map(\.capabilityID)
        )

        let missingLearning = scenario.requiredLearningCapabilities
            .subtracting(learningIDs)

        if !missingLearning.isEmpty {
            diagnostics.append(
                "Eksik öğrenme planı: " +
                missingLearning
                    .sorted()
                    .joined(separator: ", ")
            )
        }

        if scenario.minimumResearchConceptGroups > 0 {
            let queryPlan = researchQueryPlanner.plan(
                scenario.prompt
            )

            if queryPlan.conceptGroups.count <
                scenario.minimumResearchConceptGroups {
                diagnostics.append(
                    "Research concept coverage düşük: " +
                    String(queryPlan.conceptGroups.count)
                )
            }

            if queryPlan.mandatoryConceptGroups.count <
                scenario.minimumMandatoryResearchConceptGroups {
                diagnostics.append(
                    "Zorunlu research kavramı düşük: " +
                    String(queryPlan.mandatoryConceptGroups.count)
                )
            }

            if queryPlan.directCandidates.count <
                scenario.minimumDirectResearchCandidates {
                diagnostics.append(
                    "Doğrudan kaynak çözümleme adayı eksik: " +
                    String(queryPlan.directCandidates.count)
                )
            }
        }

        let unavailable = capabilities
            .filter { !$0.isAvailable }
            .map(\.id)
            .sorted()

        return TrainingScenarioResult(
            scenarioID: scenario.id,
            title: scenario.title,
            tier: scenario.tier,
            prompt: scenario.prompt,
            passed: diagnostics.isEmpty,
            goal: goal.summary,
            route: route,
            selectedCapabilities: selectedIDs.sorted(),
            unavailableCapabilities: unavailable,
            diagnostics: diagnostics
        )
    }

    private func makeScenarios() -> [TrainingScenario] {
        let empty = context()
        let workspace = context(
            hasWorkspace: true,
            fileCount: 140,
            imageCount: 40,
            videoCount: 28,
            projectCount: 8,
            documentCount: 32,
            screenshotCount: 18
        )
        let previous = context(
            hasWorkspace: true,
            fileCount: 80,
            imageCount: 12,
            videoCount: 20,
            previousFileResultCount: 5,
            lastTarget: .video,
            lastGoal: "Son videoları bul"
        )
        let rememberedResearch = context(
            relevantMemoryCount: 1,
            lastMemoryGoal:
                "güncel kaynaklarla araştır → sonucu ve gerekçeyi açıkla"
        )
        let staleComparisonMemory = context(
            relevantMemoryCount: 1,
            lastMemoryGoal:
                "bulguları analiz et → sonucu ve gerekçeyi açıkla"
        )
        let staleFileResultsWithMemory = context(
            hasWorkspace: true,
            fileCount: 80,
            videoCount: 20,
            previousFileResultCount: 5,
            lastTarget: .video,
            lastGoal: "Son videoları bul",
            relevantMemoryCount: 2,
            lastMemoryGoal: "çalışma kuralını öğren"
        )

        return [
            TrainingScenario(
                id: "research-technical",
                title: "Teknik araştırma güvenilirliği",
                tier: .core,
                prompt: "macOS üzerinde video içeriğini analiz edebilmek için hangi teknolojileri kullanabileceğini web'de araştır",
                context: empty,
                requiredOutcomes: [.research],
                requiredCapabilities: ["research.web"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Web'de araştır", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 3,
                minimumMandatoryResearchConceptGroups: 2
            ),
            TrainingScenario(
                id: "brand-research-ideas",
                title: "Marka araştırması + bağımsız fikir",
                tier: .core,
                prompt: "HABAŞ hakkında web'de detaylı araştır; tarihçesini, ürünlerini, rakiplerini ve fırsatlarını analiz et, nedenleriyle açıkla ve benim söylediklerim dışında kendi fikirlerini de ekle",
                context: empty,
                requiredOutcomes: [.research, .analyze, .explain, .ideate],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Analiz et", "Bağımsız fikir üret", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 2,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "brand-content-strategy",
                title: "Markadan içerik stratejisi çıkarma",
                tier: .core,
                prompt: "Vox Coffee Co hakkında internetten araştır, güçlü ve zayıf yönlerini analiz et ve markaya özel 5 özgün içerik fikri üret",
                context: empty,
                requiredOutcomes: [.research, .analyze, .ideate],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research"],
                requiredStepTitles: ["Analiz et", "Bağımsız fikir üret"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 1,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "generic-analysis",
                title: "Genel analiz ve çıkarım",
                tier: .core,
                prompt: "Bu verileri analiz et, önemli çıkarımları nedenleriyle açıkla ve benim söylemediğim olası fırsatları da ekle",
                context: empty,
                requiredOutcomes: [.analyze, .explain, .ideate],
                requiredCapabilities: ["core.reasoning"],
                forbiddenCapabilities: ["files.search", "research.web"],
                requiredRouteStages: ["Core", "Goal"],
                requiredStepTitles: ["Analiz et", "Bağımsız fikir üret"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "local-business-detailed-research",
                title: "Doğal dilde detaylı yerel işletme araştırması",
                tier: .core,
                prompt: "Estafiz adında bir pilates salonu var onu detaylı araştırır mısın?",
                context: empty,
                requiredOutcomes: [.research, .explain],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Web'de araştır", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 2,
                minimumMandatoryResearchConceptGroups: 1
            ),
            TrainingScenario(
                id: "social-profile-public-metadata",
                title: "Sosyal medya profil bilgisi araştırması",
                tier: .core,
                prompt: "estafizsym instagram hesabının kaç takipçisi var içerikleri neler bakabilir misin",
                context: empty,
                requiredOutcomes: [.research, .explain],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Web'de araştır", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 2,
                minimumMandatoryResearchConceptGroups: 1,
                minimumDirectResearchCandidates: 1
            ),
            TrainingScenario(
                id: "context-memory-followup",
                title: "Önceki araştırmadan devam etme",
                tier: .core,
                prompt: "bu hesap için az önce söylediklerinden 3 reels fikri çıkar",
                context: rememberedResearch,
                requiredOutcomes: [.ideate],
                requiredCapabilities: ["core.reasoning", "context.local"],
                forbiddenCapabilities: ["research.web", "files.search"],
                requiredRouteStages: ["Context"],
                requiredStepTitles: ["Bağımsız fikir üret"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "context-memory-transform",
                title: "Önceki fikri yeni formata dönüştürme",
                tier: .core,
                prompt: "şimdi Estafiz'e dön, az önceki Reels fikirlerinden birincisini 30 saniyelik çekim senaryosuna çevir",
                context: rememberedResearch,
                requiredOutcomes: [.transform],
                requiredCapabilities: ["core.reasoning", "context.local"],
                forbiddenCapabilities: ["research.web", "files.search"],
                requiredRouteStages: ["Context"],
                requiredStepTitles: ["İstenen formata dönüştür"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "knowledge-comparison-not-file-search",
                title: "Bilgi karşılaştırmasını yerel dosya aramasından ayırma",
                tier: .core,
                prompt: "Sony A7 IV ile Fuji X-T5 arasında video açısından temel farklar neler?",
                context: empty,
                requiredOutcomes: [.research, .analyze, .explain],
                requiredCapabilities: ["core.reasoning", "research.web"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Analiz et", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 1,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "knowledge-comparison-with-stale-memory",
                title: "Eski hafıza güncel karşılaştırmayı bastırmamalı",
                tier: .core,
                prompt: "Sony A7 IV ile Fuji X-T5 arasında video açısından temel farklar neler?",
                context: staleComparisonMemory,
                requiredOutcomes: [.research, .analyze, .explain],
                requiredCapabilities: ["core.reasoning", "research.web"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Analiz et", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 1,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "content-plan-not-file-search",
                title: "İçerik planını dosya aramasından ayırma",
                tier: .core,
                prompt: "Estafiz için 30 saniyelik bir Reels çekim planı hazırla. 3 bölüm olsun: açılış, ana mesaj ve kapanış. Her bölüm için süre aralığını yaz. Önemli cümleleri kalın göster, maddeler kullan ve kısa bir Neden işe yarar bölümü ekle.",
                context: rememberedResearch,
                requiredOutcomes: [.compose],
                requiredCapabilities: ["core.reasoning", "context.local"],
                forbiddenCapabilities: ["research.web", "files.search"],
                requiredRouteStages: ["Context"],
                requiredStepTitles: ["İçeriği oluştur"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "brand-reels-plan-with-stale-file-state",
                title: "Marka Reels planını eski dosya aramasından ayırma",
                tier: .core,
                prompt: "Şimdi Vox Coffee Co. için 30 saniyelik bir Reels planı hazırla. Estafiz'den öğrendiğin marka detaylarını kullanma; yalnızca genel çalışma yöntemini kullan.",
                context: staleFileResultsWithMemory,
                requiredOutcomes: [.compose],
                requiredCapabilities: ["core.reasoning", "context.local"],
                forbiddenCapabilities: ["files.search", "files.metadata", "research.web"],
                requiredRouteStages: ["Context"],
                requiredStepTitles: ["İçeriği oluştur"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "inline-turkish-rewrite",
                title: "Verilen metni doğrudan yeniden yazma",
                tier: .core,
                prompt: "şu metni düzgün Türkçeyle yeniden yaz: “şuan birşey yapmıyorum ama yada yarın devam ederiz, herkez gelirse kapanışda konuşuruz”",
                context: rememberedResearch,
                requiredOutcomes: [.transform],
                requiredCapabilities: ["core.reasoning", "context.local"],
                forbiddenCapabilities: ["research.web", "files.search"],
                requiredRouteStages: ["Context"],
                requiredStepTitles: ["İstenen formata dönüştür"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "local-file-search",
                title: "Yerel dosya araması",
                tier: .core,
                prompt: "son eklenen videoları bul",
                context: workspace,
                requiredOutcomes: [.locate],
                requiredCapabilities: ["files.search", "files.metadata"],
                forbiddenCapabilities: ["research.web"],
                requiredRouteStages: ["Files", "Verify"],
                requiredStepTitles: ["Kapsamı tara"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "media-suitability",
                title: "İçerik uygunluğu analizi",
                tier: .core,
                prompt: "son videoları bul, en uygun olanları seç ve hangilerinin kurgu için daha iyi olduğunu nedenleriyle açıkla",
                context: workspace,
                requiredOutcomes: [.locate, .shortlist, .assessContent, .explain],
                requiredCapabilities: ["files.search", "perception.media"],
                forbiddenCapabilities: [],
                requiredRouteStages: ["Files", "Perception", "Learn", "Verify"],
                requiredStepTitles: ["İçeriği analiz et", "Yetkinlik edinme planı oluştur"],
                requiredLearningCapabilities: ["perception.media"],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "screenshot-organize",
                title: "Güvenli dosya düzenleme",
                tier: .core,
                prompt: "ekran görüntülerini toparla",
                context: workspace,
                requiredOutcomes: [.locate, .organize],
                requiredCapabilities: ["files.search", "files.move.reversible"],
                forbiddenCapabilities: ["research.web"],
                requiredRouteStages: ["Files", "Verify"],
                requiredStepTitles: ["Taşıma planı hazırla", "Onay bekle"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "scoped-workflow-rule-after-file-search",
                title: "Eski dosya araması sonrası kapsamlı çalışma kuralı",
                tier: .core,
                prompt: "Bu yaptığımız çalışma biçimini ileride benzer sosyal medya video işleri için de kullan. Ama Estafiz'e özel marka detaylarını başka markalara otomatik uygulama.",
                context: previous,
                requiredOutcomes: [.remember],
                requiredCapabilities: ["memory.local"],
                forbiddenCapabilities: ["files.search", "files.metadata"],
                requiredRouteStages: ["Memory"],
                requiredStepTitles: ["Yerel hafızaya kaydet"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "remember-rule",
                title: "Çalışma kuralını öğrenme",
                tier: .core,
                prompt: "bundan sonra konuşmalı Reels videolarında 35 saniyeyi geçme, bunu aklında tut",
                context: empty,
                requiredOutcomes: [.remember],
                requiredCapabilities: ["memory.local"],
                forbiddenCapabilities: ["research.web"],
                requiredRouteStages: ["Memory"],
                requiredStepTitles: ["Yerel hafızaya kaydet"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "conversation",
                title: "Doğal konuşma",
                tier: .core,
                prompt: "nasılsın, bugün ne yapıyorsun?",
                context: workspace,
                requiredOutcomes: [.converse],
                requiredCapabilities: ["core.reasoning"],
                forbiddenCapabilities: ["research.web", "files.search"],
                requiredRouteStages: ["Core", "Response"],
                requiredStepTitles: ["Yanıt oluştur"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "previous-result-open",
                title: "Konuşma bağlamından sonuç açma",
                tier: .core,
                prompt: "bunlardan sonuncusunu Finder'da aç",
                context: previous,
                requiredOutcomes: [.open],
                requiredCapabilities: ["files.reveal"],
                forbiddenCapabilities: ["research.web"],
                requiredRouteStages: ["Files", "Verify"],
                requiredStepTitles: ["Referansı çöz", "Finder'da göster"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "premiere-gap",
                title: "Eksik uygulama yeteneğini fark etme",
                tier: .core,
                prompt: "Premiere'de aktif sequence içindeki boşlukları temizle ve sonucu kontrol et",
                context: empty,
                requiredOutcomes: [.edit],
                requiredCapabilities: ["premiere.control"],
                forbiddenCapabilities: [],
                requiredRouteStages: ["Premiere", "Learn", "Verify"],
                requiredStepTitles: ["Yetkinlik edinme planı oluştur"],
                requiredLearningCapabilities: ["premiere.control"],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "mail-gap",
                title: "Mail capability gap",
                tier: .core,
                prompt: "günlük iş özetimi mail taslağına çevir ve göndermeden önce bana göster",
                context: empty,
                requiredOutcomes: [.communicate],
                requiredCapabilities: ["mail.work"],
                forbiddenCapabilities: [],
                requiredRouteStages: ["Mail", "Learn", "Verify"],
                requiredStepTitles: ["Yetkinlik edinme planı oluştur"],
                requiredLearningCapabilities: ["mail.work"],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "open-world-brand",
                title: "Yeni marka alanında açık dünya araştırması",
                tier: .northStar,
                prompt: "Daha önce hiç konuşmadığımız bir markayı araştır, pazardaki konumunu analiz et, çelişkili bilgileri ayır ve bana üç özgün büyüme fikri üret",
                context: empty,
                requiredOutcomes: [.research, .analyze, .ideate],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Analiz et", "Bağımsız fikir üret", "Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 1,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "attached-media-analysis",
                title: "Doğrudan görsel/video analiz isteği",
                tier: .northStar,
                prompt: "bu videoyu analiz et; kadraj, netlik, hareket, anlatı ve kurgu potansiyeli hakkında içerikten yorum yap",
                context: empty,
                requiredOutcomes: [.assessContent, .analyze, .explain],
                requiredCapabilities: ["perception.media"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Perception", "Learn", "Verify"],
                requiredStepTitles: ["Yetkinlik edinme planı oluştur"],
                requiredLearningCapabilities: ["perception.media"],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "browser-open-world",
                title: "Tarayıcıda yeni görev",
                tier: .northStar,
                prompt: "markanın resmi sitesine gir, ürün sayfalarını incele ve rakiplerine göre eksik gördüğün alanları raporla",
                context: empty,
                requiredOutcomes: [.analyze, .explain],
                requiredCapabilities: ["browser.control"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Browser", "Learn", "Verify"],
                requiredStepTitles: ["Yetkinlik edinme planı oluştur"],
                requiredLearningCapabilities: ["browser.control"],
                minimumResearchConceptGroups: 0,
                minimumMandatoryResearchConceptGroups: 0
            ),
            TrainingScenario(
                id: "self-learning",
                title: "Yeteneği yoksa öğrenme döngüsü",
                tier: .northStar,
                prompt: "Bunu şu an yapamıyorsan hangi yeteneğin eksik olduğunu bul, resmi kaynaklardan nasıl yapıldığını araştır ve kendine güvenli bir öğrenme planı çıkar",
                context: empty,
                requiredOutcomes: [.research, .analyze, .explain],
                requiredCapabilities: ["research.web", "core.reasoning"],
                forbiddenCapabilities: ["files.search"],
                requiredRouteStages: ["Research", "Verify"],
                requiredStepTitles: ["Kaynakları oku"],
                requiredLearningCapabilities: [],
                minimumResearchConceptGroups: 1,
                minimumMandatoryResearchConceptGroups: 0
            )
        ]
    }

    private func context(
        hasWorkspace: Bool = false,
        fileCount: Int = 0,
        imageCount: Int = 0,
        videoCount: Int = 0,
        projectCount: Int = 0,
        documentCount: Int = 0,
        screenshotCount: Int = 0,
        previousFileResultCount: Int = 0,
        previousFolderResultCount: Int = 0,
        lastTarget: AgentTargetKind? = nil,
        lastGoal: String? = nil,
        relevantMemoryCount: Int = 0,
        lastMemoryGoal: String? = nil
    ) -> AgentContextSnapshot {
        AgentContextSnapshot(
            hasWorkspace: hasWorkspace,
            workspaceName: hasWorkspace
                ? "Training Workspace"
                : nil,
            fileCount: fileCount,
            imageCount: imageCount,
            videoCount: videoCount,
            projectCount: projectCount,
            documentCount: documentCount,
            screenshotCount: screenshotCount,
            hasPendingAction: false,
            previousFileResultCount: previousFileResultCount,
            previousFolderResultCount: previousFolderResultCount,
            lastTarget: lastTarget,
            lastGoal: lastGoal,
            relevantMemoryCount: relevantMemoryCount,
            lastMemoryGoal: lastMemoryGoal
        )
    }

    private func normalize(
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
    }
}

struct TrainingLabStore {
    private let fileManager = FileManager.default

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/training-latest.json",
                isDirectory: false
            )
    }

    func save(_ report: TrainingLabReport) throws {
        let directory = outputURL
            .deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        try data.write(
            to: outputURL,
            options: .atomic
        )
    }

    func load() -> TrainingLabReport? {
        guard
            let data = try? Data(
                contentsOf: outputURL
            )
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(
            TrainingLabReport.self,
            from: data
        )
    }
}


struct AgentArenaScenarioResult: Identifiable, Codable, Hashable {
    var id: String { scenarioID }

    let scenarioID: String
    let title: String
    let prompt: String
    let passed: Bool
    let plannerProvider: String
    let mission: AgentSemanticMission?
    let selectedCapabilityIDs: [String]
    let diagnostics: [String]
    let reviewerPassed: Bool?
    let reviewerSummary: String?
    let reviewerMissingCapabilityIDs: [String]
    let reviewerUnnecessaryCapabilityIDs: [String]
    let reviewerRiskNotes: [String]
}

struct AgentArenaReport: Codable, Hashable {
    let createdAt: Date
    let appVersion: String
    let total: Int
    let passed: Int
    let failed: Int
    let reviewerFlagged: Int
    let results: [AgentArenaScenarioResult]
}

private struct AgentArenaScenario {
    let id: String
    let title: String
    let prompt: String
    let requiredCapabilities: Set<String>
    let forbiddenCapabilities: Set<String>
    let requiredOutcomes: Set<String>
    let shouldNotRequireUserInput: Bool
}

actor AgentArena {
    private let localIntelligence = AgentLocalIntelligence()
    private let subscriptionIntelligence =
        AgentSubscriptionIntelligence()
    private let capabilityRegistry = AgentCapabilityRegistry()
    private let memoryStore = AgentContextMemoryStore()
    private let arenaStore = AgentArenaStore()

    func run() async -> AgentArenaReport {
        let scenarios = makeScenarios()
        let allCapabilities = capabilityRegistry.all
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        let memories = memoryStore.load()
        var results: [AgentArenaScenarioResult] = []
        var subscriptionFallbackBudget = 2

        for (index, scenario) in scenarios.enumerated() {
            arenaStore.saveProgress(
                "v\(appVersion) • \(index + 1)/\(scenarios.count) • \(scenario.title) • Apple Planner"
            )

            let relevantMemory = memoryStore.relevant(
                to: scenario.prompt,
                from: memories,
                limit: 4
            )

            var selectedMission: AgentSemanticMission?
            var provider = "none"
            var diagnostics: [String] = []

            if let localMission =
                await localIntelligence.planMission(
                    userInput: scenario.prompt,
                    contextMemory: relevantMemory,
                    capabilities: allCapabilities,
                    hasWorkspace: true
                ) {
                let localDiagnostics = evaluate(
                    scenario,
                    mission: localMission
                )

                selectedMission = localMission
                provider =
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
                diagnostics = localDiagnostics
            }

            if (selectedMission == nil ||
                !diagnostics.isEmpty) &&
               subscriptionFallbackBudget > 0 {
                subscriptionFallbackBudget -= 1
                arenaStore.saveProgress(
                    "\(index + 1)/\(scenarios.count) • \(scenario.title) • ChatGPT fallback"
                )

                if let fallback =
                    await subscriptionIntelligence.planMission(
                        userInput: scenario.prompt,
                        contextMemory: relevantMemory,
                        capabilities: allCapabilities,
                        hasWorkspace: true
                    ) {
                    let fallbackDiagnostics = evaluate(
                        scenario,
                        mission: fallback.mission
                    )

                    if selectedMission == nil ||
                       fallbackDiagnostics.count <
                        diagnostics.count {
                        selectedMission = fallback.mission
                        provider = fallback.provider
                        diagnostics = fallbackDiagnostics
                    }
                }
            }

            if selectedMission == nil {
                diagnostics = [
                    "Hiçbir semantic planner geçerli mission üretemedi."
                ]
            }

            arenaStore.saveProgress(
                "v\(appVersion) • \(index + 1)/\(scenarios.count) • \(scenario.title) • Reviewer"
            )

            let review: AgentMissionReview?
            if let selectedMission {
                review = await localIntelligence.reviewMission(
                    userInput: scenario.prompt,
                    mission: selectedMission,
                    capabilities: allCapabilities
                )
            } else {
                review = nil
            }

            let selectedIDs = selectedMission.map {
                Array(
                    Set(
                        $0.requiredCapabilityIDs +
                        $0.steps.map(\.capabilityID)
                    )
                )
                .sorted()
            } ?? []

            let selectedSet = Set(selectedIDs)

            let groundedReviewerMissing =
                (review?.missingCapabilityIDs ?? [])
                    .filter {
                        !selectedSet.contains($0) &&
                        scenario.requiredCapabilities
                            .contains($0)
                    }

            let groundedReviewerUnnecessary =
                (review?.unnecessaryCapabilityIDs ?? [])
                    .filter {
                        selectedSet.contains($0) &&
                        scenario.forbiddenCapabilities
                            .contains($0)
                    }

            let groundedReviewerPassed: Bool?
            if review == nil {
                groundedReviewerPassed = nil
            } else {
                groundedReviewerPassed =
                    groundedReviewerMissing.isEmpty &&
                    groundedReviewerUnnecessary.isEmpty
            }

            results.append(
                AgentArenaScenarioResult(
                    scenarioID: scenario.id,
                    title: scenario.title,
                    prompt: scenario.prompt,
                    passed: diagnostics.isEmpty,
                    plannerProvider: provider,
                    mission: selectedMission,
                    selectedCapabilityIDs: selectedIDs,
                    diagnostics: diagnostics,
                    reviewerPassed: groundedReviewerPassed,
                    reviewerSummary: review?.summary,
                    reviewerMissingCapabilityIDs:
                        groundedReviewerMissing,
                    reviewerUnnecessaryCapabilityIDs:
                        groundedReviewerUnnecessary,
                    reviewerRiskNotes:
                        review?.riskNotes ?? []
                )
            )
        }

        let reviewerFlagged = results.filter {
            $0.reviewerPassed == false ||
            !$0.reviewerMissingCapabilityIDs.isEmpty ||
            !$0.reviewerUnnecessaryCapabilityIDs.isEmpty
        }
        .count

        arenaStore.saveProgress(
            "v\(appVersion) • \(scenarios.count)/\(scenarios.count) • Arena tamamlandı"
        )

        return AgentArenaReport(
            createdAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            total: results.count,
            passed: results.filter(\.passed).count,
            failed: results.filter { !$0.passed }.count,
            reviewerFlagged: reviewerFlagged,
            results: results
        )
    }

    private func evaluate(
        _ scenario: AgentArenaScenario,
        mission: AgentSemanticMission
    ) -> [String] {
        let selected = Set(
            mission.requiredCapabilityIDs +
            mission.steps.map(\.capabilityID)
        )
        let outcomes = Set(mission.outcomes)
        var diagnostics: [String] = []

        let missingCapabilities =
            scenario.requiredCapabilities
                .subtracting(selected)
                .sorted()

        if !missingCapabilities.isEmpty {
            diagnostics.append(
                "Eksik capability: " +
                missingCapabilities.joined(
                    separator: ", "
                )
            )
        }

        let forbidden =
            scenario.forbiddenCapabilities
                .intersection(selected)
                .sorted()

        if !forbidden.isEmpty {
            diagnostics.append(
                "Gereksiz / yasak capability: " +
                forbidden.joined(separator: ", ")
            )
        }

        let missingOutcomes =
            scenario.requiredOutcomes
                .subtracting(outcomes)
                .sorted()

        if !missingOutcomes.isEmpty {
            diagnostics.append(
                "Eksik outcome: " +
                missingOutcomes.joined(separator: ", ")
            )
        }

        if scenario.shouldNotRequireUserInput &&
           mission.requiresUserInput {
            diagnostics.append(
                "Görev makul varsayımla ilerleyebilecekken gereksiz kullanıcı girdisi istendi."
            )
        }

        return diagnostics
    }

    private func makeScenarios() -> [AgentArenaScenario] {
        [
            AgentArenaScenario(
                id: "open-world-video-edit",
                title: "Doğal dilden uçtan uca video kurgu mission'ı",
                prompt:
                    "Son çekimlerden hızlı ve enerjik bir kurgu çıkarmamız gerekiyor.",
                requiredCapabilities: [
                    "files.search",
                    "files.metadata",
                    "perception.media",
                    "premiere.control",
                    "perception.screen"
                ],
                forbiddenCapabilities: [
                    "research.web"
                ],
                requiredOutcomes: [
                    "locate",
                    "assessContent",
                    "edit"
                ],
                shouldNotRequireUserInput: true
            ),
            AgentArenaScenario(
                id: "new-brand-social-design",
                title: "Yeni markayı araştırıp tasarıma dönüştürme",
                prompt:
                    "Köfteci Tame adında bir markamız var. Marka için sosyal medya tasarımı hazırlayalım.",
                requiredCapabilities: [
                    "research.web",
                    "photoshop.control",
                    "perception.screen"
                ],
                forbiddenCapabilities: [],
                requiredOutcomes: [
                    "research",
                    "analyze",
                    "edit"
                ],
                shouldNotRequireUserInput: true
            ),
            AgentArenaScenario(
                id: "desktop-cleanup",
                title: "Yerel masaüstü düzenleme",
                prompt:
                    "Masaüstündeki ekran görüntülerini toparlayıp ayrı bir klasöre düzenle.",
                requiredCapabilities: [
                    "files.search",
                    "files.move.reversible"
                ],
                forbiddenCapabilities: [
                    "research.web",
                    "browser.control"
                ],
                requiredOutcomes: [
                    "locate",
                    "organize"
                ],
                shouldNotRequireUserInput: true
            ),
            AgentArenaScenario(
                id: "browser-contact-task",
                title: "Etkileşimli web görevi",
                prompt:
                    "Bu firmanın sitesine girip iletişim sayfasını bul ve iletişim bilgilerini çıkar.",
                requiredCapabilities: [
                    "browser.control"
                ],
                forbiddenCapabilities: [
                    "files.search",
                    "files.metadata",
                    "files.reveal",
                    "perception.media"
                ],
                requiredOutcomes: [
                    "research"
                ],
                shouldNotRequireUserInput: false
            ),
            AgentArenaScenario(
                id: "work-mail-task",
                title: "İş maili orkestrasyonu",
                prompt:
                    "Bugün yaptığım işleri toparla ve müdürüme göndermek için mail taslağını hazırla.",
                requiredCapabilities: [
                    "context.local",
                    "mail.work"
                ],
                forbiddenCapabilities: [
                    "premiere.control",
                    "photoshop.control"
                ],
                requiredOutcomes: [
                    "communicate"
                ],
                shouldNotRequireUserInput: false
            ),
            AgentArenaScenario(
                id: "research-to-design",
                title: "Araştırmadan Photoshop üretimine zincir",
                prompt:
                    "Yeni açılan bir kahve markasını araştırıp görsel dilini analiz edelim ve Photoshop'ta örnek bir Instagram postu hazırlayalım.",
                requiredCapabilities: [
                    "research.web",
                    "photoshop.control",
                    "perception.screen"
                ],
                forbiddenCapabilities: [],
                requiredOutcomes: [
                    "research",
                    "analyze",
                    "edit"
                ],
                shouldNotRequireUserInput: true
            )
,
            AgentArenaScenario(
                id: "generic-desktop-app-open",
                title: "Genel masaüstü uygulama kontrolü",
                prompt:
                    "Notlar uygulamasını aç ve pencereyi öne getir.",
                requiredCapabilities: [
                    "desktop.app"
                ],
                forbiddenCapabilities: [
                    "premiere.control",
                    "photoshop.control",
                    "research.web"
                ],
                requiredOutcomes: [
                    "open"
                ],
                shouldNotRequireUserInput: true
            ),
            AgentArenaScenario(
                id: "generic-pdf-open",
                title: "Genel dosya bulma ve açma",
                prompt:
                    "İndirilenler klasöründeki en son PDF dosyasını bul ve Finder'da aç.",
                requiredCapabilities: [
                    "files.search",
                    "files.reveal"
                ],
                forbiddenCapabilities: [
                    "premiere.control",
                    "photoshop.control",
                    "research.web"
                ],
                requiredOutcomes: [
                    "locate",
                    "open"
                ],
                shouldNotRequireUserInput: true
            ),
            AgentArenaScenario(
                id: "generic-screen-observation",
                title: "Genel ekran gözlemi",
                prompt:
                    "Ekrana bak ve şu anda hangi uygulamanın önde olduğunu, ekranda genel olarak ne gördüğünü söyle.",
                requiredCapabilities: [
                    "perception.screen"
                ],
                forbiddenCapabilities: [
                    "premiere.control",
                    "photoshop.control",
                    "research.web"
                ],
                requiredOutcomes: [
                    "analyze",
                    "explain"
                ],
                shouldNotRequireUserInput: true
            )        ]
    }
}

struct AgentArenaStore {
    private let fileManager = FileManager.default

    var progressURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/arena-progress.txt",
                isDirectory: false
            )
    }

    func saveProgress(_ value: String) {
        let directory = progressURL
            .deletingLastPathComponent()

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        try? value.write(
            to: progressURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func readProgress() -> String? {
        try? String(
            contentsOf: progressURL,
            encoding: .utf8
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var outputURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor/arena-latest.json",
                isDirectory: false
            )
    }

    func save(_ report: AgentArenaReport) throws {
        let directory = outputURL
            .deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        try data.write(
            to: outputURL,
            options: .atomic
        )
    }

    func load() -> AgentArenaReport? {
        guard
            let data = try? Data(contentsOf: outputURL)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(
            AgentArenaReport.self,
            from: data
        )
    }
}


private extension Array where Element == String {
    func uniquedForTraining() -> [String] {
        var seen = Set<String>()
        return filter {
            seen.insert($0).inserted
        }
    }
}
