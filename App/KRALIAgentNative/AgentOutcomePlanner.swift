import Foundation

enum AgentOutcomeRequirementKind:
    String,
    Codable,
    Hashable,
    Sendable {
    case retrievePublicInformation
    case observeApplicationState
    case locateLocalResource
    case transformEvidence
    case mutateExternalState
    case communicate
    case openResource
}

struct AgentOutcomeRequirement:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: String
    let kind: AgentOutcomeRequirementKind
    let title: String
    let successCriterion: String
    let preferredCapabilityIDs: [String]
    let acceptableCapabilityIDs: [String]
    let requiresMutation: Bool
}

struct AgentOutcomeContract:
    Codable,
    Hashable,
    Sendable {
    let objective: String
    let requirements: [AgentOutcomeRequirement]
    let successCriteria: [String]
    let instrumentalCapabilityIDs: Set<String>

    var requiresMutation: Bool {
        requirements.contains {
            $0.requiresMutation
        }
    }
}

enum AgentOutcomeStrategyKind:
    String,
    Codable,
    Hashable,
    Sendable {
    case directCapability
    case publicResearch
    case screenObservation
    case genericAppWorkflow
    case localFiles
    case reasoningTransform
    case learning
}

struct AgentOutcomeStrategy:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: String
    let requirementID: String
    let kind: AgentOutcomeStrategyKind
    let title: String
    let capabilityIDs: [String]
    let score: Int
    let executableNow: Bool
    let requiresLearning: Bool
    let rationale: String
}

struct AgentOutcomeResolution:
    Codable,
    Hashable,
    Sendable {
    let contract: AgentOutcomeContract
    let strategies: [AgentOutcomeStrategy]
    let chosenStrategyIDs: [String]
    let coveredRequirementIDs: Set<String>
    let suppressedLearningCapabilityIDs: Set<String>

    var chosenStrategies: [AgentOutcomeStrategy] {
        strategies.filter {
            chosenStrategyIDs.contains(
                $0.id
            )
        }
    }

    var isFullyCovered: Bool {
        Set(
            contract.requirements.map(\.id)
        )
        .isSubset(
            of: coveredRequirementIDs
        )
    }
}

struct AgentOutcomePlanner {
    func makeContract(
        userInput: String,
        goal: AgentGoalProfile,
        mission: AgentSemanticMission?
    ) -> AgentOutcomeContract {
        let text = normalize(userInput)
        var requirements: [AgentOutcomeRequirement] = []
        var instrumental = Set<String>()

        let researchLike =
            goal.outcomes.contains(.research) ||
            goal.outcomes.contains(.explain) ||
            mission?.outcomes.contains(
                AgentGoalOutcome.research.rawValue
            ) == true

        let webLike =
            containsAny(
                text,
                [
                    "http://",
                    "https://",
                    ".com",
                    ".net",
                    ".org",
                    ".io",
                    ".co",
                    "site",
                    "sitesi",
                    "sayfa",
                    "web",
                    "internet",
                    "browser",
                    "tarayici"
                ]
            )

        if researchLike && webLike {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "public-information",
                    kind:
                        .retrievePublicInformation,
                    title:
                        "İstenen public bilgiyi elde et",
                    successCriterion:
                        "Kullanıcının istediği bilgi gerçek public kaynaktan kanıtla elde edilmiş olmalı.",
                    preferredCapabilityIDs: [
                        "research.web"
                    ],
                    acceptableCapabilityIDs: [
                        "research.web",
                        "browser.control",
                        "perception.screen"
                    ],
                    requiresMutation: false
                )
            )

            instrumental.formUnion([
                "browser.control",
                "desktop.app",
                "app.workflow"
            ])
        }

        if goal.outcomes.contains(.locate) {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "local-resource",
                    kind:
                        .locateLocalResource,
                    title:
                        "Yerel hedef öğeyi bul",
                    successCriterion:
                        "Hedef öğe doğru kapsamda gerçek dosya/klasör kanıtıyla bulunmalı.",
                    preferredCapabilityIDs: [
                        "files.search"
                    ],
                    acceptableCapabilityIDs: [
                        "files.search",
                        "files.metadata"
                    ],
                    requiresMutation: false
                )
            )
        }

        if goal.outcomes.contains(.assessContent) {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "content-observation",
                    kind:
                        .observeApplicationState,
                    title:
                        "İçeriği doğrudan gözlemle",
                    successCriterion:
                        "Değerlendirme gerçek içerik veya ekran kanıtına dayanmalı.",
                    preferredCapabilityIDs: [
                        "perception.media",
                        "perception.screen"
                    ],
                    acceptableCapabilityIDs: [
                        "perception.media",
                        "perception.screen"
                    ],
                    requiresMutation: false
                )
            )
        }

        if goal.outcomes.contains(.transform) ||
           goal.outcomes.contains(.analyze) ||
           goal.outcomes.contains(.ideate) ||
           goal.outcomes.contains(.compose) {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "reasoning-output",
                    kind:
                        .transformEvidence,
                    title:
                        "Kanıttan istenen çıktıyı üret",
                    successCriterion:
                        "Çıktı eldeki kanıt ve kullanıcı hedefiyle tutarlı olmalı.",
                    preferredCapabilityIDs: [
                        "core.reasoning"
                    ],
                    acceptableCapabilityIDs: [
                        "core.reasoning"
                    ],
                    requiresMutation: false
                )
            )
        }

        if goal.outcomes.contains(.communicate) {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "communication",
                    kind:
                        .communicate,
                    title:
                        "İletişim çıktısını hazırla veya gönder",
                    successCriterion:
                        "Taslak ve gönderim durumu kullanıcı niyetiyle uyumlu olmalı; dış gönderim onay kapısını korumalı.",
                    preferredCapabilityIDs: [
                        "mail.work"
                    ],
                    acceptableCapabilityIDs: [
                        "mail.work",
                        "core.reasoning"
                    ],
                    requiresMutation: true
                )
            )
        }

        if goal.outcomes.contains(.edit) ||
           goal.outcomes.contains(.organize) {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "external-mutation",
                    kind:
                        .mutateExternalState,
                    title:
                        "İstenen değişikliği uygula",
                    successCriterion:
                        "Dış durum gerçekten değişmiş ve postcondition gözlemle doğrulanmış olmalı.",
                    preferredCapabilityIDs:
                        Array(
                            goal.requiredCapabilityIDs
                                .filter {
                                    $0 !=
                                        "core.reasoning" &&
                                    $0 !=
                                        "context.local"
                                }
                        )
                        .sorted(),
                    acceptableCapabilityIDs:
                        Array(
                            goal.requiredCapabilityIDs
                                .filter {
                                    $0 !=
                                        "core.reasoning" &&
                                    $0 !=
                                        "context.local"
                                }
                        )
                        .sorted(),
                    requiresMutation: true
                )
            )
        }

        if goal.outcomes.contains(.open) &&
           requirements.isEmpty {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "open-resource",
                    kind:
                        .openResource,
                    title:
                        "Hedef kaynağı aç veya öne getir",
                    successCriterion:
                        "Hedef kaynak gerçekten açılmış/öne gelmiş olmalı.",
                    preferredCapabilityIDs: [
                        "desktop.app",
                        "files.reveal",
                        "browser.control"
                    ],
                    acceptableCapabilityIDs: [
                        "desktop.app",
                        "files.reveal",
                        "browser.control",
                        "app.workflow"
                    ],
                    requiresMutation: false
                )
            )
        }

        if requirements.isEmpty {
            requirements.append(
                AgentOutcomeRequirement(
                    id:
                        "reasoning-output",
                    kind:
                        .transformEvidence,
                    title:
                        "Kullanıcı hedefini anlamlandır ve yanıtla",
                    successCriterion:
                        "Yanıt güncel kullanıcı hedefi ve mevcut kanıtla tutarlı olmalı.",
                    preferredCapabilityIDs: [
                        "core.reasoning"
                    ],
                    acceptableCapabilityIDs: [
                        "core.reasoning"
                    ],
                    requiresMutation: false
                )
            )
        }

        return AgentOutcomeContract(
            objective:
                mission?.objective ??
                goal.summary,
            requirements:
                deduplicateRequirements(
                    requirements
                ),
            successCriteria:
                deduplicateRequirements(
                    requirements
                )
                .map(
                    \.successCriterion
                ),
            instrumentalCapabilityIDs:
                instrumental
        )
    }

    func resolve(
        contract: AgentOutcomeContract,
        capabilities: [AgentCapability]
    ) -> AgentOutcomeResolution {
        let available =
            Set(
                capabilities
                    .filter(\.isAvailable)
                    .map(\.id)
            )

        var strategies: [AgentOutcomeStrategy] = []
        var chosen: [String] = []
        var covered = Set<String>()

        for requirement in
            contract.requirements {
            let candidates =
                strategiesForRequirement(
                    requirement,
                    availableCapabilityIDs:
                        available
                )

            strategies.append(
                contentsOf:
                    candidates
            )

            if let selected =
                candidates
                    .filter {
                        $0.executableNow &&
                        !$0.requiresLearning
                    }
                    .sorted(
                        by: {
                            $0.score >
                                $1.score
                        }
                    )
                    .first {
                chosen.append(
                    selected.id
                )
                covered.insert(
                    requirement.id
                )
            } else if let learning =
                candidates.first(
                    where: {
                        $0.requiresLearning
                    }
                ) {
                chosen.append(
                    learning.id
                )
            }
        }

        var suppressed = Set<String>()

        if !contract.requiresMutation,
           Set(
                contract.requirements
                    .map(\.id)
           )
           .isSubset(of: covered) {
            suppressed.formUnion(
                contract
                    .instrumentalCapabilityIDs
            )
        }

        return AgentOutcomeResolution(
            contract: contract,
            strategies:
                deduplicateStrategies(
                    strategies
                ),
            chosenStrategyIDs:
                chosen,
            coveredRequirementIDs:
                covered,
            suppressedLearningCapabilityIDs:
                suppressed
        )
    }

    private func strategiesForRequirement(
        _ requirement:
            AgentOutcomeRequirement,
        availableCapabilityIDs:
            Set<String>
    ) -> [AgentOutcomeStrategy] {
        var results: [AgentOutcomeStrategy] = []

        for capabilityID in
            requirement
                .preferredCapabilityIDs {
            if availableCapabilityIDs
                .contains(capabilityID) {
                results.append(
                    AgentOutcomeStrategy(
                        id:
                            requirement.id +
                            ":direct:" +
                            capabilityID,
                        requirementID:
                            requirement.id,
                        kind:
                            strategyKind(
                                for:
                                    capabilityID
                            ),
                        title:
                            "Outcome'u " +
                            capabilityID +
                            " ile çöz",
                        capabilityIDs: [
                            capabilityID
                        ],
                        score:
                            directScore(
                                for:
                                    capabilityID,
                                requirement:
                                    requirement
                            ),
                        executableNow:
                            true,
                        requiresLearning:
                            false,
                        rationale:
                            "Bu capability başarı kriterini doğrudan karşılayabiliyor."
                    )
                )
            }
        }

        if requirement.kind ==
            .retrievePublicInformation {
            if availableCapabilityIDs
                .contains(
                    "research.web"
                ) {
                results.append(
                    AgentOutcomeStrategy(
                        id:
                            requirement.id +
                            ":public-research",
                        requirementID:
                            requirement.id,
                        kind:
                            .publicResearch,
                        title:
                            "Public kaynaktan bilgi edin",
                        capabilityIDs: [
                            "research.web"
                        ],
                        score: 110,
                        executableNow: true,
                        requiresLearning: false,
                        rationale:
                            "Kullanıcının başarı kriteri bilgi edinmek; tarayıcı UI'sı araçtır, zorunlu outcome değildir."
                    )
                )
            }

            if availableCapabilityIDs
                .contains(
                    "perception.screen"
                ) &&
               availableCapabilityIDs
                .contains(
                    "desktop.app"
                ) {
                results.append(
                    AgentOutcomeStrategy(
                        id:
                            requirement.id +
                            ":screen-observation",
                        requirementID:
                            requirement.id,
                        kind:
                            .screenObservation,
                        title:
                            "Uygulama + ekran gözlemiyle bilgi edin",
                        capabilityIDs: [
                            "desktop.app",
                            "perception.screen"
                        ],
                        score: 70,
                        executableNow: true,
                        requiresLearning: false,
                        rationale:
                            "Public bilgi başka yolla alınamazsa görünür uygulama durumundan salt-okunur kanıt üretilebilir."
                    )
                )
            }
        }

        if results
            .filter({
                $0.executableNow &&
                !$0.requiresLearning
            })
            .isEmpty {
            let missing =
                requirement
                    .preferredCapabilityIDs
                    .first ??
                requirement
                    .acceptableCapabilityIDs
                    .first ??
                "unknown"

            results.append(
                AgentOutcomeStrategy(
                    id:
                        requirement.id +
                        ":learn:" +
                        missing,
                    requirementID:
                        requirement.id,
                    kind:
                        .learning,
                    title:
                        "Outcome için capability öğren",
                    capabilityIDs: [
                        missing
                    ],
                    score: 10,
                    executableNow: false,
                    requiresLearning: true,
                    rationale:
                        "Başarı kriterini karşılayacak mevcut güvenli capability kombinasyonu bulunamadı."
                )
            )
        }

        return deduplicateStrategies(
            results
        )
    }

    private func directScore(
        for capabilityID: String,
        requirement:
            AgentOutcomeRequirement
    ) -> Int {
        if requirement.kind ==
            .retrievePublicInformation &&
           capabilityID ==
            "research.web" {
            return 110
        }

        if capabilityID ==
            "core.reasoning" {
            return 95
        }

        return 90
    }

    private func strategyKind(
        for capabilityID: String
    ) -> AgentOutcomeStrategyKind {
        switch capabilityID {
        case "research.web":
            return .publicResearch
        case "perception.screen",
             "perception.media":
            return .screenObservation
        case "app.workflow",
             "desktop.app":
            return .genericAppWorkflow
        case "files.search",
             "files.metadata",
             "files.reveal":
            return .localFiles
        case "core.reasoning":
            return .reasoningTransform
        default:
            return .directCapability
        }
    }

    private func normalize(
        _ text: String
    ) -> String {
        text.folding(
            options: [
                .diacriticInsensitive,
                .caseInsensitive
            ],
            locale:
                Locale(
                    identifier: "tr_TR"
                )
        )
        .lowercased()
        .replacingOccurrences(
            of: "ı",
            with: "i"
        )
    }

    private func containsAny(
        _ text: String,
        _ needles: [String]
    ) -> Bool {
        needles.contains {
            text.contains($0)
        }
    }

    private func deduplicateRequirements(
        _ input: [AgentOutcomeRequirement]
    ) -> [AgentOutcomeRequirement] {
        var seen = Set<String>()

        return input.filter {
            seen.insert($0.id).inserted
        }
    }

    private func deduplicateStrategies(
        _ input: [AgentOutcomeStrategy]
    ) -> [AgentOutcomeStrategy] {
        var seen = Set<String>()

        return input.filter {
            seen.insert($0.id).inserted
        }
    }
}
