import Foundation

enum AgentCapabilityRisk {
    case reasoning
}

struct AgentCapability {
    let id: String
    let name: String
    let summary: String
    let risk: AgentCapabilityRisk
    let isAvailable: Bool
    let requiresWorkspace: Bool
}

@main
struct DevelopmentResearchQualitySelfTest {
    static func check(
        _ value: @autoclosure () -> Bool,
        _ label: String
    ) {
        guard value() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let planner = AgentResearchQueryPlanner()
        let mission = """
        KRALİ RESEARCH-CORE TEST — kendi araştırma ve gelişim mimarini iyileştir.

        Özellikle şu konulara bak:
        - autonomous agent learning
        - self-improving agents
        - agent skill libraries
        - experience replay
        - reflection
        - episodic / semantic memory
        - tool learning
        - task decomposition
        - self-debugging agents
        - evidence-grounded reasoning
        - long-running agents
        - agent evaluation
        - safe self-modification

        En az 5 farklı yaklaşım belirle.
        browser.control, desktop.app, desktop.control, app.workflow,
        system.open.url ve perception.screen kullanma.
        """

        let plan = planner.developmentPlan(mission)

        check(
            plan.requiredApproachCount == 5,
            "explicit approach count"
        )
        check(
            plan.facets.count >= 5,
            "multiple research facets"
        )
        check(
            plan.facets.prefix(5).allSatisfy {
                $0.queries.count >= 2
            },
            "diversified facet queries"
        )
        check(
            plan.facets
                .flatMap(\.queries)
                .allSatisfy {
                    !$0.contains("browser.control") &&
                    !$0.contains("desktop.control")
                },
            "paused control excluded from queries"
        )

        guard let memoryFacet =
            plan.facets.first(
                where: {
                    $0.label
                        .lowercased()
                        .contains("memory")
                }
            )
        else {
            fputs("FAIL: memory facet missing\n", stderr)
            exit(1)
        }

        let classifier =
            AgentDevelopmentResearchSourceClassifier()

        let irrelevantApple = WebResearchResult(
            title: "Vision | Apple Developer Documentation",
            url: URL(
                string:
                    "https://developer.apple.com/documentation/vision"
            )!,
            domain: "developer.apple.com",
            snippet:
                "Computer vision framework for image analysis."
        )

        let irrelevantAssessment =
            classifier.assess(
                irrelevantApple,
                facet: memoryFacet
            )

        check(
            irrelevantAssessment.tier == .d &&
            !irrelevantAssessment
                .qualifiesForTechnicalCoverage,
            "irrelevant official source cannot cover agent memory"
        )

        let relevantPaper = WebResearchResult(
            title:
                "Memory Mechanisms for LLM Agents",
            url: URL(
                string:
                    "https://arxiv.org/abs/2601.00001"
            )!,
            domain: "arxiv.org",
            snippet:
                "episodic semantic memory architecture for autonomous agents"
        )

        let paperAssessment =
            classifier.assess(
                relevantPaper,
                facet: memoryFacet
            )

        check(
            paperAssessment.tier == .a &&
            paperAssessment
                .qualifiesForTechnicalCoverage,
            "relevant paper is Tier A"
        )

        guard let toolFacet =
            plan.facets.first(
                where: {
                    $0.label
                        .lowercased()
                        .contains("tool learning")
                }
            )
        else {
            fputs("FAIL: tool learning facet missing\n", stderr)
            exit(1)
        }

        let toolBand = WebResearchResult(
            title:
                "TOOL - Schism (Official Video)",
            url: URL(
                string:
                    "https://www.youtube.com/watch?v=example"
            )!,
            domain:
                "www.youtube.com",
            snippet:
                "Official music video from the rock band Tool."
        )

        let toolBandAssessment =
            classifier.assess(
                toolBand,
                facet: toolFacet
            )

        check(
            toolBandAssessment.tier == .d &&
            !toolBandAssessment
                .qualifiesForTechnicalCoverage,
            "literal Tool music result is rejected"
        )

        guard let reflectionFacet =
            plan.facets.first(
                where: {
                    $0.label
                        .lowercased()
                        .contains("reflection")
                }
            )
        else {
            fputs("FAIL: reflection facet missing\n", stderr)
            exit(1)
        }

        let githubTopics = WebResearchResult(
            title:
                "reflection-agent · GitHub Topics",
            url: URL(
                string:
                    "https://github.com/topics/reflection-agent"
            )!,
            domain:
                "github.com",
            snippet:
                "Repositories and examples tagged reflection-agent for LLM agents."
        )

        let githubTopicsAssessment =
            classifier.assess(
                githubTopics,
                facet: reflectionFacet
            )

        check(
            githubTopicsAssessment.tier != .a &&
            githubTopicsAssessment.kind !=
                .originalRepository,
            "GitHub Topics is not an original repository"
        )

        let firstFive =
            Array(plan.facets.prefix(5))

        let origins = [
            "arxiv.org",
            "github.com",
            "openreview.net",
            "aclanthology.org",
            "openai.com"
        ]

        let kinds: [AgentResearchSourceKind] = [
            .paper,
            .originalRepository,
            .paper,
            .paper,
            .organizationEngineering
        ]

        let assessments =
            firstFive.enumerated().map {
                index,
                facet in

                AgentDevelopmentResearchSourceAssessment(
                    facetID: facet.id,
                    sourceURL:
                        "https://" +
                        origins[index] +
                        "/source-" +
                        String(index + 1),
                    sourceTitle:
                        facet.label +
                        " primary source",
                    domain:
                        origins[index],
                    origin:
                        origins[index],
                    kind:
                        kinds[index],
                    tier:
                        index == 4
                        ? .b
                        : .a,
                    relevance: 0.9,
                    qualityScore:
                        index == 4
                        ? 95
                        : 120,
                    qualifiesForTechnicalCoverage:
                        true
                )
            }

        let evidence =
            firstFive.enumerated().map {
                index,
                facet in

                AgentDevelopmentResearchEvidenceRecord(
                    id:
                        "W" +
                        String(index + 1),
                    facetID:
                        facet.id,
                    sourceURL:
                        assessments[index]
                            .sourceURL,
                    sourceTitle:
                        assessments[index]
                            .sourceTitle,
                    domain:
                        assessments[index]
                            .domain,
                    kind:
                        assessments[index]
                            .kind,
                    tier:
                        assessments[index]
                            .tier,
                    excerpt:
                        "Primary page evidence supporting " +
                        facet.label +
                        ". Grounding is improved by a structured verifier."
                )
            }

        let approaches =
            firstFive.enumerated().map {
                index,
                facet in

                AgentDevelopmentResearchApproach(
                    title:
                        facet.label,
                    decision:
                        .improve,
                    summary:
                        "Structured comparison for " + facet.label,
                    evidenceIDs: [
                        "W" +
                        String(index + 1)
                    ],
                    repositoryEvidenceIDs: [
                        "E" +
                        String(index + 1)
                    ],
                    benefits: [
                        "better research"
                    ],
                    risks: [
                        "bounded complexity"
                    ]
                )
            }

        let proposal =
            AgentDevelopmentResearchProposal(
                problem:
                    "Research intelligence quality",
                currentArchitecture:
                    "Facet research exists",
                researchFindings: [
                    "Primary evidence improves grounding"
                ],
                evidenceIDs: ["W1"],
                repositoryEvidenceIDs: ["E1"],
                gap:
                    "Deterministic quality gate",
                alternatives: [
                    "prompt-only",
                    "structured verifier"
                ],
                selectedStrategy:
                    "structured verifier",
                whyThisStrategy:
                    "deterministic and testable",
                expectedBehavior:
                    "unsupported research cannot pass",
                allowedScope: [
                    "research intelligence"
                ],
                likelyFiles: [
                    "AgentResearchQueryPlanner.swift"
                ],
                risks: [
                    "false negatives"
                ],
                securityBoundaries: [
                    "mutation off"
                ],
                verificationContract: [
                    "Tier A/B evidence required"
                ],
                behavioralBenchmark: [
                    "weak sources fail"
                ],
                rollbackCondition:
                    "research regression"
            )

        let synthesis =
            AgentDevelopmentResearchSynthesis(
                currentArchitecture: [
                    "research.web active"
                ],
                approaches: approaches,
                biggestGap:
                    "research quality",
                selectedImprovement:
                    "structured research quality gate",
                proposal: proposal,
                risks: [
                    "latency"
                ],
                verificationPlan: [
                    "fixture regressions"
                ],
                mutationRecommended:
                    true,
                mutationStarted:
                    false,
                remainingLimitations: []
            )

        let verifier =
            AgentDevelopmentResearchVerifier()

        let passed =
            verifier.verify(
                plan: plan,
                sources: assessments,
                evidence: evidence,
                repositoryEvidenceIDs:
                    Set(
                        (1...5)
                            .map {
                                "E" +
                                String($0)
                            }
                    ),
                synthesis: synthesis,
                executedCapabilityIDs: [
                    "core.reasoning",
                    "context.local",
                    "research.web"
                ]
            )

        check(
            passed.state == .passed,
            "grounded contract passes"
        )

        let unsupportedEvidence =
            evidence.enumerated().map {
                index,
                item in

                AgentDevelopmentResearchEvidenceRecord(
                    id: item.id,
                    facetID: item.facetID,
                    sourceURL: item.sourceURL,
                    sourceTitle: item.sourceTitle,
                    domain: item.domain,
                    kind: item.kind,
                    tier: item.tier,
                    excerpt:
                        index == 0
                        ? "Unrelated material without the claimed research finding."
                        : item.excerpt
                )
            }

        let unsupportedResult =
            verifier.verify(
                plan: plan,
                sources: assessments,
                evidence: unsupportedEvidence,
                repositoryEvidenceIDs:
                    Set(
                        (1...5)
                            .map {
                                "E" +
                                String($0)
                            }
                    ),
                synthesis: synthesis,
                executedCapabilityIDs: [
                    "research.web"
                ]
            )

        check(
            unsupportedResult.state == .partial,
            "citation-only findings cannot pass without excerpt support"
        )

        let weakAssessments =
            assessments.map {
                AgentDevelopmentResearchSourceAssessment(
                    facetID: $0.facetID,
                    sourceURL: $0.sourceURL,
                    sourceTitle: $0.sourceTitle,
                    domain: $0.domain,
                    origin: $0.origin,
                    kind: .secondarySummary,
                    tier: .d,
                    relevance: 0.1,
                    qualityScore: 10,
                    qualifiesForTechnicalCoverage:
                        false
                )
            }

        let weakEvidence =
            evidence.map {
                AgentDevelopmentResearchEvidenceRecord(
                    id: $0.id,
                    facetID: $0.facetID,
                    sourceURL: $0.sourceURL,
                    sourceTitle: $0.sourceTitle,
                    domain: $0.domain,
                    kind: .secondarySummary,
                    tier: .d,
                    excerpt: $0.excerpt
                )
            }

        let weakResult =
            verifier.verify(
                plan: plan,
                sources: weakAssessments,
                evidence: weakEvidence,
                repositoryEvidenceIDs:
                    Set(
                        (1...5)
                            .map {
                                "E" +
                                String($0)
                            }
                    ),
                synthesis: synthesis,
                executedCapabilityIDs: [
                    "research.web"
                ]
            )

        check(
            weakResult.state == .attention,
            "weak-only evidence cannot pass"
        )

        let prohibitedResult =
            verifier.verify(
                plan: plan,
                sources: assessments,
                evidence: evidence,
                repositoryEvidenceIDs:
                    Set(
                        (1...5)
                            .map {
                                "E" +
                                String($0)
                            }
                    ),
                synthesis: synthesis,
                executedCapabilityIDs: [
                    "research.web",
                    "browser.control"
                ]
            )

        check(
            prohibitedResult.state == .attention,
            "computer control cannot enter development research"
        )

        print("development_research_quality_self_test_ok")
        print("facet_plan=PASS")
        print("source_quality=PASS")
        print("lexical_false_positives=BLOCKED")
        print("evidence_contract=PASS")
        print("computer_control=BLOCKED")
    }
}
