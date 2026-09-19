import Foundation

struct MentorTraceCapability: Codable {
    let id: String
    let name: String
    let available: Bool
    let risk: String
}

struct MentorTraceLearningPlan: Codable {
    let capabilityID: String
    let capabilityName: String
    let state: String
    let researchGoal: String
    let nextStep: String
}

struct MentorTraceStep: Codable {
    let title: String
    let detail: String
    let kind: String
    let capabilityID: String?
    let state: String
}

struct MentorTraceResearchSource: Codable {
    let title: String
    let url: String
    let domain: String
    let snippet: String?
}

struct MentorTraceEvidence: Codable {
    let title: String
    let url: String
    let domain: String
    let excerpt: String
    let conceptCoverage: Int
    let matchedConcepts: [String]
}

struct MentorTraceActivity: Codable {
    let text: String
    let date: Date
}

struct MentorTrace: Codable {
    let traceID: String
    let createdAt: Date
    let appVersion: String
    let inputSource: String
    let userInput: String
    let goal: String
    let plan: String
    let route: [String]
    let capabilities: [MentorTraceCapability]
    let learningPlans: [MentorTraceLearningPlan]
    let executionSteps: [MentorTraceStep]
    let verificationState: String
    let verificationSummary: String
    let fallbackPlan: String?
    let finalResponse: String
    let researchSources: [MentorTraceResearchSource]
    let researchEvidence: [MentorTraceEvidence]
    let activityTail: [MentorTraceActivity]
}

struct MentorTraceStore {
    private let fileManager = FileManager.default

    var rootDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Mentor",
                isDirectory: true
            )
    }

    var latestURL: URL {
        rootDirectory.appendingPathComponent(
            "latest.json",
            isDirectory: false
        )
    }

    func save(
        input: String,
        inputSource: ChatInputSource,
        goal: String,
        plan: String,
        route: [String],
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        executionSteps: [AgentExecutionStep],
        verification: AgentVerificationResult,
        fallbackPlan: String?,
        finalResponse: String,
        researchSources: [WebResearchResult],
        researchEvidence: [WebSourceEvidence],
        activities: [ActivityItem]
    ) throws -> URL {
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let historyDirectory = rootDirectory
            .appendingPathComponent(
                "History",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: historyDirectory,
            withIntermediateDirectories: true
        )

        let trace = MentorTrace(
            traceID: UUID().uuidString,
            createdAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            inputSource: inputSourceName(inputSource),
            userInput: input,
            goal: goal,
            plan: plan,
            route: route,
            capabilities: capabilities.map {
                MentorTraceCapability(
                    id: $0.id,
                    name: $0.name,
                    available: $0.isAvailable,
                    risk: $0.risk.rawValue
                )
            },
            learningPlans: learningPlans.map {
                MentorTraceLearningPlan(
                    capabilityID: $0.capabilityID,
                    capabilityName: $0.capabilityName,
                    state: $0.state.rawValue,
                    researchGoal: $0.researchGoal,
                    nextStep: $0.nextStep
                )
            },
            executionSteps: executionSteps.map {
                MentorTraceStep(
                    title: $0.title,
                    detail: $0.detail,
                    kind: $0.kind.rawValue,
                    capabilityID: $0.capabilityID,
                    state: $0.state.rawValue
                )
            },
            verificationState: verification.state.rawValue,
            verificationSummary: verification.summary,
            fallbackPlan: fallbackPlan,
            finalResponse: finalResponse,
            researchSources: researchSources.map {
                MentorTraceResearchSource(
                    title: $0.title,
                    url: $0.url.absoluteString,
                    domain: $0.domain,
                    snippet: $0.snippet
                )
            },
            researchEvidence: researchEvidence.map {
                MentorTraceEvidence(
                    title: $0.source.title,
                    url: $0.source.url.absoluteString,
                    domain: $0.source.domain,
                    excerpt: String($0.excerpt.prefix(1400)),
                    conceptCoverage: $0.conceptCoverage,
                    matchedConcepts: $0.matchedConcepts
                )
            },
            activityTail: activities.suffix(30).map {
                MentorTraceActivity(
                    text: $0.text,
                    date: $0.date
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(trace)
        try data.write(
            to: latestURL,
            options: .atomic
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let historyURL = historyDirectory
            .appendingPathComponent(
                formatter.string(from: trace.createdAt) +
                "-" +
                trace.traceID.prefix(8) +
                ".json"
            )

        try data.write(
            to: historyURL,
            options: .atomic
        )

        pruneHistory(
            directory: historyDirectory,
            keeping: 30
        )

        return latestURL
    }

    private func inputSourceName(
        _ source: ChatInputSource
    ) -> String {
        switch source {
        case .text: return "text"
        case .voice: return "voice"
        }
    }

    private func pruneHistory(
        directory: URL,
        keeping limit: Int
    ) {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            ),
            files.count > limit
        else {
            return
        }

        let sorted = files.sorted { left, right in
            let leftDate = (
                try? left.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate
            ) ?? .distantPast

            let rightDate = (
                try? right.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate
            ) ?? .distantPast

            return leftDate > rightDate
        }

        for url in sorted.dropFirst(limit) {
            try? fileManager.removeItem(at: url)
        }
    }
}
