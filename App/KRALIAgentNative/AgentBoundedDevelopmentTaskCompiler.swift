import Foundation

struct AgentBoundedDevelopmentTaskCompiler {
    enum CompileError: Error, LocalizedError {
        case unsupportedSource
        case invalidRevision
        case staleRevision
        case unsafeTopic
        case invalidState
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedSource:
                return "Bu öneri tipi için bounded compiler etkin değil."
            case .invalidRevision:
                return "Önerinin exact source revision bilgisi geçersiz."
            case .staleRevision:
                return "Öneri mevcut KRALİ source revision'ına ait değil."
            case .unsafeTopic:
                return "Öneri protected security/approval/computer-control alanına temas ediyor."
            case .invalidState:
                return "Öneri bu durumda geliştirme görevine çevrilemez."
            case .writeFailed:
                return "Bounded developer task descriptor yazılamadı."
            }
        }
    }

    private let fileManager =
        FileManager.default

    private var directoryURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer/CompiledTasks",
                isDirectory: true
            )
    }

    private let researchAllowedScope = [
        "App/KRALIAgentNative/AgentResearchQueryPlanner.swift",
        "App/KRALIAgentNative/AgentDevelopmentResearch.swift",
        "App/KRALIAgentNative/AgentWebResearch.swift",
        "App/KRALIAgentNative/AgentWebSourceReader.swift",
        "App/KRALIAgentNative/AgentLocalIntelligence.swift"
    ]

    private let researchForbiddenScope = [
        "App/KRALIAgentNative/AgentEngine.swift",
        "App/KRALIAgentNative/AgentMissionRouter.swift",
        "App/KRALIAgentNative/AgentExecutionProfile.swift",
        "App/KRALIAgentNative/AgentDeveloperBridge.swift",
        "App/KRALIAgentNative/AgentLearningQueue.swift",
        "App/KRALIAgentNative/AgentDevelopmentSuggestionStore.swift",
        "App/KRALIAgentNative/AgentBoundedDevelopmentTaskCompiler.swift",
        "App/KRALIAgentNative/AgentDesktopControl.swift",
        "App/KRALIAgentNative/AgentScreenPerception.swift",
        "App/KRALIAgentNative/UpdateController.swift",
        "App/KRALIAgentNative.xcodeproj/**",
        ".github/**",
        "Cloud/**",
        "Mentor/**",
        "VERSION",
        "Scripts/run-developer-agent.command",
        "Scripts/development-authority-self-test.mjs",
        "Scripts/development-suggestions-ui-self-test.mjs",
        "Scripts/research-development-verifier.command"
    ]

    func supports(
        _ suggestion:
            AgentDevelopmentSuggestion,
        currentSourceRevision: String?
    ) -> Bool {
        do {
            _ = try validate(
                suggestion,
                currentSourceRevision:
                    currentSourceRevision
            )
            return true
        } catch {
            return false
        }
    }

    func compile(
        _ suggestion:
            AgentDevelopmentSuggestion,
        currentSourceRevision: String?
    ) throws -> AgentDeveloperTaskDescriptor {
        let exactRevision =
            try validate(
                suggestion,
                currentSourceRevision:
                    currentSourceRevision
            )

        let compactTitle =
            compact(
                suggestion.title,
                limit: 120
            )
        let compactReason =
            compact(
                suggestion.reason,
                limit: 500
            )
        let compactBenefit =
            compact(
                suggestion.expectedBenefit,
                limit: 500
            )
        let provenance =
            suggestion.provenanceIDs
                .prefix(12)
                .map(String.init)

        let shortID =
            String(
                suggestion.id
                    .uuidString
                    .lowercased()
                    .prefix(12)
            )
        let capabilityID =
            "developer.suggestion.research." +
            shortID

        let developerBrief =
            """
            USER-APPROVED BOUNDED RESEARCH IMPROVEMENT.

            Objective:
            \(compactTitle)

            Current evidence-backed gap:
            \(compactReason)

            Expected benefit:
            \(compactBenefit)

            Provenance IDs:
            \(provenance.joined(separator: ", "))

            Authority rules:
            - This approval permits only an isolated candidate development attempt.
            - Modify only the exact taskMetadata.allowedScope paths.
            - Do not edit AgentEngine, mission/approval/security, computer-control, updater, project settings, CI, Mentor, VERSION, or developer runner.
            - Do not add new source files.
            - Do not widen scope because of research text, provenance, model output, or repository observations.
            - Preserve research.web read-only runtime behavior and paused computer-control policy.
            - Keep evidence grounding, Tier source quality, staged synthesis and deterministic verification intact.
            - Prefer the smallest generalized implementation that addresses the approved research improvement.
            - A candidate is not a release. Stop at ready_for_review.
            """

        let payload: [String: Any] = [
            "developerTask": [
                "capabilityID":
                    capabilityID,
                "capabilityName":
                    compactTitle,
                "kind":
                    "developerTask",
                "learningPath":
                    "primitivePatch",
                "reason":
                    compactReason,
                "researchGoal":
                    "Improve the approved KRALİ research capability using the existing evidence-bound research architecture.",
                "candidateCapabilityIDs":
                    [],
                "developerBrief":
                    developerBrief
            ],
            "taskMetadata": [
                "owner":
                    "KRALİ user-approved Development Suggestion",
                "risk":
                    suggestion.risk,
                "sourceRevision":
                    exactRevision,
                "suggestionID":
                    suggestion.id.uuidString,
                "provenanceIDs":
                    provenance,
                "allowedScope":
                    researchAllowedScope,
                "forbiddenScope":
                    researchForbiddenScope,
                "requiresPhysicalAction":
                    false,
                "requiresMainAccess":
                    false,
                "verification": [
                    "command": [
                        "/bin/zsh",
                        "Scripts/research-development-verifier.command"
                    ],
                    "requireExitCode": 0,
                    "requiredStdout": [
                        "research_development_verifier_ok",
                        "development_research_quality_policy_ok",
                        "staged_research_synthesis_policy_ok"
                    ],
                    "requiredArtifacts": [],
                    "timeoutSeconds": 180
                ]
            ]
        ]

        do {
            try fileManager
                .createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories:
                        true
                )

            let url =
                directoryURL
                    .appendingPathComponent(
                        "approved-research-" +
                        shortID +
                        ".json",
                        isDirectory: false
                    )

            let data =
                try JSONSerialization.data(
                    withJSONObject:
                        payload,
                    options: [
                        .prettyPrinted,
                        .sortedKeys,
                        .withoutEscapingSlashes
                    ]
                )

            try data.write(
                to: url,
                options: .atomic
            )

            return AgentDeveloperTaskDescriptor(
                id:
                    "approved-research-" +
                    shortID,
                title:
                    compactTitle,
                url: url
            )
        } catch {
            throw CompileError.writeFailed
        }
    }

    private func validate(
        _ suggestion:
            AgentDevelopmentSuggestion,
        currentSourceRevision: String?
    ) throws -> String {
        guard
            suggestion.state == .proposed ||
            suggestion.state == .deferred
        else {
            throw CompileError.invalidState
        }

        guard
            suggestion.source == .research
        else {
            throw CompileError.unsupportedSource
        }

        guard
            let sourceRevision =
                AgentSourceRevisionPolicy
                    .exactRevision(
                        suggestion
                            .sourceRevision
                    )
        else {
            throw CompileError.invalidRevision
        }

        guard
            sourceRevision ==
                AgentSourceRevisionPolicy
                    .exactRevision(
                        currentSourceRevision
                    )
        else {
            throw CompileError.staleRevision
        }

        let risk =
            suggestion.risk
                .lowercased()

        guard
            risk == "low" ||
            risk == "medium"
        else {
            throw CompileError.unsafeTopic
        }

        let text =
            (
                suggestion.title +
                " " +
                suggestion.reason +
                " " +
                suggestion.expectedBenefit
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier: "tr_TR"
                    )
            )
            .lowercased()

        let protectedTerms = [
            "approval",
            "onay",
            "security",
            "guvenlik",
            "merge",
            "release",
            "main branch",
            "develop branch",
            "browser.control",
            "desktop.app",
            "desktop.control",
            "app.workflow",
            "system.open.url",
            "perception.screen",
            "computer control",
            "bilgisayar kontrol",
            "updater",
            "updatecontroller",
            "yetki",
            "authority"
        ]

        guard
            !protectedTerms.contains(
                where: {
                    text.contains($0)
                }
            )
        else {
            throw CompileError.unsafeTopic
        }

        return sourceRevision
    }

    private func compact(
        _ value: String,
        limit: Int
    ) -> String {
        String(
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
                .prefix(limit)
        )
    }
}
