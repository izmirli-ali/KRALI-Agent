import Foundation

enum AgentSelfDiagnosisConfidence: String, Codable, Hashable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
}

struct AgentSelfDiagnosisSourceIdentity: Codable, Hashable {
    let repositoryPath: String
    let repositoryHeadSHA: String?
    let repositoryBranch: String?
    let repositoryVersion: String?
    let appVersion: String
    let appSourceRevision: String?
    let workingTreeClean: Bool
    let exactRevisionMatch: Bool
    let exactVersionMatch: Bool

    var isExact: Bool {
        exactRevisionMatch &&
        exactVersionMatch &&
        workingTreeClean
    }
}

struct AgentSelfDiagnosisEvidence: Codable, Hashable {
    let id: String
    let kind: String
    let path: String
    let lineStart: Int?
    let lineEnd: Int?
    let excerpt: String
    let matchedTerms: [String]
}

struct AgentSelfDiagnosisAlternative: Codable, Hashable {
    let title: String
    let advantages: [String]
    let risks: [String]
    let architecturalImpact: String
    let generalizability: String
    let changeSize: String
    let testability: String
}

struct AgentSelfDiagnosisProposal: Codable, Hashable {
    let problem: String
    let evidence: [String]
    let rootCause: String
    let existingArchitecture: String
    let selectedStrategy: String
    let expectedBehavior: String
    let allowedScope: [String]
    let risks: [String]
    let verificationContract: [String]
    let behavioralBenchmark: [String]
    let rollbackCondition: String
}

struct AgentSelfDiagnosisModelOutput: Codable, Hashable {
    let failureReconstruction: String
    let proximateCause: String
    let architecturalRootCause: String
    let rootCauseEvidenceIDs: [String]
    let confidence: AgentSelfDiagnosisConfidence
    let architectureInspected: [String]
    let capabilityAssessment: [String]
    let alternatives: [AgentSelfDiagnosisAlternative]
    let decision: String
    let developmentProposal: AgentSelfDiagnosisProposal
    let remainingLimitations: [String]
}

struct AgentSelfDiagnosisEvidencePackage: Codable, Hashable {
    let sourceIdentity: AgentSelfDiagnosisSourceIdentity
    let queryTerms: [String]
    let evidence: [AgentSelfDiagnosisEvidence]
    let warnings: [String]
    let prohibitedCapabilityIDs: [String]

    var canDiagnoseCurrentSource: Bool {
        sourceIdentity.isExact
    }
}

struct AgentSelfDiagnosisReport: Codable, Hashable {
    let sourceIdentity: AgentSelfDiagnosisSourceIdentity
    let failureReconstruction: String
    let proximateCause: String
    let architecturalRootCause: String
    let rootCauseEvidenceIDs: [String]
    let confidence: AgentSelfDiagnosisConfidence
    let architectureInspected: [String]
    let evidence: [AgentSelfDiagnosisEvidence]
    let capabilityAssessment: [String]
    let alternatives: [AgentSelfDiagnosisAlternative]
    let decision: String
    let developmentProposal: AgentSelfDiagnosisProposal?
    let mutationStarted: Bool
    let stopReason: String
    let remainingLimitations: [String]
    let evidenceBound: Bool

    func formattedFinalReport() -> String {
        let evidenceText = evidence
            .prefix(12)
            .map { item in
                let range: String
                if let start = item.lineStart,
                   let end = item.lineEnd {
                    range = ":\(start)-\(end)"
                } else {
                    range = ""
                }
                return "- [\(item.id)] \(item.path)\(range)"
            }
            .joined(separator: "\n")

        let alternativesText = alternatives
            .enumerated()
            .map { index, item in
                let advantages = item.advantages.isEmpty
                    ? "belirtilmedi"
                    : item.advantages.joined(separator: "; ")
                let risks = item.risks.isEmpty
                    ? "belirtilmedi"
                    : item.risks.joined(separator: "; ")
                return """
                \(index + 1). \(item.title)
                   - Avantaj: \(advantages)
                   - Risk: \(risks)
                   - Mimari etki: \(item.architecturalImpact)
                   - Genellenebilirlik: \(item.generalizability)
                   - Değişiklik büyüklüğü: \(item.changeSize)
                   - Test edilebilirlik: \(item.testability)
                """
            }
            .joined(separator: "\n")

        let proposalText: String
        if let proposal = developmentProposal {
            proposalText = """
            Problem: \(proposal.problem)
            Evidence: \(proposal.evidence.joined(separator: ", "))
            Root Cause: \(proposal.rootCause)
            Existing Architecture: \(proposal.existingArchitecture)
            Selected Strategy: \(proposal.selectedStrategy)
            Expected Behavior: \(proposal.expectedBehavior)
            Allowed Scope: \(proposal.allowedScope.joined(separator: ", "))
            Risks: \(proposal.risks.joined(separator: "; "))
            Verification Contract: \(proposal.verificationContract.joined(separator: "; "))
            Behavioral Benchmark: \(proposal.behavioralBenchmark.joined(separator: "; "))
            Rollback Condition: \(proposal.rollbackCondition)
            """
        } else {
            proposalText =
                "Evidence-bound root cause doğrulanmadığı için mutation proposal üretilmedi."
        }

        let inspected = architectureInspected.isEmpty
            ? "Doğrulanmış mimari yüzeyi yok."
            : architectureInspected.joined(separator: ", ")

        let assessment = capabilityAssessment.isEmpty
            ? "Yeterli kanıt yok."
            : capabilityAssessment.map { "- " + $0 }.joined(separator: "\n")

        let limitations = remainingLimitations.isEmpty
            ? "Yok."
            : remainingLimitations.map { "- " + $0 }.joined(separator: "\n")

        return """
        **A. Failure Reconstruction**
        \(failureReconstruction)

        **B. Root Cause**
        Proximate Cause: \(proximateCause)

        Architectural Root Cause: \(architecturalRootCause)

        Confidence: \(confidence.rawValue)
        Evidence IDs: \(rootCauseEvidenceIDs.joined(separator: ", "))

        **C. Repository / Architecture Inspected**
        Repo: \(sourceIdentity.repositoryPath)
        Repo HEAD: \(sourceIdentity.repositoryHeadSHA ?? "unknown")
        App source revision: \(sourceIdentity.appSourceRevision ?? "unknown")
        Exact revision match: \(sourceIdentity.exactRevisionMatch ? "yes" : "no")
        Working tree clean: \(sourceIdentity.workingTreeClean ? "yes" : "no")
        Architecture: \(inspected)

        **D. Evidence**
        \(evidenceText.isEmpty ? "Kanıt toplanamadı." : evidenceText)

        **E. Existing Capability Assessment**
        \(assessment)

        **F. Alternatives**
        \(alternativesText.isEmpty ? "Evidence-bound alternatif üretilemedi." : alternativesText)

        **G. Decision**
        \(decision)

        **H. Development Proposal**
        \(proposalText)

        **I. Mutation Started?**
        no

        **J. Stop Reason**
        \(stopReason)

        **K. Remaining Limitations**
        \(limitations)
        """
    }
}

struct AgentDeveloperContextFirewall {
    func shouldIsolate(
        routing: AgentMissionRoutingDecision
    ) -> Bool {
        routing.owner == .developer ||
        routing.owner == .stop
    }
}

/// Read-only repository diagnosis collector.
///
/// This type has no mutation, shell-write, git-write, network, browser or
/// computer-control primitive. It only reads repository files and executes
/// read-only git queries.
struct AgentSelfDiagnosisExecutor {
    private let fileManager = FileManager.default

    private let allowedExtensions: Set<String> = [
        "swift", "mjs", "command", "json", "md",
        "yml", "yaml", "sh"
    ]

    private let excludedPathPrefixes = [
        ".git/",
        ".build/",
        ".ci-build/",
        "DerivedData/",
        "node_modules/",
        "build/"
    ]

    func collect(
        userInput: String,
        repository: AgentDeveloperRepository,
        appVersion: String,
        appSourceRevision: String?
    ) -> AgentSelfDiagnosisEvidencePackage {
        let root = URL(
            fileURLWithPath: repository.path,
            isDirectory: true
        )
        .standardizedFileURL
        .resolvingSymlinksInPath()

        let head = git(
            ["rev-parse", "HEAD"],
            root: root
        )?.trimmedNonEmpty

        let branch = git(
            ["branch", "--show-current"],
            root: root
        )?.trimmedNonEmpty

        let status = git(
            ["status", "--porcelain"],
            root: root
        )

        let versionURL = root.appendingPathComponent(
            "VERSION",
            isDirectory: false
        )
        let repositoryVersion = (
            try? String(
                contentsOf: versionURL,
                encoding: .utf8
            )
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .nilIfEmpty

        let normalizedBundleRevision =
            appSourceRevision?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .nilIfEmpty

        let clean = status?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty == true

        let exactRevisionMatch =
            head != nil &&
            normalizedBundleRevision != nil &&
            head == normalizedBundleRevision

        let exactVersionMatch =
            repositoryVersion != nil &&
            repositoryVersion == appVersion

        let identity = AgentSelfDiagnosisSourceIdentity(
            repositoryPath: root.path,
            repositoryHeadSHA: head,
            repositoryBranch: branch,
            repositoryVersion: repositoryVersion,
            appVersion: appVersion,
            appSourceRevision: normalizedBundleRevision,
            workingTreeClean: clean,
            exactRevisionMatch: exactRevisionMatch,
            exactVersionMatch: exactVersionMatch
        )

        let terms = diagnosisTerms(
            from: userInput
        )
        let prohibitedCapabilities =
            prohibitedCapabilityIDs(
                from: userInput
            )

        var evidence: [AgentSelfDiagnosisEvidence] = [
            AgentSelfDiagnosisEvidence(
                id: "E1",
                kind: "mission_input",
                path: "current-user-mission",
                lineStart: nil,
                lineEnd: nil,
                excerpt: String(
                    userInput.prefix(3200)
                ),
                matchedTerms: terms
                    .filter {
                        normalized(userInput)
                            .contains(
                                normalized($0)
                            )
                    }
                    .prefix(12)
                    .map { $0 }
            )
        ]

        var warnings: [String] = []

        guard identity.isExact else {
            if !exactRevisionMatch {
                warnings.append(
                    "Developer repository HEAD does not exactly match the running app source revision."
                )
            }
            if !exactVersionMatch {
                warnings.append(
                    "Developer repository VERSION does not match the running app version."
                )
            }
            if !clean {
                warnings.append(
                    "Developer repository working tree is not clean."
                )
            }

            return AgentSelfDiagnosisEvidencePackage(
                sourceIdentity: identity,
                queryTerms: terms,
                evidence: evidence,
                warnings: warnings,
                prohibitedCapabilityIDs:
                    prohibitedCapabilities
            )
        }

        let sourceCandidates = rankedRepositoryFiles(
            root: root,
            terms: terms
        )

        for candidate in sourceCandidates.prefix(10) {
            let snippet = bestSnippet(
                content: candidate.content,
                terms: terms
            )

            guard !snippet.excerpt.isEmpty else {
                continue
            }

            evidence.append(
                AgentSelfDiagnosisEvidence(
                    id: "E\(evidence.count + 1)",
                    kind: "source",
                    path: candidate.relativePath,
                    lineStart: snippet.lineStart,
                    lineEnd: snippet.lineEnd,
                    excerpt: snippet.excerpt,
                    matchedTerms: candidate.matchedTerms
                )
            )
        }

        let historyEvidence =
            historicalMentorEvidence(
                root: root,
                terms: terms
            )

        for historical in historyEvidence.prefix(4) {
            evidence.append(
                AgentSelfDiagnosisEvidence(
                    id: "E\(evidence.count + 1)",
                    kind: "diagnostic_history",
                    path: historical.path,
                    lineStart: nil,
                    lineEnd: nil,
                    excerpt: historical.excerpt,
                    matchedTerms:
                        historical.matchedTerms
                )
            )
        }

        if !evidence.contains(
            where: { $0.kind == "source" }
        ) {
            warnings.append(
                "No relevant source-code evidence was discovered."
            )
        }

        if !evidence.contains(
            where: {
                $0.kind == "diagnostic_history"
            }
        ) {
            warnings.append(
                "No matching historical Mentor trace was discovered; failure reconstruction relies on the current mission evidence."
            )
        }

        // Re-check identity after collection so a concurrent checkout,
        // commit or file edit cannot produce a mixed-revision evidence package.
        let finalHead = git(
            ["rev-parse", "HEAD"],
            root: root
        )?.trimmedNonEmpty

        let finalBranch = git(
            ["branch", "--show-current"],
            root: root
        )?.trimmedNonEmpty

        let finalStatus = git(
            ["status", "--porcelain"],
            root: root
        )

        let finalVersion = (
            try? String(
                contentsOf: versionURL,
                encoding: .utf8
            )
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .nilIfEmpty

        let finalClean =
            finalStatus?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty == true

        if finalHead != head {
            warnings.append(
                "Developer repository HEAD changed during diagnosis; collected evidence is not accepted as a single revision."
            )
        }

        if !finalClean {
            warnings.append(
                "Developer repository became dirty during diagnosis; collected evidence is not accepted."
            )
        }

        if finalVersion != repositoryVersion {
            warnings.append(
                "Developer repository VERSION changed during diagnosis."
            )
        }

        let finalIdentity =
            AgentSelfDiagnosisSourceIdentity(
                repositoryPath: root.path,
                repositoryHeadSHA: finalHead,
                repositoryBranch: finalBranch,
                repositoryVersion: finalVersion,
                appVersion: appVersion,
                appSourceRevision:
                    normalizedBundleRevision,
                workingTreeClean:
                    finalClean &&
                    finalHead == head &&
                    finalVersion ==
                        repositoryVersion,
                exactRevisionMatch:
                    finalHead != nil &&
                    normalizedBundleRevision != nil &&
                    finalHead ==
                        normalizedBundleRevision &&
                    finalHead == head,
                exactVersionMatch:
                    finalVersion != nil &&
                    finalVersion == appVersion &&
                    finalVersion ==
                        repositoryVersion
            )

        return AgentSelfDiagnosisEvidencePackage(
            sourceIdentity:
                finalIdentity,
            queryTerms: terms,
            evidence: evidence,
            warnings: warnings,
            prohibitedCapabilityIDs:
                prohibitedCapabilities
        )
    }

    func assembleReport(
        package: AgentSelfDiagnosisEvidencePackage,
        modelOutput: AgentSelfDiagnosisModelOutput?,
        reasoningFailure: String? = nil
    ) -> AgentSelfDiagnosisReport {
        guard package.canDiagnoseCurrentSource else {
            return AgentSelfDiagnosisReport(
                sourceIdentity: package.sourceIdentity,
                failureReconstruction:
                    "Running app source identity could not be bound to the developer repository, so code-level diagnosis was not allowed to continue.",
                proximateCause:
                    "Source revision identity is unresolved.",
                architecturalRootCause:
                    "UNKNOWN — diagnosing a different checkout could create a false root cause.",
                rootCauseEvidenceIDs: ["E1"],
                confidence: .low,
                architectureInspected: [],
                evidence: package.evidence,
                capabilityAssessment: [],
                alternatives: [],
                decision:
                    "STOP — synchronize the approved developer repository to the exact running-app source revision.",
                developmentProposal: nil,
                mutationStarted: false,
                stopReason:
                    "Exact running-app ↔ repository revision identity is required before self-diagnosis.",
                remainingLimitations:
                    package.warnings,
                evidenceBound: false
            )
        }

        guard let modelOutput else {
            let failure =
                reasoningFailure?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            return AgentSelfDiagnosisReport(
                sourceIdentity: package.sourceIdentity,
                failureReconstruction:
                    "Repository evidence was collected successfully, but the local reasoning provider did not produce a structured diagnosis.",
                proximateCause:
                    failure?.isEmpty == false
                    ? "Reasoning provider failed: " + failure!
                    : "Reasoning provider unavailable or structured output invalid.",
                architecturalRootCause:
                    "UNKNOWN — evidence was not converted into a validated root-cause claim.",
                rootCauseEvidenceIDs: [],
                confidence: .low,
                architectureInspected:
                    package.evidence
                        .filter {
                            $0.kind == "source"
                        }
                        .map(\.path),
                evidence: package.evidence,
                capabilityAssessment: [],
                alternatives: [],
                decision:
                    "STOP — retain the evidence package and retry with a valid read-only reasoning provider.",
                developmentProposal: nil,
                mutationStarted: false,
                stopReason:
                    "Evidence-bound root cause was not established.",
                remainingLimitations:
                    package.warnings +
                    [
                        failure?.isEmpty == false
                        ? "Structured self-diagnosis reasoning failure: " + failure!
                        : "Structured self-diagnosis reasoning output is unavailable."
                    ],
                evidenceBound: false
            )
        }

        let knownEvidence = Dictionary(
            uniqueKeysWithValues:
                package.evidence.map {
                    ($0.id, $0)
                }
        )

        let citedIDs = Array(
            Set(
                modelOutput.rootCauseEvidenceIDs
            )
        )
        .sorted()

        let citedEvidence = citedIDs.compactMap {
            knownEvidence[$0]
        }

        let citationsValid =
            !citedIDs.isEmpty &&
            citedEvidence.count == citedIDs.count

        let hasSourceEvidence =
            citedEvidence.contains {
                $0.kind == "source"
            }

        let hasFailureEvidence =
            citedEvidence.contains {
                $0.kind == "diagnostic_history" ||
                $0.kind == "mission_input"
            }

        let rootCauseClaim =
            modelOutput.architecturalRootCause
        let causalClaimContext =
            modelOutput.proximateCause +
            "\n" +
            rootCauseClaim

        let supportingSourceEvidence =
            citedEvidence.filter {
                $0.kind == "source" &&
                evidenceSupportsRootCause(
                    $0,
                    claim: causalClaimContext
                )
            }

        let supportingFailureEvidence =
            citedEvidence.filter {
                (
                    $0.kind == "diagnostic_history" ||
                    $0.kind == "mission_input"
                ) &&
                evidenceSupportsRootCause(
                    $0,
                    claim: causalClaimContext
                )
            }

        let citedProposalEvidenceValid =
            !modelOutput.developmentProposal
                .evidence.isEmpty &&
            modelOutput.developmentProposal
                .evidence.allSatisfy {
                    knownEvidence[$0] != nil
                }

        let hasDistinctAlternatives =
            Set(
                modelOutput.alternatives.map {
                    normalized($0.title)
                }
            ).count >= 2

        let selectedStrategyMatchesAlternative =
            modelOutput.alternatives.contains {
                normalized(
                    modelOutput.developmentProposal
                        .selectedStrategy
                )
                .contains(
                    normalized($0.title)
                ) ||
                normalized($0.title)
                    .contains(
                        normalized(
                            modelOutput.developmentProposal
                                .selectedStrategy
                        )
                    )
            }

        let proposalConstraintSafe =
            proposalRespectsMissionConstraints(
                modelOutput,
                prohibitedCapabilityIDs:
                    package.prohibitedCapabilityIDs
            )

        let evidenceBound =
            citationsValid &&
            hasSourceEvidence &&
            hasFailureEvidence &&
            !supportingSourceEvidence.isEmpty &&
            !supportingFailureEvidence.isEmpty &&
            citedProposalEvidenceValid &&
            hasDistinctAlternatives &&
            selectedStrategyMatchesAlternative &&
            proposalConstraintSafe &&
            !rootCauseClaim
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty

        let finalConfidence: AgentSelfDiagnosisConfidence
        if evidenceBound {
            let hasHistorical =
                citedEvidence.contains {
                    $0.kind == "diagnostic_history"
                }

            if modelOutput.confidence == .high &&
               !hasHistorical {
                finalConfidence = .medium
            } else {
                finalConfidence =
                    modelOutput.confidence
            }
        } else {
            finalConfidence = .low
        }

        let proposal =
            evidenceBound
            ? modelOutput.developmentProposal
            : nil

        let stopReason =
            evidenceBound
            ? "Read-only diagnosis complete. A bounded registered mutation task and explicit human review are required before any code change."
            : "Evidence binding failed; mutation is forbidden."

        let limitations =
            package.warnings +
            modelOutput.remainingLimitations +
            (
                evidenceBound
                ? []
                : [
                    "Root-cause evidence did not semantically support the architectural claim, the proposal violated mission constraints, or the proposal was structurally incomplete."
                ]
            )

        return AgentSelfDiagnosisReport(
            sourceIdentity: package.sourceIdentity,
            failureReconstruction:
                modelOutput.failureReconstruction,
            proximateCause:
                modelOutput.proximateCause,
            architecturalRootCause:
                evidenceBound
                ? modelOutput.architecturalRootCause
                : "UNKNOWN — model output was not sufficiently evidence-bound.",
            rootCauseEvidenceIDs:
                evidenceBound ? citedIDs : [],
            confidence: finalConfidence,
            architectureInspected:
                modelOutput.architectureInspected,
            evidence: package.evidence,
            capabilityAssessment:
                modelOutput.capabilityAssessment,
            alternatives:
                evidenceBound
                ? modelOutput.alternatives
                : [],
            decision:
                evidenceBound
                ? modelOutput.decision
                : "STOP — insufficient evidence binding.",
            developmentProposal:
                proposal,
            mutationStarted: false,
            stopReason:
                stopReason,
            remainingLimitations:
                limitations,
            evidenceBound:
                evidenceBound
        )
    }

    private func evidenceSupportsRootCause(
        _ evidence: AgentSelfDiagnosisEvidence,
        claim: String
    ) -> Bool {
        let claimText = normalized(claim)
        let excerptText = normalized(evidence.excerpt)

        let architectureAnchors = [
            "planner",
            "dependency",
            "dependson",
            "task graph",
            "feasibility",
            "browser.control",
            "research.web",
            "outcome",
            "fallback",
            "unavailable",
            "blocked",
            "zorunlu",
            "bagimlilik",
            "planlayici"
        ]

        let causalAnchors = [
            "planner",
            "dependency",
            "dependson",
            "task graph",
            "feasibility",
            "unavailable",
            "blocked",
            "zorunlu",
            "bagimlilik",
            "planlayici"
        ]

        let claimAnchors =
            architectureAnchors.filter {
                claimText.contains($0)
            }

        guard !claimAnchors.isEmpty else {
            return false
        }

        let overlapCount =
            claimAnchors.filter {
                excerptText.contains($0)
            }.count

        let causalClaimAnchors =
            causalAnchors.filter {
                claimText.contains($0)
            }

        let causalOverlapCount =
            causalClaimAnchors.filter {
                excerptText.contains($0)
            }.count

        if evidence.kind == "source" {
            // Source code is responsible for proving the mechanism itself
            // (for example, a dependency edge). Historical failure evidence
            // separately proves that the mechanism actually blocked the run.
            return causalOverlapCount >= 1
        }

        let hasCausalSupport =
            causalClaimAnchors.isEmpty ||
            causalOverlapCount >= 1

        return overlapCount >= 2 &&
            hasCausalSupport
    }

    private func proposalRespectsMissionConstraints(
        _ output: AgentSelfDiagnosisModelOutput,
        prohibitedCapabilityIDs: [String]
    ) -> Bool {
        guard !prohibitedCapabilityIDs.isEmpty else {
            return true
        }

        let alternativeText =
            output.alternatives.flatMap {
                [$0.title] +
                $0.advantages +
                $0.risks +
                [
                    $0.architecturalImpact,
                    $0.generalizability,
                    $0.changeSize,
                    $0.testability
                ]
            }

        let proposal = output.developmentProposal
        let proposalText =
            [
                proposal.problem,
                proposal.rootCause,
                proposal.existingArchitecture,
                proposal.selectedStrategy,
                proposal.expectedBehavior,
                proposal.rollbackCondition
            ] +
            proposal.allowedScope +
            proposal.risks +
            proposal.verificationContract +
            proposal.behavioralBenchmark +
            alternativeText

        let normalizedProposal =
            normalized(
                proposalText.joined(
                    separator: "\n"
                )
            )

        return prohibitedCapabilityIDs.allSatisfy {
            !normalizedProposal.contains(
                normalized($0)
            )
        }
    }

    private func prohibitedCapabilityIDs(
        from userInput: String
    ) -> [String] {
        let capabilityPattern =
            try? NSRegularExpression(
                pattern:
                    #"[A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z][A-Za-z0-9_-]*)+"#
            )

        guard let capabilityPattern else {
            return []
        }

        let lines =
            userInput.components(
                separatedBy: .newlines
            )

        var result: Set<String> = []
        var inProhibitionBlock = false
        var blockCapturedCapability = false

        for rawLine in lines {
            let line =
                rawLine.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            let normalizedLine = normalized(line)

            let startsBlock =
                normalizedLine.contains(
                    "bu gorev icin kullanma"
                ) ||
                normalizedLine.contains(
                    "do not use"
                ) ||
                normalizedLine.contains(
                    "prohibited capabilities"
                )

            if startsBlock {
                inProhibitionBlock = true
                blockCapturedCapability = false
            }

            let range =
                NSRange(
                    line.startIndex..<line.endIndex,
                    in: line
                )
            let matches =
                capabilityPattern.matches(
                    in: line,
                    range: range
                )
            let capabilityIDs =
                matches.compactMap {
                    Range($0.range, in: line)
                }
                .map {
                    String(line[$0])
                }

            let lineHasDirectProhibition =
                normalizedLine.contains("kullanma") ||
                normalizedLine.contains("do not use") ||
                normalizedLine.contains("prohibited") ||
                normalizedLine.contains("yasak")

            if inProhibitionBlock {
                if !capabilityIDs.isEmpty {
                    capabilityIDs.forEach {
                        result.insert($0)
                    }
                    blockCapturedCapability = true
                } else if
                    blockCapturedCapability &&
                    !line.isEmpty &&
                    !line.hasPrefix("-") &&
                    !line.hasPrefix("*")
                {
                    inProhibitionBlock = false
                }
            } else if lineHasDirectProhibition {
                capabilityIDs.forEach {
                    result.insert($0)
                }
            }
        }

        return result.sorted()
    }

    private struct RankedFile {
        let relativePath: String
        let content: String
        let score: Int
        let matchedTerms: [String]
    }

    private struct HistoricalEvidence {
        let path: String
        let excerpt: String
        let score: Int
        let matchedTerms: [String]
    }

    private func rankedRepositoryFiles(
        root: URL,
        terms: [String]
    ) -> [RankedFile] {
        // Diagnose only committed/tracked source. Ignored or untracked local
        // files may contain credentials or machine-specific data and are not
        // part of the source revision stamped into the running app.
        guard let tracked = git(
            ["ls-files"],
            root: root
        ) else {
            return []
        }

        let trackedPaths = tracked
            .split(whereSeparator: {
                $0.isNewline
            })
            .map(String.init)

        var candidates: [RankedFile] = []
        var inspectedCount = 0

        for relative in trackedPaths {
            if inspectedCount >= 1200 {
                break
            }

            guard
                !excludedPathPrefixes
                    .contains(where: {
                        relative.hasPrefix($0)
                    }),
                !relative.hasPrefix(
                    "Mentor/"
                )
            else {
                continue
            }

            let url = root
                .appendingPathComponent(
                    relative,
                    isDirectory: false
                )
                .standardizedFileURL
                .resolvingSymlinksInPath()

            guard
                url.path.hasPrefix(
                    root.path + "/"
                ),
                allowedExtensions.contains(
                    url.pathExtension
                        .lowercased()
                )
            else {
                continue
            }

            let values = try? url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey
                ]
            )

            guard
                values?.isRegularFile == true,
                values?.isSymbolicLink != true,
                (values?.fileSize ?? 0) <= 550_000
            else {
                continue
            }

            inspectedCount += 1

            guard let raw = try? String(
                contentsOf: url,
                encoding: .utf8
            ) else {
                continue
            }

            let content = String(
                raw.prefix(220_000)
            )
            let corpus = normalized(content)
            let pathCorpus = normalized(relative)

            var score = 0
            var matched: [String] = []

            for term in terms {
                let normalizedTerm =
                    normalized(term)

                guard !normalizedTerm.isEmpty else {
                    continue
                }

                let pathHit =
                    pathCorpus.contains(
                        normalizedTerm
                    )
                let contentHits =
                    occurrenceCount(
                        normalizedTerm,
                        in: corpus,
                        limit: 8
                    )

                if pathHit || contentHits > 0 {
                    matched.append(term)
                    score += pathHit ? 9 : 0
                    score += min(contentHits, 8) * 2
                }
            }

            // Generic term density is useful for discovery but must not let
            // very large files drown out a smaller file that contains the
            // actual planner/dependency mechanism.
            score = min(score, 120)
            score += causalArchitectureBonus(
                relativePath: relative,
                corpus: corpus,
                terms: terms
            )

            if score > 0 {
                candidates.append(
                    RankedFile(
                        relativePath: relative,
                        content: content,
                        score: score,
                        matchedTerms:
                            Array(
                                matched.prefix(12)
                            )
                    )
                )
            }
        }

        return candidates.sorted {
            if $0.score == $1.score {
                return $0.relativePath <
                    $1.relativePath
            }
            return $0.score > $1.score
        }
    }

    private func causalArchitectureBonus(
        relativePath: String,
        corpus: String,
        terms: [String]
    ) -> Int {
        let normalizedTerms =
            Set(
                terms.map {
                    normalized($0)
                }
            )

        let diagnosisIsCausal =
            normalizedTerms.contains("planner") ||
            normalizedTerms.contains("dependency") ||
            normalizedTerms.contains("graph") ||
            normalizedTerms.contains("research.web") ||
            normalizedTerms.contains("browser.control")

        guard diagnosisIsCausal else {
            return 0
        }

        let path = normalized(relativePath)
        var bonus = 0

        if path.hasPrefix("app/") {
            bonus += 35
        }
        if path.contains("planner") {
            bonus += 35
        }
        if path.contains("capability") {
            bonus += 20
        }
        if path.hasPrefix("scripts/") {
            bonus -= 15
        }

        if corpus.contains("retrievepublicinformation") &&
           corpus.contains("research.web") {
            bonus += 160
        }

        if corpus.contains("dependson") &&
           corpus.contains("capabilityid") {
            bonus += 130
        }

        if corpus.contains("executablenow") &&
           corpus.contains("availablecapabilityids") {
            bonus += 110
        }

        if corpus.contains("preferredcapabilityids") &&
           corpus.contains("acceptablecapabilityids") {
            bonus += 80
        }

        if corpus.contains("research.web") &&
           corpus.contains("browser.control") {
            bonus += 60
        }

        if corpus.contains("unavailable") {
            bonus += 20
        }

        return bonus
    }

    private func historicalMentorEvidence(
        root: URL,
        terms: [String]
    ) -> [HistoricalEvidence] {
        var commits: [String] = []

        let refs = [
            "refs/remotes/origin/mentor/diagnostics",
            "HEAD"
        ]

        for ref in refs {
            guard let rawLog = git(
                [
                    "log",
                    "-n", "18",
                    "--format=%H",
                    ref,
                    "--",
                    "Mentor/latest.json"
                ],
                root: root
            ) else {
                continue
            }

            for commit in rawLog
                .split(whereSeparator: {
                    $0.isWhitespace
                })
                .map(String.init)
            where !commits.contains(commit) {
                commits.append(commit)
            }
        }

        guard !commits.isEmpty else {
            return []
        }

        var matches: [HistoricalEvidence] = []

        for commit in commits {
            guard
                let raw = git(
                    [
                        "show",
                        commit +
                        ":Mentor/latest.json"
                    ],
                    root: root
                ),
                !raw.isEmpty
            else {
                continue
            }

            let corpus = normalized(raw)
            var score = 0
            var matched: [String] = []

            for term in terms {
                let normalizedTerm =
                    normalized(term)
                let count =
                    occurrenceCount(
                        normalizedTerm,
                        in: corpus,
                        limit: 6
                    )

                if count > 0 {
                    matched.append(term)
                    score += min(count, 6) * 3
                }
            }

            guard score > 0 else {
                continue
            }

            let excerpt =
                diagnosticSummary(
                    raw,
                    terms: terms
                )

            matches.append(
                HistoricalEvidence(
                    path:
                        "git:" +
                        String(commit.prefix(12)) +
                        ":Mentor/latest.json",
                    excerpt:
                        String(
                            excerpt.prefix(3600)
                        ),
                    score: score,
                    matchedTerms:
                        Array(
                            matched.prefix(12)
                        )
                )
            )
        }

        return matches.sorted {
            $0.score > $1.score
        }
    }

    private func diagnosticSummary(
        _ raw: String,
        terms: [String]
    ) -> String {
        guard
            let data = raw.data(
                using: .utf8
            ),
            let object = try? JSONSerialization
                .jsonObject(
                    with: data
                ) as? [String: Any]
        else {
            return bestSnippet(
                content:
                    String(
                        raw.prefix(12_000)
                    ),
                terms: terms
            ).excerpt
        }

        let preferredKeys = [
            "appVersion",
            "userInput",
            "goal",
            "plan",
            "missionOwner",
            "missionPhase",
            "verificationState",
            "verificationSummary",
            "finalResponse",
            "taskGraph",
            "capabilities",
            "capabilityGaps",
            "researchSources",
            "researchEvidence"
        ]

        var result: [String] = []

        for key in preferredKeys {
            guard let value = object[key] else {
                continue
            }

            if let scalar = value as? String {
                result.append(
                    key + ": " +
                    String(
                        scalar.prefix(1200)
                    )
                )
            } else if
                JSONSerialization
                    .isValidJSONObject(value),
                let data =
                    try? JSONSerialization
                        .data(
                            withJSONObject: value,
                            options: [
                                .sortedKeys
                            ]
                        ),
                let string = String(
                    data: data,
                    encoding: .utf8
                ) {
                result.append(
                    key + ": " +
                    String(
                        string.prefix(1800)
                    )
                )
            } else {
                result.append(
                    key + ": " +
                    String(
                        describing: value
                    )
                )
            }
        }

        return result.joined(
            separator: "\n"
        )
    }

    private func bestSnippet(
        content: String,
        terms: [String]
    ) -> (
        excerpt: String,
        lineStart: Int?,
        lineEnd: Int?
    ) {
        let lines = content.components(
            separatedBy: .newlines
        )

        guard !lines.isEmpty else {
            return ("", nil, nil)
        }

        var bestIndex = 0
        var bestScore = -1

        let weightedAnchors = [
            "research.web",
            "browser.control",
            "dependson",
            "dependency",
            "retrievepublicinformation",
            "preferredcapabilityids",
            "acceptablecapabilityids",
            "executablenow",
            "unavailable",
            "outcome",
            "fallback"
        ]

        for index in lines.indices {
            let localStart = max(0, index - 3)
            let localEnd = min(
                lines.count - 1,
                index + 3
            )
            let corpus =
                normalized(
                    lines[localStart...localEnd]
                        .joined(separator: "\n")
                )
            var score = 0

            for term in terms {
                if corpus.contains(
                    normalized(term)
                ) {
                    score += 1
                }
            }

            for anchor in weightedAnchors
                where corpus.contains(anchor) {
                score += 4
            }

            if corpus.contains(
                "retrievepublicinformation"
            ) &&
               corpus.contains("research.web") {
                score += 30
            }

            if corpus.contains("dependson") &&
               corpus.contains("capabilityid") {
                score += 24
            }

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        let start = max(
            0,
            bestIndex - 6
        )
        let end = min(
            lines.count - 1,
            bestIndex + 8
        )

        let excerpt = lines[start...end]
            .enumerated()
            .map { offset, line in
                String(start + offset + 1) +
                ": " +
                line
            }
            .joined(separator: "\n")

        return (
            String(
                excerpt.prefix(2200)
            ),
            start + 1,
            end + 1
        )
    }

    private func diagnosisTerms(
        from input: String
    ) -> [String] {
        let dottedPattern =
            #"[A-Za-z_][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+)+"#

        let regex = try? NSRegularExpression(
            pattern: dottedPattern
        )

        let nsRange = NSRange(
            input.startIndex..<input.endIndex,
            in: input
        )

        var ordered: [String] = []

        if let regex {
            for match in regex.matches(
                in: input,
                range: nsRange
            ) {
                guard let range = Range(
                    match.range,
                    in: input
                ) else {
                    continue
                }

                ordered.append(
                    String(input[range])
                )
            }
        }

        let technicalSeeds = [
            "research",
            "browser",
            "planner",
            "semantic",
            "mission",
            "task",
            "graph",
            "dependency",
            "capability",
            "availability",
            "profile",
            "evidence",
            "verification",
            "fallback",
            "source",
            "reader",
            "runtime",
            "root",
            "cause",
            "developer",
            "repository"
        ]

        let normalizedInput =
            normalized(input)

        for seed in technicalSeeds
            where normalizedInput.contains(seed) {
            ordered.append(seed)
        }

        let stopWords: Set<String> = [
            "icin", "ile", "veya", "ama", "bunu", "bana",
            "bir", "bu", "su", "olarak", "olan", "nasil",
            "neden", "gorev", "gorevi", "amac", "amacı",
            "once", "sonra", "mevcut", "kendi", "sistem",
            "kullanici", "kullanma", "yapma", "degistirme",
            "the", "for", "with", "from", "this", "that",
            "should", "must", "into", "when", "while"
        ]

        let tokens = normalizedInput
            .components(
                separatedBy:
                    CharacterSet.alphanumerics
                        .inverted
            )
            .filter {
                $0.count >= 4 &&
                !stopWords.contains($0)
            }

        ordered.append(
            contentsOf:
                tokens.prefix(30)
        )

        var seen = Set<String>()
        return ordered.compactMap { value in
            let normalizedValue =
                normalized(value)

            guard
                !normalizedValue.isEmpty,
                !seen.contains(
                    normalizedValue
                )
            else {
                return nil
            }

            seen.insert(
                normalizedValue
            )

            return value
        }
        .prefix(32)
        .map { $0 }
    }

    private func relativePath(
        _ url: URL,
        root: URL
    ) -> String? {
        let rootPath = root.path
        let path = url.path

        guard
            path.hasPrefix(
                rootPath + "/"
            )
        else {
            return nil
        }

        return String(
            path.dropFirst(
                rootPath.count + 1
            )
        )
    }

    private func occurrenceCount(
        _ needle: String,
        in haystack: String,
        limit: Int
    ) -> Int {
        guard
            !needle.isEmpty,
            !haystack.isEmpty,
            limit > 0
        else {
            return 0
        }

        var count = 0
        var range =
            haystack.startIndex..<haystack.endIndex

        while
            count < limit,
            let found =
                haystack.range(
                    of: needle,
                    range: range
                )
        {
            count += 1
            range =
                found.upperBound..<haystack.endIndex
        }

        return count
    }

    private func git(
        _ arguments: [String],
        root: URL
    ) -> String? {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(
            fileURLWithPath:
                "/usr/bin/git"
        )
        process.arguments =
            ["-C", root.path] +
            arguments
        process.standardOutput =
            outputPipe
        process.standardError =
            FileHandle.nullDevice

        do {
            try process.run()

            // Drain stdout while git is running. Waiting before reading can
            // deadlock when a real repository or Mentor object fills the pipe.
            let data =
                outputPipe
                    .fileHandleForReading
                    .readDataToEndOfFile()

            process.waitUntilExit()

            guard
                process.terminationStatus == 0,
                let output = String(
                    data: data,
                    encoding: .utf8
                )
            else {
                return nil
            }

            return output
        } catch {
            return nil
        }
    }

    private func normalized(
        _ value: String
    ) -> String {
        value
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var trimmedNonEmpty: String? {
        trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .nilIfEmpty
    }
}
