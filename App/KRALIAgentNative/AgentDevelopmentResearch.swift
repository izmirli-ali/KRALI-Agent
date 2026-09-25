import Foundation

enum AgentResearchSourceTier: String, Codable, Hashable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var rank: Int {
        switch self {
        case .a: return 4
        case .b: return 3
        case .c: return 2
        case .d: return 1
        }
    }
}

enum AgentResearchSourceKind: String, Codable, Hashable {
    case paper
    case officialDocumentation = "official_documentation"
    case originalRepository = "original_repository"
    case organizationEngineering = "organization_engineering"
    case technicalPublication = "technical_publication"
    case secondarySummary = "secondary_summary"
    case generic
}

enum AgentDevelopmentResearchDecision: String, Codable, Hashable, CaseIterable {
    case discard = "DISCARD"
    case improve = "IMPROVE"
    case merge = "MERGE"
    case create = "CREATE"
}

struct AgentDevelopmentResearchFacet: Codable, Hashable {
    let id: String
    let label: String
    let topics: [String]
    let required: Bool
    let preferredSourceKinds: [AgentResearchSourceKind]
    let queries: [String]
}

struct AgentDevelopmentResearchPlan: Codable, Hashable {
    let facets: [AgentDevelopmentResearchFacet]
    let requiredApproachCount: Int
    let minimumQualifyingSourceCount: Int
    let minimumHighQualitySourceCount: Int
    let minimumIndependentOriginCount: Int
    let minimumPreferredSourceKindCount: Int
    let requiresRepositoryComparison: Bool
}

struct AgentDevelopmentResearchSourceAssessment: Codable, Hashable {
    let facetID: String
    let sourceURL: String
    let sourceTitle: String
    let domain: String
    let origin: String
    let kind: AgentResearchSourceKind
    let tier: AgentResearchSourceTier
    let relevance: Double
    let qualityScore: Int
    let qualifiesForTechnicalCoverage: Bool
    let publishedAt: Date?
    let freshnessScore: Int?

    init(
        facetID: String,
        sourceURL: String,
        sourceTitle: String,
        domain: String,
        origin: String,
        kind: AgentResearchSourceKind,
        tier: AgentResearchSourceTier,
        relevance: Double,
        qualityScore: Int,
        qualifiesForTechnicalCoverage: Bool,
        publishedAt: Date? = nil,
        freshnessScore: Int? = nil
    ) {
        self.facetID = facetID
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.domain = domain
        self.origin = origin
        self.kind = kind
        self.tier = tier
        self.relevance = relevance
        self.qualityScore = qualityScore
        self.qualifiesForTechnicalCoverage = qualifiesForTechnicalCoverage
        self.publishedAt = publishedAt
        self.freshnessScore = freshnessScore
    }
}

struct AgentDevelopmentResearchEvidenceRecord: Codable, Hashable {
    let id: String
    let facetID: String
    let sourceURL: String
    let sourceTitle: String
    let domain: String
    let kind: AgentResearchSourceKind
    let tier: AgentResearchSourceTier
    let excerpt: String
    let publishedAt: Date?

    init(
        id: String,
        facetID: String,
        sourceURL: String,
        sourceTitle: String,
        domain: String,
        kind: AgentResearchSourceKind,
        tier: AgentResearchSourceTier,
        excerpt: String,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.facetID = facetID
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.domain = domain
        self.kind = kind
        self.tier = tier
        self.excerpt = excerpt
        self.publishedAt = publishedAt
    }
}

struct AgentDevelopmentResearchEvidenceAudit: Hashable {
    let datedSourceCount: Int
    let recentSourceCount: Int
    let unknownDateCount: Int
    let potentialContradictionCount: Int

    static func analyze(
        sources: [AgentDevelopmentResearchSourceAssessment],
        evidence: [AgentDevelopmentResearchEvidenceRecord]
    ) -> Self {
        let dated = sources.filter { $0.publishedAt != nil }
        let recent = dated.filter { ($0.freshnessScore ?? 0) >= 70 }
        var contradictions = 0

        for leftIndex in evidence.indices {
            for rightIndex in evidence.indices where rightIndex > leftIndex {
                let left = normalized(evidence[leftIndex].excerpt)
                let right = normalized(evidence[rightIndex].excerpt)
                guard sharedMaterialToken(left, right) else { continue }
                if polarity(left) != 0,
                   polarity(right) != 0,
                   polarity(left) != polarity(right) {
                    contradictions += 1
                }
            }
        }

        return Self(
            datedSourceCount: dated.count,
            recentSourceCount: recent.count,
            unknownDateCount: max(0, sources.count - dated.count),
            potentialContradictionCount: contradictions
        )
    }

    private static func polarity(_ value: String) -> Int {
        let negative = [" not ", " no ", "cannot", "fails", "worse", "risk", "degil", "yetersiz", "basarisiz"]
        let positive = ["improves", "supports", "effective", "better", "passes", "iyilestir", "basarili", "destekler"]
        let negativeCount = negative.filter { value.contains($0) }.count
        let positiveCount = positive.filter { value.contains($0) }.count
        return positiveCount == negativeCount ? 0 : (positiveCount > negativeCount ? 1 : -1)
    }

    private static func sharedMaterialToken(_ left: String, _ right: String) -> Bool {
        let stop = Set(["agent", "research", "source", "evidence", "system", "with", "from", "that", "this"])
        let leftTokens = Set(left.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 6 && !stop.contains($0) })
        let rightTokens = Set(right.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 6 && !stop.contains($0) })
        return !leftTokens.intersection(rightTokens).isEmpty
    }

    private static func normalized(_ value: String) -> String {
        " " + value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")).lowercased() + " "
    }
}

struct AgentDevelopmentResearchApproach: Codable, Hashable {
    let title: String
    let decision: AgentDevelopmentResearchDecision
    let summary: String
    let evidenceIDs: [String]
    let repositoryEvidenceIDs: [String]
    let benefits: [String]
    let risks: [String]
}

struct AgentDevelopmentResearchProposal: Codable, Hashable {
    let problem: String
    let currentArchitecture: String
    let researchFindings: [String]
    let evidenceIDs: [String]
    let repositoryEvidenceIDs: [String]
    let gap: String
    let alternatives: [String]
    let selectedStrategy: String
    let whyThisStrategy: String
    let expectedBehavior: String
    let allowedScope: [String]
    let likelyFiles: [String]
    let risks: [String]
    let securityBoundaries: [String]
    let verificationContract: [String]
    let behavioralBenchmark: [String]
    let rollbackCondition: String
}

struct AgentDevelopmentResearchSynthesis: Codable, Hashable {
    let currentArchitecture: [String]
    let approaches: [AgentDevelopmentResearchApproach]
    let biggestGap: String
    let selectedImprovement: String
    let proposal: AgentDevelopmentResearchProposal
    let risks: [String]
    let verificationPlan: [String]
    let mutationRecommended: Bool
    let mutationStarted: Bool
    let remainingLimitations: [String]

    func formattedFinalReport(
        sources: [AgentDevelopmentResearchSourceAssessment],
        evidence: [AgentDevelopmentResearchEvidenceRecord]
    ) -> String {
        let uniqueSources = Dictionary(
            sources.map { ($0.sourceURL, $0) },
            uniquingKeysWith: { left, right in
                left.qualityScore >= right.qualityScore ? left : right
            }
        )
        .values
        .sorted {
            if $0.tier.rank == $1.tier.rank {
                return $0.qualityScore > $1.qualityScore
            }
            return $0.tier.rank > $1.tier.rank
        }

        let sourceText = uniqueSources
            .prefix(12)
            .enumerated()
            .map {
                "\($0.offset + 1). [Tier \($0.element.tier.rawValue)] \($0.element.sourceTitle) — \($0.element.domain) — \($0.element.sourceURL)"
            }
            .joined(separator: "\n")

        let independentOrigins = Set(uniqueSources.map(\.origin))
        let sourceKinds = Dictionary(
            grouping: uniqueSources,
            by: \.kind
        )
        let scorecard =
            "Sources: \(uniqueSources.count) • Independent origins: \(independentOrigins.count) • Preferred source kinds: \(sourceKinds.keys.count) • Tier A/B: \(uniqueSources.filter { $0.tier == .a || $0.tier == .b }.count) • Dated: \(uniqueSources.filter { $0.publishedAt != nil }.count) • Freshness: \(freshnessAverage(uniqueSources))/100"
        let audit = AgentDevelopmentResearchEvidenceAudit.analyze(
            sources: Array(uniqueSources),
            evidence: evidence
        )

        let approachText = approaches.enumerated().map { index, item in
            """
            \(index + 1). \(item.title) — \(item.decision.rawValue)
            \(item.summary)
            External evidence: \(item.evidenceIDs.joined(separator: ", "))
            Repository evidence: \(item.repositoryEvidenceIDs.joined(separator: ", "))
            Benefits: \(item.benefits.joined(separator: " • "))
            Risks: \(item.risks.joined(separator: " • "))
            """
        }
        .joined(separator: "\n\n")

        let architectureText = currentArchitecture
            .map { "• " + $0 }
            .joined(separator: "\n")

        let findings = proposal.researchFindings
            .map { "• " + $0 }
            .joined(separator: "\n")

        func bullets(_ values: [String]) -> String {
            values.isEmpty
                ? "• Yok"
                : values.map { "• " + $0 }.joined(separator: "\n")
        }

        return """
        A. Current KRALİ Architecture
        \(architectureText)

        B. Research Sources
        \(sourceText)
        Quality Scorecard: \(scorecard)
        Evidence Audit: Recent sources: \(audit.recentSourceCount) • Unknown dates: \(audit.unknownDateCount) • Potential contradictions requiring review: \(audit.potentialContradictionCount)

        C. External Approaches Found
        \(approachText)

        D. KRALİ Comparison
        Her yaklaşım external evidence IDs ile repository evidence IDs üzerinden karşılaştırıldı.

        E. DISCARD / IMPROVE / MERGE / CREATE Decisions
        \(approaches.map { "• \($0.decision.rawValue): \($0.title)" }.joined(separator: "\n"))

        F. Biggest Current Gap
        \(biggestGap)

        G. Selected Improvement
        \(selectedImprovement)

        H. Development Proposal
        Problem: \(proposal.problem)
        Current Architecture: \(proposal.currentArchitecture)
        Research Findings:
        \(findings)
        Evidence: \(proposal.evidenceIDs.joined(separator: ", "))
        Repository Evidence: \(proposal.repositoryEvidenceIDs.joined(separator: ", "))
        Gap: \(proposal.gap)
        Alternatives: \(proposal.alternatives.joined(separator: " • "))
        Selected Strategy: \(proposal.selectedStrategy)
        Why This Strategy: \(proposal.whyThisStrategy)
        Expected Behavior: \(proposal.expectedBehavior)
        Allowed Scope:
        \(bullets(proposal.allowedScope))
        Files / Components Likely Affected:
        \(bullets(proposal.likelyFiles))
        Risks:
        \(bullets(proposal.risks))
        Security Boundaries:
        \(bullets(proposal.securityBoundaries))
        Verification Contract:
        \(bullets(proposal.verificationContract))
        Behavioral Benchmark:
        \(bullets(proposal.behavioralBenchmark))
        Rollback Condition: \(proposal.rollbackCondition)

        I. Evidence & Provenance
        Material approaches and the selected proposal carry explicit external and repository evidence IDs.

        J. Risks & Security Boundaries
        \(bullets(risks))

        K. Verification Plan
        \(bullets(verificationPlan))

        L. Mutation Recommended
        Mutation Recommended: \(mutationRecommended ? "YES" : "NO")

        M. Mutation Started
        Mutation Started: \(mutationStarted ? "YES" : "NO")

        N. Recommended Next Step
        \(remainingLimitations.isEmpty ? "Human review of the selected proposal before any bounded Developer Agent task." : remainingLimitations.joined(separator: " • "))
        """
    }

    private func freshnessAverage(
        _ sources: [AgentDevelopmentResearchSourceAssessment]
    ) -> Int {
        let dated = sources.filter { $0.publishedAt != nil }
        guard !dated.isEmpty else { return 0 }
        return dated.map { $0.freshnessScore ?? 0 }.reduce(0, +) / dated.count
    }
}

enum AgentDevelopmentResearchVerificationState: String, Codable, Hashable {
    case passed
    case partial
    case attention
}

struct AgentDevelopmentResearchVerificationOutcome: Codable, Hashable {
    let state: AgentDevelopmentResearchVerificationState
    let summary: String
    let fallback: String?
}

struct AgentDevelopmentResearchSourceClassifier {
    func assess(
        _ result: WebResearchResult,
        facet: AgentDevelopmentResearchFacet
    ) -> AgentDevelopmentResearchSourceAssessment {
        let domain = normalize(result.domain)
        let combined = normalize(
            result.title + " " +
            (result.snippet ?? "") + " " +
            result.domain
        )

        let tokens = relevanceTokens(
            facet.label + " " +
            facet.topics.joined(separator: " ")
        )
        let matched = tokens.filter {
            combined.contains($0)
        }
        let relevance = tokens.isEmpty
            ? 0
            : min(
                1,
                Double(matched.count) /
                Double(max(1, min(tokens.count, 8)))
            )

        let kind: AgentResearchSourceKind
        var tier: AgentResearchSourceTier

        if isPaperHost(domain) {
            kind = .paper
            tier = .a
        } else if domain == "github.com" ||
                    domain.hasSuffix(".github.com") {
            if isOriginalGitHubRepository(
                result.url
            ) {
                kind = .originalRepository
                tier = .a
            } else {
                kind = .secondarySummary
                tier = .c
            }
        } else if isOfficialDocumentationHost(domain) {
            kind = .officialDocumentation
            tier = .a
        } else if isOrganizationEngineeringHost(domain) {
            kind = .organizationEngineering
            tier = .b
        } else if domain.hasSuffix("wikipedia.org") {
            kind = .secondarySummary
            tier = .c
        } else if isSecondaryHost(domain) {
            kind = .secondarySummary
            tier = .c
        } else {
            kind = .generic
            tier = .c
        }

        if relevance < 0.18 {
            tier = .d
        } else if relevance < 0.30 &&
                    tier == .a {
            tier = .c
        }

        if requiresAgentContext(
            facet
        ) &&
           !hasAgentContext(
               combined
           ) {
            tier = .d
        }

        let baseScore: Int
        switch tier {
        case .a: baseScore = 100
        case .b: baseScore = 75
        case .c: baseScore = 45
        case .d: baseScore = 10
        }

        let freshnessScore = freshnessScore(for: result.publishedAt)
        let qualityScore =
            baseScore +
            Int((relevance * 25).rounded()) +
            (result.publishedAt == nil ? 0 : (freshnessScore - 50) / 5)

        let origin = canonicalOrigin(domain)

        return AgentDevelopmentResearchSourceAssessment(
            facetID: facet.id,
            sourceURL: result.url.absoluteString,
            sourceTitle: result.title,
            domain: result.domain,
            origin: origin,
            kind: kind,
            tier: tier,
            relevance: relevance,
            qualityScore: qualityScore,
            qualifiesForTechnicalCoverage:
                (tier == .a || tier == .b) &&
                relevance >= 0.30,
            publishedAt: result.publishedAt,
            freshnessScore: freshnessScore
        )
    }

    private func freshnessScore(for date: Date?) -> Int {
        guard let date else { return 0 }
        let years = max(0, Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0)
        switch years {
        case 0...1: return 100
        case 2...3: return 85
        case 4...5: return 70
        case 6...8: return 50
        default: return 30
        }
    }

    private func isOriginalGitHubRepository(
        _ url: URL
    ) -> Bool {
        let parts =
            url.pathComponents
                .filter {
                    $0 != "/"
                }

        guard parts.count >= 2 else {
            return false
        }

        let reserved = Set([
            "topics",
            "search",
            "collections",
            "marketplace",
            "orgs",
            "settings",
            "features"
        ])

        return !reserved.contains(
            parts[0].lowercased()
        )
    }

    private func requiresAgentContext(
        _ facet: AgentDevelopmentResearchFacet
    ) -> Bool {
        let text =
            normalize(
                facet.label + " " +
                facet.topics
                    .joined(separator: " ")
            )

        let ambiguousTechnicalTerms = [
            "tool",
            "memory",
            "reflection",
            "replay",
            "skill",
            "evaluation",
            "debug",
            "decomposition",
            "self-modification",
            "self improving",
            "self-improving"
        ]

        return ambiguousTechnicalTerms.contains {
            text.contains($0)
        }
    }

    private func hasAgentContext(
        _ combined: String
    ) -> Bool {
        let anchors = [
            "agent",
            "agentic",
            "llm",
            "large language model",
            "language model",
            "autonomous ai",
            "artificial intelligence",
            "multi-agent",
            "multi agent"
        ]

        return anchors.contains {
            combined.contains($0)
        }
    }

    private func isPaperHost(
        _ domain: String
    ) -> Bool {
        [
            "arxiv.org",
            "openreview.net",
            "aclanthology.org",
            "proceedings.neurips.cc",
            "dl.acm.org",
            "ieeexplore.ieee.org",
            "papers.nips.cc"
        ]
        .contains {
            domain == $0 ||
            domain.hasSuffix("." + $0)
        }
    }

    private func isOfficialDocumentationHost(
        _ domain: String
    ) -> Bool {
        domain.hasPrefix("docs.") ||
        domain.contains(".docs.") ||
        domain.hasPrefix("developer.") ||
        [
            "docs.github.com",
            "platform.openai.com",
            "developer.apple.com",
            "developer.adobe.com",
            "learn.microsoft.com"
        ]
        .contains {
            domain == $0 ||
            domain.hasSuffix("." + $0)
        }
    }

    private func isOrganizationEngineeringHost(
        _ domain: String
    ) -> Bool {
        [
            "openai.com",
            "anthropic.com",
            "deepmind.google",
            "research.google",
            "microsoft.com",
            "huggingface.co",
            "ai.meta.com"
        ]
        .contains {
            domain == $0 ||
            domain.hasSuffix("." + $0)
        }
    }

    private func isSecondaryHost(
        _ domain: String
    ) -> Bool {
        [
            "medium.com",
            "substack.com",
            "dev.to"
        ]
        .contains {
            domain == $0 ||
            domain.hasSuffix("." + $0)
        }
    }

    private func relevanceTokens(
        _ value: String
    ) -> [String] {
        let stop = Set([
            "agent", "agents", "artificial", "intelligence",
            "research", "approach", "system", "systems",
            "with", "from", "into", "using", "learning",
            "self", "ai"
        ])

        var seen = Set<String>()
        return normalize(value)
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )
            .filter {
                $0.count >= 4 &&
                !stop.contains($0) &&
                seen.insert($0).inserted
            }
    }

    private func canonicalOrigin(
        _ domain: String
    ) -> String {
        let parts = domain
            .split(separator: ".")
            .map(String.init)

        guard parts.count >= 2 else {
            return domain
        }

        return parts
            .suffix(2)
            .joined(separator: ".")
    }

    private func normalize(
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
                        identifier: "tr_TR"
                    )
            )
            .lowercased()
    }
}

struct AgentDevelopmentResearchVerifier {
    func verify(
        plan: AgentDevelopmentResearchPlan,
        sources: [AgentDevelopmentResearchSourceAssessment],
        evidence: [AgentDevelopmentResearchEvidenceRecord],
        repositoryEvidenceIDs: Set<String>,
        synthesis: AgentDevelopmentResearchSynthesis?,
        executedCapabilityIDs: Set<String>
    ) -> AgentDevelopmentResearchVerificationOutcome {
        let prohibited =
            AgentExecutionProfile
                .computerControlCapabilityIDs

        let executedProhibited =
            executedCapabilityIDs
                .intersection(prohibited)

        if !executedProhibited.isEmpty {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .attention,
                summary:
                    "Self-development research executed paused computer-control capabilities: " +
                    executedProhibited.sorted().joined(separator: ", "),
                fallback:
                    "Retry with research.web + read-only repository evidence only."
            )
        }

        guard let synthesis else {
            return AgentDevelopmentResearchVerificationOutcome(
                state:
                    evidence.isEmpty
                    ? .attention
                    : .partial,
                summary:
                    evidence.isEmpty
                    ? "No qualifying page-derived research evidence was produced."
                    : "Research evidence exists, but structured comparison/proposal synthesis is missing.",
                fallback:
                    "Retain the evidence and retry bounded structured synthesis without mutation."
            )
        }

        if synthesis.mutationStarted {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .attention,
                summary:
                    "Research phase violated the mutation-off invariant.",
                fallback:
                    "Stop immediately and require human review before any Developer Agent task."
            )
        }

        let sourceByURL =
            Dictionary(
                sources.map { ($0.sourceURL, $0) },
                uniquingKeysWith: { left, right in
                    left.qualityScore >= right.qualityScore
                    ? left
                    : right
                }
            )

        let qualifying =
            Array(
                sourceByURL.values.filter {
                    $0.qualifiesForTechnicalCoverage
                }
            )

        let highQuality =
            qualifying.filter {
                $0.tier == .a ||
                $0.tier == .b
            }

        let datedHighQuality = highQuality.filter { $0.publishedAt != nil }
        let recentHighQuality = datedHighQuality.filter { ($0.freshnessScore ?? 0) >= 70 }

        let origins: Set<String> =
            Set(
                highQuality.map(\.origin)
            )

        let preferredKinds = Set(
            plan.facets.flatMap(\.preferredSourceKinds)
        )
        let coveredPreferredKinds = Set(
            highQuality
                .map(\.kind)
                .filter { preferredKinds.contains($0) }
        )

        let evidenceByID =
            Dictionary(
                uniqueKeysWithValues:
                    evidence.map {
                        ($0.id, $0)
                    }
            )

        let qualifyingEvidenceIDs: Set<String> =
            Set(
                evidence.compactMap { item -> String? in
                    guard
                        item.tier == .a ||
                        item.tier == .b
                    else {
                        return nil
                    }
                    return item.id
                }
            )

        func claimIsEvidenceBound(
            _ claim: String,
            evidenceIDs: Set<String>
        ) -> Bool {
            let excerpts = evidenceIDs.compactMap {
                evidenceByID[$0]?.excerpt
            }

            guard !excerpts.isEmpty else {
                return false
            }

            let claimTokens = evidenceTokens(in: claim)
            guard !claimTokens.isEmpty else {
                return false
            }

            let evidenceText = excerpts.joined(separator: " ")
            let matches = claimTokens.filter {
                evidenceText.localizedCaseInsensitiveContains($0)
            }

            return matches.count >= min(2, claimTokens.count)
        }

        let coveredFacetIDs: Set<String> =
            Set(
                evidence.compactMap { item -> String? in
                    qualifyingEvidenceIDs
                        .contains(item.id)
                    ? item.facetID
                    : nil
                }
            )

        let validDecisions =
            Set(
                AgentDevelopmentResearchDecision
                    .allCases
            )

        for approach in synthesis.approaches {
            if !validDecisions.contains(
                approach.decision
            ) {
                return AgentDevelopmentResearchVerificationOutcome(
                    state: .attention,
                    summary:
                        "Structured research contains an invalid development decision.",
                    fallback:
                        "Regenerate the affected approach using DISCARD / IMPROVE / MERGE / CREATE only."
                )
            }

            let externalIDs =
                Set(approach.evidenceIDs)

            guard
                !externalIDs.isEmpty,
                externalIDs.allSatisfy({
                    evidenceByID[$0] != nil
                }),
                !externalIDs
                    .intersection(
                        qualifyingEvidenceIDs
                    )
                    .isEmpty
            else {
                return AgentDevelopmentResearchVerificationOutcome(
                    state: .attention,
                    summary:
                        "At least one material approach is unsupported by qualifying external evidence.",
                    fallback:
                        "Do not promote unsupported claims; collect page-derived Tier A/B evidence first."
                )
            }

            guard claimIsEvidenceBound(
                approach.summary,
                evidenceIDs: externalIDs
            ) else {
                return AgentDevelopmentResearchVerificationOutcome(
                    state: .partial,
                    summary:
                        "A development approach cites evidence IDs, but its summary is not textually supported by their page-derived excerpts.",
                    fallback:
                        "Rewrite the approach from the cited excerpts or collect direct evidence; do not promote citation-only claims."
                )
            }

            if plan.requiresRepositoryComparison {
                let repoIDs =
                    Set(
                        approach
                            .repositoryEvidenceIDs
                    )

                guard
                    !repoIDs.isEmpty,
                    repoIDs.allSatisfy({
                        repositoryEvidenceIDs
                            .contains($0)
                    })
                else {
                    return AgentDevelopmentResearchVerificationOutcome(
                        state: .attention,
                        summary:
                            "At least one approach is not grounded in current KRALİ repository evidence.",
                        fallback:
                            "Bind the external finding to read-only current-source observations before comparison."
                    )
                }
            }
        }

        let proposalEvidence =
            Set(
                synthesis
                    .proposal
                    .evidenceIDs
            )
        let proposalRepositoryEvidence =
            Set(
                synthesis
                    .proposal
                    .repositoryEvidenceIDs
            )

        guard
            !synthesis.selectedImprovement
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty,
            !synthesis.proposal
                .selectedStrategy
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty,
            !proposalEvidence.isEmpty,
            proposalEvidence.allSatisfy({
                evidenceByID[$0] != nil
            }),
            !proposalEvidence
                .intersection(
                    qualifyingEvidenceIDs
                )
                .isEmpty
        else {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .attention,
                summary:
                    "The selected development proposal is not grounded in qualifying external evidence.",
                fallback:
                    "Select exactly one evidence-backed improvement before proposal completion."
            )
        }

        let unsupportedFinding = synthesis.proposal.researchFindings.first {
            !claimIsEvidenceBound(
                $0,
                evidenceIDs: proposalEvidence
            )
        }

        if unsupportedFinding != nil {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .partial,
                summary:
                    "A proposal finding cites evidence IDs, but its wording is not supported by the cited page-derived excerpts.",
                fallback:
                    "Keep only findings with direct excerpt support; otherwise collect stronger evidence before proposing development."
            )
        }

        if plan.requiresRepositoryComparison {
            guard
                !proposalRepositoryEvidence
                    .isEmpty,
                proposalRepositoryEvidence
                    .allSatisfy({
                        repositoryEvidenceIDs
                            .contains($0)
                    })
            else {
                return AgentDevelopmentResearchVerificationOutcome(
                    state: .attention,
                    summary:
                        "The selected proposal is not grounded in current repository observations.",
                    fallback:
                        "Bind the selected strategy to current KRALİ source evidence."
                )
            }
        }

        guard
            !synthesis.proposal.allowedScope.isEmpty,
            !synthesis.proposal.likelyFiles.isEmpty,
            !synthesis.proposal.verificationContract.isEmpty,
            !synthesis.proposal.behavioralBenchmark.isEmpty,
            !synthesis.proposal.rollbackCondition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .attention,
                summary: "The selected proposal lacks a complete impact map, regression contract, benchmark, or rollback condition.",
                fallback: "Complete affected scope/files, verification, behavioral benchmark, and rollback fields before creating a candidate."
            )
        }

        var gaps: [String] = []

        if synthesis.approaches.count <
            plan.requiredApproachCount {
            gaps.append(
                "approaches " +
                String(synthesis.approaches.count) +
                "/" +
                String(plan.requiredApproachCount)
            )
        }

        if coveredFacetIDs.count <
            plan.requiredApproachCount {
            gaps.append(
                "evidence-covered facets " +
                String(coveredFacetIDs.count) +
                "/" +
                String(plan.requiredApproachCount)
            )
        }

        if qualifying.count <
            plan.minimumQualifyingSourceCount {
            gaps.append(
                "qualifying sources " +
                String(qualifying.count) +
                "/" +
                String(plan.minimumQualifyingSourceCount)
            )
        }

        if highQuality.count <
            plan.minimumHighQualitySourceCount {
            gaps.append(
                "Tier A/B sources " +
                String(highQuality.count) +
                "/" +
                String(plan.minimumHighQualitySourceCount)
            )
        }

        if origins.count <
            plan.minimumIndependentOriginCount {
            gaps.append(
                "independent origins " +
                String(origins.count) +
                "/" +
                String(plan.minimumIndependentOriginCount)
            )
        }

        if coveredPreferredKinds.count <
            plan.minimumPreferredSourceKindCount {
            gaps.append(
                "preferred source kinds " +
                String(coveredPreferredKinds.count) +
                "/" +
                String(plan.minimumPreferredSourceKindCount)
            )
        }


        if !datedHighQuality.isEmpty && recentHighQuality.isEmpty {
            gaps.append("recent Tier A/B sources 0/1")
        }

        if !gaps.isEmpty {
            return AgentDevelopmentResearchVerificationOutcome(
                state: .partial,
                summary:
                    "Grounded research exists, but the mission-derived quality contract is incomplete: " +
                    gaps.joined(separator: " • "),
                fallback:
                    "Research only the uncovered facets with higher-quality primary sources; do not start mutation."
            )
        }

        return AgentDevelopmentResearchVerificationOutcome(
            state: .passed,
            summary:
                "Development research contract passed: mission-derived approach coverage, Tier A/B evidence, freshness audit, independent source origins, repository comparison, impact map, regression benchmark, rollback condition, one selected proposal, and mutation-off invariant are all satisfied.",
            fallback:
                "Human review is still required before any bounded Developer Agent task."
        )
    }

    private func evidenceTokens(in value: String) -> [String] {
        let stopWords = Set([
            "agent", "agents", "research", "evidence", "source",
            "sources", "current", "system", "systems", "approach",
            "proposal", "comparison", "with", "from", "into", "using",
            "this", "that", "these", "those", "and", "the", "for",
            "bir", "ile", "icin", "gibi", "olan", "olarak", "arastirma",
            "kanit", "kaynak", "sistem", "yaklasim", "onerisi"
        ])

        var seen = Set<String>()
        return value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter {
                $0.count >= 4 &&
                !stopWords.contains($0) &&
                seen.insert($0).inserted
            }
    }
}
