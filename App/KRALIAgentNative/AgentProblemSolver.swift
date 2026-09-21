import Foundation

enum AgentSolutionStrategyKind:
    String,
    Codable,
    Hashable,
    Sendable {
    case primary
    case reuseEvidence
    case screenObservation
    case genericAppWorkflow
    case publicResearch
    case reasoningTransform
    case learning
}

struct AgentProblemFrame:
    Codable,
    Hashable,
    Sendable {
    let objective: String
    let observations: [String]
    let constraints: [String]
    let availableCapabilityIDs: [String]
    let blockedCapabilityIDs: [String]
}

struct AgentSolutionStrategy:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: String
    let kind: AgentSolutionStrategyKind
    let title: String
    let summary: String
    let capabilityIDs: [String]
    let score: Int
    let executableNow: Bool
    let requiresLearning: Bool
    let rationale: String
}

struct AgentProblemResolution:
    Codable,
    Hashable,
    Sendable {
    let frame: AgentProblemFrame
    let strategies: [AgentSolutionStrategy]
    let chosenStrategyID: String?
    let reflection: String?

    var chosenStrategy: AgentSolutionStrategy? {
        guard let chosenStrategyID else {
            return nil
        }

        return strategies.first {
            $0.id == chosenStrategyID
        }
    }
}

struct AgentProblemSolver {
    func frame(
        graph: AgentTaskGraph,
        capabilities: [AgentCapability],
        observations: [String] = []
    ) -> AgentProblemFrame {
        let available =
            capabilities
                .filter(\.isAvailable)
                .map(\.id)
                .sorted()

        let blocked =
            graph.blockedCapabilityIDs

        var constraints: [String] = [
            "Başarı gerçek observation/verification ile kanıtlanmalı.",
            "Dış dünyaya commit eden işlem kullanıcı onayı olmadan uygulanmamalı.",
            "Uygulama/marka adına özel hard-code yerine generic capability/strategy tercih edilmeli."
        ]

        if graph.steps.contains(where: {
            $0.risk == .reversibleWrite
        }) {
            constraints.append(
                "Yazma işlemleri geri alınabilir ve çalışma alanı sınırları içinde kalmalı."
            )
        }

        return AgentProblemFrame(
            objective: graph.objective,
            observations: observations,
            constraints: constraints,
            availableCapabilityIDs: available,
            blockedCapabilityIDs: blocked
        )
    }

    func solve(
        graph: AgentTaskGraph,
        capabilities: [AgentCapability],
        observations: [String] = []
    ) -> AgentProblemResolution {
        let frame = frame(
            graph: graph,
            capabilities: capabilities,
            observations: observations
        )

        var strategies: [AgentSolutionStrategy] = []

        for step in graph.steps {
            strategies.append(
                contentsOf:
                    strategiesForStep(
                        step,
                        capabilities: capabilities,
                        dependencyEvidence: ""
                    )
            )
        }

        strategies = deduplicate(
            strategies
        )
        .sorted {
            if $0.executableNow != $1.executableNow {
                return $0.executableNow &&
                    !$1.executableNow
            }

            return $0.score > $1.score
        }

        let chosen =
            strategies.first(
                where: {
                    $0.executableNow &&
                    !$0.requiresLearning
                }
            ) ??
            strategies.first

        return AgentProblemResolution(
            frame: frame,
            strategies: strategies,
            chosenStrategyID: chosen?.id,
            reflection: nil
        )
    }

    func strategiesForStep(
        _ step: AgentTaskGraphStep,
        capabilities: [AgentCapability],
        dependencyEvidence: String
    ) -> [AgentSolutionStrategy] {
        let available =
            Dictionary(
                uniqueKeysWithValues:
                    capabilities
                        .filter(\.isAvailable)
                        .map {
                            ($0.id, $0)
                        }
            )

        var strategies: [AgentSolutionStrategy] = []

        if step.isAvailable {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "primary:" +
                        step.capabilityID,
                    kind: .primary,
                    title:
                        "Mevcut provider'ı kullan",
                    summary:
                        step.title +
                        " adımını " +
                        step.capabilityID +
                        " ile yürüt.",
                    capabilityIDs: [
                        step.capabilityID
                    ],
                    score: 100,
                    executableNow: true,
                    requiresLearning: false,
                    rationale:
                        "Task Graph bu capability'yi doğrudan seçti ve provider available."
                )
            )
        }

        if !dependencyEvidence
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty,
           canReuseEvidence(
                for: step
           ) {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "reuse-evidence:" +
                        String(step.index),
                    kind: .reuseEvidence,
                    title:
                        "Mevcut kanıtı yeniden kullan",
                    summary:
                        "Önceki adımların doğrulanmış çıktısını yeni provider çağrısı yapmadan değerlendir.",
                    capabilityIDs: [
                        "core.reasoning"
                    ],
                    score: 88,
                    executableNow:
                        available[
                            "core.reasoning"
                        ] != nil,
                    requiresLearning: false,
                    rationale:
                        "Bağımlılık kanıtı zaten mevcut; salt-okunur reasoning/transform adımında yeniden gözlem gerekmeyebilir."
                )
            )
        }

        if canUseGenericAppWorkflow(
            for: step
        ),
           available["app.workflow"] != nil {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "generic-app:" +
                        String(step.index),
                    kind:
                        .genericAppWorkflow,
                    title:
                        "Generic uygulama iş akışı",
                    summary:
                        "Öndeki uygulamayı ekran kanıtıyla gözlemle ve hedefe uygun salt-okunur/prepare çıktısı üret.",
                    capabilityIDs: [
                        "app.workflow",
                        "perception.screen"
                    ],
                    score: 82,
                    executableNow:
                        available[
                            "perception.screen"
                        ] != nil,
                    requiresLearning: false,
                    rationale:
                        "İstenen adım uygulama-özel provider yerine generic observation + reasoning ile güvenli biçimde çözülebilir."
                )
            )
        }

        if canUseScreenObservation(
            for: step
        ),
           available[
                "perception.screen"
           ] != nil {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "screen-observe:" +
                        String(step.index),
                    kind:
                        .screenObservation,
                    title:
                        "Ekrandan gözlemle",
                    summary:
                        "Öndeki uygulamadaki görünür durumu Screen Perception ile oku ve postcondition'a kanıt üret.",
                    capabilityIDs: [
                        "perception.screen"
                    ],
                    score: 78,
                    executableNow: true,
                    requiresLearning: false,
                    rationale:
                        "Adım salt-okunur observe/retrieve niteliğinde; ekran gözlemi gerçek evidence sağlayabilir."
                )
            )
        }

        if canUsePublicResearch(
            for: step
        ),
           available[
                "research.web"
           ] != nil {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "public-research:" +
                        String(step.index),
                    kind:
                        .publicResearch,
                    title:
                        "Public web araştırması",
                    summary:
                        "Tarayıcı oturumu yerine kamuya açık web kaynaklarından gerekli salt-okunur bilgiyi getir.",
                    capabilityIDs: [
                        "research.web"
                    ],
                    score: 70,
                    executableNow: true,
                    requiresLearning: false,
                    rationale:
                        "Adım retrieve/read amaçlı ve dış dünyada değişiklik gerektirmiyor."
                )
            )
        }

        if canUseReasoningTransform(
            for: step
        ),
           available[
                "core.reasoning"
           ] != nil {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "reasoning:" +
                        String(step.index),
                    kind:
                        .reasoningTransform,
                    title:
                        "Kanıtı reasoning ile dönüştür",
                    summary:
                        "Mevcut dependency evidence üzerinde analiz/sentez uygula.",
                    capabilityIDs: [
                        "core.reasoning"
                    ],
                    score: 75,
                    executableNow: true,
                    requiresLearning: false,
                    rationale:
                        "Adımın amacı dış değişiklik değil; mevcut kanıttan yeni bir bilgi/çıktı üretmek."
                )
            )
        }

        if strategies
            .filter({
                $0.executableNow &&
                !$0.requiresLearning
            })
            .isEmpty {
            strategies.append(
                AgentSolutionStrategy(
                    id:
                        "learn:" +
                        step.capabilityID,
                    kind: .learning,
                    title:
                        "Capability öğren",
                    summary:
                        step.capabilityID +
                        " için güvenli provider/strategy öğrenme hattını başlat.",
                    capabilityIDs: [
                        step.capabilityID
                    ],
                    score: 10,
                    executableNow: false,
                    requiresLearning: true,
                    rationale:
                        "Mevcut capability setinde hedefi güvenilir biçimde tamamlayacak güvenli alternatif bulunamadı."
                )
            )
        }

        return deduplicate(
            strategies
        )
        .sorted {
            $0.score > $1.score
        }
    }

    func reflection(
        step: AgentTaskGraphStep,
        attemptedStrategyIDs: [String],
        dependencyEvidence: String,
        capabilities: [AgentCapability]
    ) -> AgentProblemResolution {
        let graph = AgentTaskGraph(
            objective: step.title,
            steps: [step]
        )

        let strategies =
            strategiesForStep(
                step,
                capabilities: capabilities,
                dependencyEvidence:
                    dependencyEvidence
            )

        let untried =
            strategies.filter {
                !attemptedStrategyIDs
                    .contains($0.id)
            }

        let chosen =
            untried.first(
                where: {
                    $0.executableNow &&
                    !$0.requiresLearning
                }
            ) ??
            untried.first

        let summary: String

        if let chosen {
            summary =
                "İlk yaklaşım hedefe ulaşmadı. " +
                "Kalan güvenli stratejiler değerlendirildi; sıradaki yaklaşım: " +
                chosen.title +
                "."
        } else {
            summary =
                "Mevcut güvenli stratejiler tükendi; capability learning gerekli."
        }

        return AgentProblemResolution(
            frame: frame(
                graph: graph,
                capabilities: capabilities,
                observations: [
                    "Başarısız step: " +
                        step.title,
                    dependencyEvidence
                ]
                .filter {
                    !$0.isEmpty
                }
            ),
            strategies: strategies,
            chosenStrategyID: chosen?.id,
            reflection: summary
        )
    }

    func candidateCapabilityIDs(
        for step: AgentTaskGraphStep,
        availableCapabilities: [AgentCapability]
    ) -> [String] {
        strategiesForStep(
            step,
            capabilities:
                availableCapabilities,
            dependencyEvidence: ""
        )
        .filter {
            $0.executableNow &&
            !$0.requiresLearning &&
            $0.kind != .primary
        }
        .flatMap(\.capabilityIDs)
        .filter {
            $0 !=
                step.capabilityID
        }
        .uniqued()
        .sorted()
    }

    private func canReuseEvidence(
        for step: AgentTaskGraphStep
    ) -> Bool {
        switch step.role {
        case .reason,
             .transform,
             .verify:
            return true

        case .observe,
             .retrieve,
             .act,
             .persist,
             .communicate:
            return false
        }
    }

    private func canUseScreenObservation(
        for step: AgentTaskGraphStep
    ) -> Bool {
        guard
            step.risk == .readOnly ||
            step.risk == .external
        else {
            return false
        }

        switch step.role {
        case .observe,
             .retrieve:
            return isApplicationLike(step)

        default:
            return false
        }
    }

    private func canUseGenericAppWorkflow(
        for step: AgentTaskGraphStep
    ) -> Bool {
        guard isApplicationLike(step) else {
            return false
        }

        switch step.role {
        case .observe,
             .retrieve,
             .transform:
            return !looksLikeExternalCommit(
                step
            )

        default:
            return false
        }
    }

    private func canUsePublicResearch(
        for step: AgentTaskGraphStep
    ) -> Bool {
        guard step.role == .retrieve else {
            return false
        }

        let corpus = normalizedCorpus(step)

        let publicTerms = [
            "web",
            "browser",
            "site",
            "sayfa",
            "public",
            "research",
            "arastir",
            "internet"
        ]

        let privateTerms = [
            "mail",
            "gmail",
            "mesaj",
            "hesabim",
            "oturum",
            "login",
            "inbox"
        ]

        return publicTerms.contains(
            where: {
                corpus.contains($0)
            }
        ) &&
        !privateTerms.contains(
            where: {
                corpus.contains($0)
            }
        )
    }

    private func canUseReasoningTransform(
        for step: AgentTaskGraphStep
    ) -> Bool {
        switch step.role {
        case .reason,
             .transform:
            return true

        default:
            return false
        }
    }

    private func isApplicationLike(
        _ step: AgentTaskGraphStep
    ) -> Bool {
        if step.capabilityID.hasPrefix(
            "files."
        ) ||
           step.capabilityID.hasPrefix(
            "memory."
        ) ||
           step.capabilityID.hasPrefix(
            "speech."
        ) ||
           step.capabilityID ==
            "research.web" {
            return false
        }

        return step.risk == .external ||
            step.capabilityID ==
                "app.workflow" ||
            step.capabilityID ==
                "perception.screen" ||
            step.capabilityID ==
                "desktop.app"
    }

    private func looksLikeExternalCommit(
        _ step: AgentTaskGraphStep
    ) -> Bool {
        let corpus = normalizedCorpus(
            step
        )

        let commitTerms = [
            "send", "gonder",
            "submit", "publish",
            "yayinla", "paylas",
            "delete", "sil",
            "purchase", "satinal",
            "save", "kaydet",
            "create", "olustur",
            "change", "degistir",
            "apply", "uygula",
            "confirm", "onayla"
        ]

        return commitTerms.contains {
            corpus.contains($0)
        }
    }

    private func normalizedCorpus(
        _ step: AgentTaskGraphStep
    ) -> String {
        [
            step.title,
            step.operation,
            step.capabilityID
        ]
        .joined(separator: " ")
        .folding(
            options: [
                .diacriticInsensitive,
                .caseInsensitive
            ],
            locale: Locale(
                identifier: "tr_TR"
            )
        )
        .lowercased()
        .replacingOccurrences(
            of: "ı",
            with: "i"
        )
    }

    private func deduplicate(
        _ strategies: [AgentSolutionStrategy]
    ) -> [AgentSolutionStrategy] {
        var seen = Set<String>()

        return strategies.filter {
            seen.insert($0.id).inserted
        }
    }
}

private extension Array
where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()

        return filter {
            seen.insert($0).inserted
        }
    }
}
