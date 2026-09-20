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
