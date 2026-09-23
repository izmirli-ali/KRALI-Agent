import Foundation

enum AgentTaskStepRole: String, Hashable {
    case reason
    case observe
    case retrieve
    case transform
    case act
    case persist
    case communicate
    case verify
}

struct AgentTaskGraphStep: Identifiable, Hashable {
    var id: Int { index }

    let index: Int
    let title: String
    let capabilityID: String
    let operation: String
    let role: AgentTaskStepRole
    let dependsOn: [Int]
    let risk: AgentCapabilityRisk
    let isAvailable: Bool
    let requiresApproval: Bool
    var approvalReason: String? = nil
}

struct AgentTaskGraph: Hashable {
    let objective: String
    let steps: [AgentTaskGraphStep]

    var blockedCapabilityIDs: [String] {
        Array(
            Set(
                steps
                    .filter { !$0.isAvailable }
                    .map(\.capabilityID)
            )
        )
        .sorted()
    }

    var approvalStepIndexes: [Int] {
        steps
            .filter(\.requiresApproval)
            .map(\.index)
    }
}

struct AgentTaskOrchestrator {
    func compile(
        mission: AgentSemanticMission,
        capabilities: [AgentCapability]
    ) -> AgentTaskGraph {
        let registry =
            Dictionary(
                uniqueKeysWithValues:
                    capabilities.map {
                        ($0.id, $0)
                    }
            )

        let steps = mission.steps
            .enumerated()
            .map { index, step in
                let capability =
                    registry[step.capabilityID]

                let approvalReason =
                    approvalReason(
                        step: step,
                        capability:
                            capability
                    )

                return AgentTaskGraphStep(
                    index: index,
                    title: step.title,
                    capabilityID:
                        step.capabilityID,
                    operation:
                        step.operation,
                    role:
                        role(
                            for: step
                        ),
                    dependsOn:
                        step.dependsOn,
                    risk:
                        capability?.risk ??
                        .reasoning,
                    isAvailable:
                        capability?
                            .isAvailable ??
                        false,
                    requiresApproval:
                        approvalReason != nil,
                    approvalReason:
                        approvalReason
                )
            }

        return AgentTaskGraph(
            objective: mission.objective,
            steps: steps
        )
    }

    func dependencyEvidence(
        for step: AgentTaskGraphStep,
        evidence: [Int: String]
    ) -> String {
        step.dependsOn
            .compactMap {
                evidence[$0]
            }
            .filter {
                !$0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }
            .joined(separator: "\n\n")
    }

    private func role(
        for step: AgentSemanticMissionStep
    ) -> AgentTaskStepRole {
        let corpus = normalize(
            [
                step.operation,
                step.title,
                step.purpose
            ]
            .joined(separator: " ")
        )

        if step.capabilityID ==
            "context.local" {
            return .reason
        }

        if step.capabilityID ==
            "core.reasoning" {
            if corpus.contains("analiz") ||
               corpus.contains("analyze") ||
               corpus.contains("sentez") ||
               corpus.contains("synthesize") ||
               corpus.contains("donustur") ||
               corpus.contains("transform") ||
               corpus.contains("ozet") ||
               corpus.contains("summar") {
                return .transform
            }

            return .reason
        }

        if step.capabilityID.hasPrefix(
            "perception."
        ) {
            return .observe
        }

        if step.capabilityID ==
            "research.web" ||
           step.capabilityID ==
            "files.search" ||
           step.capabilityID ==
            "files.metadata" {
            return .retrieve
        }

        if step.capabilityID ==
            "files.write.text" ||
           step.capabilityID ==
            "files.move.reversible" {
            return .persist
        }

        if step.capabilityID ==
            "mail.work" {
            return .communicate
        }

        let commitTerms = [
            "send", "gonder",
            "submit", "publish", "yayinla",
            "paylas", "delete", "sil",
            "save", "kaydet",
            "create", "olustur",
            "change", "degistir",
            "apply", "uygula",
            "confirm", "onayla",
            "move", "tasi",
            "edit", "duzenle"
        ]

        if commitTerms.contains(
            where: {
                corpus.contains($0)
            }
        ) {
            return .act
        }

        let observationTerms = [
            "observe", "gozlem",
            "read", "oku",
            "inspect", "incele",
            "list", "listele",
            "get", "al",
            "find", "bul",
            "current", "mevcut",
            "active", "aktif",
            "status", "durum"
        ]

        if observationTerms.contains(
            where: {
                corpus.contains($0)
            }
        ) {
            return .retrieve
        }

        if step.capabilityID ==
            "app.workflow" {
            return .act
        }

        if corpus.contains("verify") ||
           corpus.contains("dogrula") ||
           corpus.contains("kontrol") {
            return .verify
        }

        if corpus.contains("analiz") ||
           corpus.contains("sentez") ||
           corpus.contains("donustur") ||
           corpus.contains("ozet") {
            return .transform
        }

        return .act
    }

    func approvalReason(
        step: AgentSemanticMissionStep,
        capability: AgentCapability?
    ) -> String? {
        approvalReason(
            title: step.title,
            operation: step.operation,
            purpose: step.purpose,
            capability: capability
        )
    }

    func approvalReason(
        title: String,
        operation: String,
        purpose: String = "",
        capability: AgentCapability?
    ) -> String? {
        guard let capability else {
            return nil
        }

        let capabilityID =
            capability.id

        // Strict Approval Mode:
        // Read-only reasoning, local context, screen observation and static
        // web research may proceed. Any capability that can move foreground,
        // open a user-facing resource, interact with an app, communicate or
        // write user data must stop before execution and ask in chat.
        switch capabilityID {
        case "desktop.app":
            return "Bir uygulama açılacak veya öne getirilecek."

        case "system.open.url":
            return "Bir web adresi varsayılan uygulamada açılacak."

        case "files.reveal":
            return "Finder öne getirilecek ve bir dosya veya klasör gösterilecek."

        case "desktop.control":
            return "macOS arayüzünde mouse, klavye, menü veya alan etkileşimi yapılacak."

        case "browser.control":
            return "Tarayıcı arayüzünde kullanıcı etkileşimi yapılacak."

        case "premiere.control":
            return "Premiere içinde kullanıcı projesini etkileyebilecek bir işlem yapılacak."

        case "photoshop.control":
            return "Photoshop içinde kullanıcı belgesini etkileyebilecek bir işlem yapılacak."

        case "mail.work":
            return "Mail hesabı veya dış iletişim üzerinde bir işlem yapılacak."

        case "files.write.text":
            return "Dosya sistemine yeni bir metin dosyası yazılacak."

        case "files.move.reversible":
            return "Dosyanın konumu veya kimliği değiştirilecek."

        default:
            break
        }

        if capability.risk ==
            .reversibleWrite {
            return "Dosya sistemi veya kullanıcı verisi üzerinde geri alınabilir bir değişiklik yapılacak."
        }

        return nil
    }

    func approvalTargetIsResolved(
        capabilityID: String,
        targetSummary: String?,
        targetName: String? = nil,
        targetPath: String? = nil
    ) -> Bool {
        func present(
            _ value: String?
        ) -> Bool {
            !(value?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty ?? true)
        }

        switch capabilityID {
        case "desktop.app":
            return
                present(targetName) &&
                present(targetPath)

        case "system.open.url",
             "browser.control",
             "files.reveal":
            return present(
                targetSummary
            )

        default:
            return true
        }
    }

    private func approvalTokens(
        _ value: String
    ) -> Set<String> {
        let normalizedValue =
            normalize(value)

        let scalars =
            normalizedValue
                .unicodeScalars
                .map {
                    CharacterSet
                        .alphanumerics
                        .contains($0)
                        ? Character($0)
                        : " "
                }

        return Set(
            String(scalars)
                .split(
                    whereSeparator: {
                        $0.isWhitespace
                    }
                )
                .map(String.init)
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
                locale:
                    Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(
                of: "ı",
                with: "i"
            )
    }
}


enum AgentRuntimeTaskState:
    String,
    Codable,
    Hashable,
    Sendable {
    case queued
    case planning
    case ready
    case running
    case waitingForResource
    case waitingForApproval
    case verifying
    case completed
    case failed
    case paused
    case cancelled
}

enum AgentRuntimeResource:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable {
    case foreground
    case userInteraction
    case screenObservation
    case filesystemWrite
    case network
}

struct AgentRuntimeTask:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: String
    let objective: String
    let priority: Int
    let createdAt: Date
    var state: AgentRuntimeTaskState
    var completedStepIndexes: Set<Int>
    var runningStepIndexes: Set<Int>
    var waitingResourceIDs: Set<AgentRuntimeResource>

    init(
        id: String = UUID().uuidString,
        objective: String,
        priority: Int = 0,
        createdAt: Date = Date(),
        state: AgentRuntimeTaskState = .queued,
        completedStepIndexes: Set<Int> = [],
        runningStepIndexes: Set<Int> = [],
        waitingResourceIDs: Set<AgentRuntimeResource> = []
    ) {
        self.id = id
        self.objective = objective
        self.priority = priority
        self.createdAt = createdAt
        self.state = state
        self.completedStepIndexes = completedStepIndexes
        self.runningStepIndexes = runningStepIndexes
        self.waitingResourceIDs = waitingResourceIDs
    }
}

struct AgentRuntimeResourceLease:
    Codable,
    Hashable,
    Sendable {
    let resource: AgentRuntimeResource
    let taskID: String
}

enum AgentRuntimeResourceDecision:
    Hashable,
    Sendable {
    case acquired([AgentRuntimeResourceLease])
    case waiting(Set<AgentRuntimeResource>)
}

struct AgentRuntimeResourceScheduler:
    Sendable {
    private(set) var owners:
        [AgentRuntimeResource: String] = [:]

    mutating func acquire(
        _ resources: Set<AgentRuntimeResource>,
        for taskID: String
    ) -> AgentRuntimeResourceDecision {
        let blocked =
            Set(
                resources.filter { resource in
                    guard let owner = owners[resource] else {
                        return false
                    }

                    return owner != taskID
                }
            )

        guard blocked.isEmpty else {
            return .waiting(blocked)
        }

        let leases =
            resources
                .sorted {
                    $0.rawValue < $1.rawValue
                }
                .map { resource in
                    owners[resource] = taskID

                    return AgentRuntimeResourceLease(
                        resource: resource,
                        taskID: taskID
                    )
                }

        return .acquired(leases)
    }

    mutating func release(
        taskID: String
    ) {
        owners =
            owners.filter {
                $0.value != taskID
            }
    }

    mutating func release(
        _ resources: Set<AgentRuntimeResource>,
        taskID: String
    ) {
        for resource in resources
            where owners[resource] == taskID {
            owners.removeValue(
                forKey: resource
            )
        }
    }

    func owner(
        of resource: AgentRuntimeResource
    ) -> String? {
        owners[resource]
    }
}

struct AgentTaskRuntimePlanner {
    func makeTask(
        graph: AgentTaskGraph,
        priority: Int = 0
    ) -> AgentRuntimeTask {
        AgentRuntimeTask(
            objective: graph.objective,
            priority: priority,
            state: .ready
        )
    }

    func readyStepIndexes(
        graph: AgentTaskGraph,
        completedStepIndexes:
            Set<Int>,
        runningStepIndexes:
            Set<Int> = []
    ) -> [Int] {
        graph.steps
            .filter { step in
                !completedStepIndexes
                    .contains(step.index) &&
                !runningStepIndexes
                    .contains(step.index) &&
                Set(step.dependsOn)
                    .isSubset(
                        of:
                            completedStepIndexes
                    )
            }
            .map(\.index)
            .sorted()
    }

    func requiredResources(
        for step: AgentTaskGraphStep
    ) -> Set<AgentRuntimeResource> {
        var resources =
            Set<AgentRuntimeResource>()

        if step.capabilityID ==
            "desktop.app" ||
           step.capabilityID ==
            "app.workflow" ||
           step.capabilityID ==
            "system.open.url" {
            resources.insert(
                .foreground
            )
        }

        if step.capabilityID ==
            "perception.screen" {
            resources.insert(
                .screenObservation
            )
        }

        if step.capabilityID ==
            "research.web" {
            resources.insert(
                .network
            )
        }

        if step.capabilityID ==
            "files.write.text" ||
           step.capabilityID ==
            "files.move.reversible" {
            resources.insert(
                .filesystemWrite
            )
        }

        if step.role == .act &&
           (
                step.capabilityID ==
                    "desktop.app" ||
                step.capabilityID ==
                    "app.workflow"
           ) {
            resources.insert(
                .userInteraction
            )
        }

        return resources
    }
}
