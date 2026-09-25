import Foundation

enum AgentSourceRevisionPolicy {
    static func exactRevision(
        _ raw: String?
    ) -> String? {
        guard let raw else {
            return nil
        }

        let value =
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard value.count == 40 else {
            return nil
        }

        let allowed =
            CharacterSet(
                charactersIn: "0123456789abcdef"
            )

        guard value.unicodeScalars.allSatisfy({
            allowed.contains($0)
        }) else {
            return nil
        }

        return value
    }
}

enum AgentDevelopmentSuggestionSource:
    String,
    Codable,
    Hashable,
    Sendable {
    case capabilityGap
    case research
    case arena
    case training
    case mentor
    case developerFailure
    case architecture
    case usability
}

enum AgentDevelopmentSuggestionState:
    String,
    Codable,
    Hashable,
    Sendable {
    case proposed
    case deferred
    case suppressed
    case approved
    case developing
    case readyForReview
    case failed
    case released
    case completed
}

struct AgentDevelopmentSuggestion:
    Identifiable,
    Codable,
    Hashable,
    Sendable {
    let id: UUID
    let fingerprint: String
    let source:
        AgentDevelopmentSuggestionSource
    let capabilityID: String?
    let capabilityName: String?
    let capabilityKind:
        CapabilityGapKind?
    let learningPath:
        CapabilityLearningPath?
    let candidateCapabilityIDs: [String]
    let title: String
    let reason: String
    let expectedBenefit: String
    let provenanceIDs: [String]
    let sourceRevision: String?
    let risk: String
    var occurrenceCount: Int
    var state:
        AgentDevelopmentSuggestionState
    var developerJobID: UUID? = nil
    var candidateBranch: String? = nil
    let createdAt: Date
    var updatedAt: Date

    var isExecutableCapabilityGap: Bool {
        source == .capabilityGap &&
        capabilityID != nil &&
        capabilityName != nil &&
        capabilityKind != nil &&
        AgentSourceRevisionPolicy
            .exactRevision(
                sourceRevision
            ) != nil
    }
}

struct AgentDevelopmentSuggestionStore {
    private let fileManager =
        FileManager.default

    private var directoryURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer",
                isDirectory: true
            )
    }

    var suggestionsURL: URL {
        directoryURL
            .appendingPathComponent(
                "development-suggestions.json",
                isDirectory: false
            )
    }

    func load()
        -> [AgentDevelopmentSuggestion] {
        guard
            let data = try? Data(
                contentsOf:
                    suggestionsURL
            )
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .iso8601

        return (
            try? decoder.decode(
                [AgentDevelopmentSuggestion].self,
                from: data
            )
        ) ?? []
    }

    func save(
        _ suggestions:
            [AgentDevelopmentSuggestion]
    ) {
        do {
            try fileManager
                .createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories:
                        true
                )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            encoder.dateEncodingStrategy =
                .iso8601

            try encoder
                .encode(suggestions)
                .write(
                    to: suggestionsURL,
                    options: .atomic
                )
        } catch {
            // Suggestion persistence must
            // never block the user task.
        }
    }

    func observeCapabilityGaps(
        _ gaps: [CapabilityGapResolution],
        sourceRevision: String?,
        provenancePrefix: String,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        for gap in gaps {
            let fingerprint =
                capabilityFingerprint(
                    gap
                )

            let now = Date()
            let provenanceID =
                provenancePrefix +
                ":" +
                compactIdentifier(
                    gap.capabilityID
                )

            if let index =
                suggestions.firstIndex(
                    where: {
                        $0.fingerprint ==
                            fingerprint
                    }
                ) {
                suggestions[index]
                    .occurrenceCount += 1
                suggestions[index]
                    .updatedAt = now

                // Suppression is sticky and
                // deferred suggestions never
                // become executable merely
                // because the gap reappears.
                continue
            }

            suggestions.append(
                AgentDevelopmentSuggestion(
                    id: UUID(),
                    fingerprint:
                        fingerprint,
                    source:
                        .capabilityGap,
                    capabilityID:
                        gap.capabilityID,
                    capabilityName:
                        gap.capabilityName,
                    capabilityKind:
                        gap.kind,
                    learningPath:
                        gap.learningPath,
                    candidateCapabilityIDs:
                        Array(
                            gap
                                .candidateCapabilityIDs
                                .prefix(8)
                        ),
                    title:
                        compactText(
                            gap.capabilityName,
                            limit: 90
                        ),
                    reason:
                        compactText(
                            gap.reason,
                            limit: 360
                        ),
                    expectedBenefit:
                        "KRALİ'nin " +
                        compactText(
                            gap.capabilityName,
                            limit: 90
                        ) +
                        " yeteneğini kontrollü bir candidate ile geliştirmek.",
                    provenanceIDs: [
                        provenanceID
                    ],
                    sourceRevision:
                        AgentSourceRevisionPolicy
                            .exactRevision(
                                sourceRevision
                            ),
                    risk:
                        riskLabel(
                            for: gap
                        ),
                    occurrenceCount: 1,
                    state: .proposed,
                    developerJobID: nil,
                    candidateBranch: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        save(suggestions)
        return suggestions
    }

    func observeArena(
        _ report: AgentArenaReport,
        sourceRevision: String?,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        guard
            report.failed > 0 ||
            report.reviewerFlagged > 0
        else {
            return existing
        }

        let failedIDs =
            report.results
                .filter {
                    !$0.passed ||
                    $0.reviewerPassed == false
                }
                .map(\.scenarioID)
                .sorted()

        let fingerprint =
            "arena|" +
            failedIDs
                .prefix(8)
                .joined(separator: ",")

        var suggestions = existing
        let now = Date()

        if let index =
            suggestions.firstIndex(
                where: {
                    $0.fingerprint ==
                        fingerprint
                }
            ) {
            suggestions[index]
                .occurrenceCount += 1
            suggestions[index]
                .updatedAt = now
            save(suggestions)
            return suggestions
        }

        suggestions.append(
            AgentDevelopmentSuggestion(
                id: UUID(),
                fingerprint:
                    fingerprint,
                source: .arena,
                capabilityID: nil,
                capabilityName: nil,
                capabilityKind: nil,
                learningPath: nil,
                candidateCapabilityIDs: [],
                title:
                    "Arena güvenilirlik önerisi",
                reason:
                    "Arena " +
                    String(report.failed) +
                    " başarısız ve " +
                    String(
                        report
                            .reviewerFlagged
                    ) +
                    " reviewer-flagged senaryo buldu.",
                expectedBenefit:
                    "Açık-dünya regression'larını kullanıcı onayından sonra kontrollü bir geliştirme göreviyle azaltmak.",
                provenanceIDs:
                    failedIDs
                        .prefix(8)
                        .map {
                            "arena:" + $0
                        },
                sourceRevision:
                    AgentSourceRevisionPolicy
                        .exactRevision(
                            sourceRevision
                        ),
                risk: "medium",
                occurrenceCount: 1,
                state: .proposed,
                createdAt: now,
                updatedAt: now
            )
        )

        save(suggestions)
        return suggestions
    }

    func transition(
        _ id: UUID,
        to state:
            AgentDevelopmentSuggestionState,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return suggestions
        }

        suggestions[index].state =
            state
        suggestions[index].updatedAt =
            Date()
        save(suggestions)
        return suggestions
    }

    func linkDevelopmentJob(
        suggestionID: UUID,
        jobID: UUID,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.id ==
                            suggestionID
                    }
                )
        else {
            return suggestions
        }

        suggestions[index]
            .developerJobID = jobID
        suggestions[index]
            .updatedAt = Date()
        save(suggestions)
        return suggestions
    }

    func updateDevelopmentState(
        jobID: UUID,
        state:
            AgentDevelopmentSuggestionState,
        candidateBranch: String? = nil,
        in existing:
            [AgentDevelopmentSuggestion]
    ) -> [AgentDevelopmentSuggestion] {
        var suggestions = existing

        guard
            let index =
                suggestions.firstIndex(
                    where: {
                        $0.developerJobID ==
                            jobID
                    }
                )
        else {
            return suggestions
        }

        suggestions[index].state =
            state

        if let candidateBranch {
            suggestions[index]
                .candidateBranch =
                    candidateBranch
        }

        suggestions[index]
            .updatedAt = Date()
        save(suggestions)
        return suggestions
    }

    func approvedGap(
        from suggestion:
            AgentDevelopmentSuggestion
    ) -> CapabilityGapResolution? {
        guard
            suggestion
                .isExecutableCapabilityGap,
            let capabilityID =
                suggestion.capabilityID,
            let capabilityName =
                suggestion.capabilityName,
            let kind =
                suggestion.capabilityKind
        else {
            return nil
        }

        return CapabilityGapResolution(
            capabilityID:
                capabilityID,
            capabilityName:
                capabilityName,
            kind:
                kind,
            reason:
                suggestion.reason,
            candidateCapabilityIDs:
                suggestion
                    .candidateCapabilityIDs,
            researchGoal:
                "Research the minimum safe implementation for the user-approved capability proposal: " +
                capabilityName,
            developerBrief:
                "Implement the minimum bounded candidate for capability " +
                capabilityID +
                ". Preserve existing approval/security boundaries and verify the change deterministically.",
            learningPath:
                suggestion.learningPath
        )
    }

    private func capabilityFingerprint(
        _ gap: CapabilityGapResolution
    ) -> String {
        [
            "capability-gap",
            compactIdentifier(
                gap.capabilityID
            ),
            gap.kind.rawValue
        ]
        .joined(separator: "|")
    }

    private func riskLabel(
        for gap: CapabilityGapResolution
    ) -> String {
        switch gap.kind {
        case .knowledge,
             .strategy:
            return "low"
        case .code:
            return "medium"
        case .integration:
            return "medium"
        }
    }

    private func compactText(
        _ value: String,
        limit: Int
    ) -> String {
        let clean =
            value
                .replacingOccurrences(
                    of: "\n",
                    with: " "
                )
                .split(
                    whereSeparator: {
                        $0.isWhitespace
                    }
                )
                .joined(separator: " ")

        return String(
            clean.prefix(limit)
        )
    }

    private func compactIdentifier(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "tr_TR"
                    )
            )
            .lowercased()
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )
            .filter {
                !$0.isEmpty
            }
            .prefix(6)
            .joined(separator: "-")
    }
}
