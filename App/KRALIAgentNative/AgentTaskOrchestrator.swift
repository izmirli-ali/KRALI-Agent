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
                        requiresApproval(
                            step: step,
                            capability:
                                capability
                        )
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

    private func requiresApproval(
        step: AgentSemanticMissionStep,
        capability: AgentCapability?
    ) -> Bool {
        guard
            capability?.risk ==
                .external ||
            capability?.risk ==
                .reversibleWrite
        else {
            return false
        }

        let actionCorpus = normalize(
            [
                step.operation,
                step.title
            ]
            .joined(separator: " ")
        )

        let purposeCorpus =
            normalize(step.purpose)

        let explicitNonCommitTerms = [
            "gondermeden",
            "gonderme",
            "commit etmeden",
            "onay almadan",
            "degisiklik yapma",
            "yalniz hazirla",
            "sadece hazirla",
            "henuz dis dunyaya"
        ]

        if explicitNonCommitTerms.contains(
            where: {
                purposeCorpus.contains($0)
            }
        ) {
            return false
        }

        let commitTerms = Set([
            "send", "gonder",
            "submit", "publish", "yayinla",
            "post", "paylas",
            "delete", "sil",
            "purchase", "satinal",
            "confirm", "onayla",
            "commit"
        ])

        let actionTokens =
            approvalTokens(
                actionCorpus
            )
        let purposeTokens =
            approvalTokens(
                purposeCorpus
            )

        return !actionTokens
            .intersection(commitTerms)
            .isEmpty ||
        !purposeTokens
            .intersection(commitTerms)
            .isEmpty
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
