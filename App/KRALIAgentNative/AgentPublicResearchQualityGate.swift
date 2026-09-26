import Foundation

/// Separates the presence of web pages from the quality required to answer a
/// public-research question.  It is deliberately read-only: a strong score
/// authorizes neither tool access nor any project mutation.
struct AgentPublicResearchQualityAssessment: Hashable {
    let score: Int
    let evidenceCount: Int
    let independentDomainCount: Int
    let highQualitySourceCount: Int
    let datedSourceCount: Int
    let recentSourceCount: Int
    let requiresPreferredPrimarySource: Bool
    let hasPreferredPrimarySource: Bool
    let potentialContradictionCount: Int
    let sourceAssessments: [AgentDevelopmentResearchSourceAssessment]

    var isSufficient: Bool {
        evidenceCount >= 2 &&
        independentDomainCount >= 2 &&
        highQualitySourceCount >= 1 &&
        (!requiresPreferredPrimarySource || hasPreferredPrimarySource) &&
        score >= 65
    }

    var shortfall: String {
        var reasons: [String] = []
        if evidenceCount < 2 { reasons.append("en az iki okunmuş sayfa kanıtı") }
        if independentDomainCount < 2 { reasons.append("en az iki bağımsız alan adı") }
        if highQualitySourceCount < 1 { reasons.append("en az bir A/B seviye birincil veya güvenilir teknik kaynak") }
        if requiresPreferredPrimarySource && !hasPreferredPrimarySource {
            reasons.append("konuya ait tercihli/resmî birincil kaynak")
        }
        if score < 65 { reasons.append("asgari kalite puanı") }
        return reasons.joined(separator: ", ")
    }
}

struct AgentPublicResearchQualityGate {
    private let classifier = AgentDevelopmentResearchSourceClassifier()

    func assess(
        query: String,
        plan: ResearchQueryPlan,
        evidence: [WebSourceEvidence]
    ) -> AgentPublicResearchQualityAssessment {
        let facet = AgentDevelopmentResearchFacet(
            id: "public-research",
            label: "Genel araştırma doğrulaması",
            topics: Array(plan.conceptGroups.flatMap { $0 }.prefix(12)),
            required: true,
            preferredSourceKinds: [
                .officialDocumentation,
                .paper,
                .originalRepository,
                .organizationEngineering,
                .technicalPublication
            ],
            queries: [query]
        )

        let assessments = evidence.map { item in
            classifier.assess(item.source, facet: facet)
        }
        let domains = Set(evidence.map { $0.source.domain.lowercased() })
        let highQuality = assessments.filter {
            ($0.tier == .a || $0.tier == .b) &&
            $0.relevance >= 0.30
        }
        let preferredDomains = Set(plan.preferredDomains.map { $0.lowercased() })
        let hasPreferred = preferredDomains.isEmpty || domains.contains {
            domain in preferredDomains.contains {
                domain == $0 || domain.hasSuffix("." + $0)
            }
        }
        let records = zip(evidence, assessments).map { item, assessment in
            AgentDevelopmentResearchEvidenceRecord(
                id: item.id,
                facetID: facet.id,
                sourceURL: item.source.url.absoluteString,
                sourceTitle: item.source.title,
                domain: item.source.domain,
                kind: assessment.kind,
                tier: assessment.tier,
                excerpt: item.excerpt,
                publishedAt: item.source.publishedAt
            )
        }
        let audit = AgentDevelopmentResearchEvidenceAudit.analyze(
            sources: assessments,
            evidence: records
        )

        let authority = min(30, highQuality.count * 20)
        let coverage = min(25, evidence.count * 10)
        let diversity = min(20, domains.count * 10)
        let freshness = audit.recentSourceCount > 0
            ? 15
            : (audit.datedSourceCount > 0 ? 8 : 0)
        let transparency = audit.potentialContradictionCount == 0 ? 10 : 5

        return AgentPublicResearchQualityAssessment(
            score: min(100, authority + coverage + diversity + freshness + transparency),
            evidenceCount: evidence.count,
            independentDomainCount: domains.count,
            highQualitySourceCount: highQuality.count,
            datedSourceCount: audit.datedSourceCount,
            recentSourceCount: audit.recentSourceCount,
            requiresPreferredPrimarySource: !preferredDomains.isEmpty,
            hasPreferredPrimarySource: hasPreferred,
            potentialContradictionCount: audit.potentialContradictionCount,
            sourceAssessments: assessments
        )
    }

    func sourceLabel(
        _ assessment: AgentDevelopmentResearchSourceAssessment
    ) -> String {
        let kind: String
        switch assessment.kind {
        case .paper: kind = "akademik yayın"
        case .officialDocumentation: kind = "resmî belge"
        case .originalRepository: kind = "özgün depo"
        case .organizationEngineering: kind = "kurumsal teknik yayın"
        case .technicalPublication: kind = "teknik yayın"
        case .secondarySummary: kind = "ikincil özet"
        case .generic: kind = "genel kaynak"
        }
        return "Seviye \(assessment.tier.rawValue) • \(kind) • ilgi \(Int((assessment.relevance * 100).rounded()))/100"
    }
}
