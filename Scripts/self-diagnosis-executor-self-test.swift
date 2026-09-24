import Foundation

@main
struct SelfDiagnosisExecutorSelfTest {
    static func expect(
        _ condition: @autoclosure () -> Bool,
        _ label: String
    ) {
        guard condition() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }

    static func run(
        _ arguments: [String],
        root: URL
    ) -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/git"
        )
        process.arguments =
            ["-C", root.path] +
            arguments
        process.standardOutput =
            outputPipe
        process.standardError =
            errorPipe

        do {
            try process.run()

            let outputData =
                outputPipe
                    .fileHandleForReading
                    .readDataToEndOfFile()
            let errorData =
                errorPipe
                    .fileHandleForReading
                    .readDataToEndOfFile()

            process.waitUntilExit()

            let output = String(
                data: outputData,
                encoding: .utf8
            ) ?? ""
            let errorOutput = String(
                data: errorData,
                encoding: .utf8
            ) ?? ""

            if process.terminationStatus != 0 {
                fputs(
                    "FAIL: git \(arguments.joined(separator: " ")) => \(errorOutput.isEmpty ? output : errorOutput)\n",
                    stderr
                )
                exit(1)
            }

            return output.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        } catch {
            fputs(
                "FAIL: git launch \(error)\n",
                stderr
            )
            exit(1)
        }
    }

    static func write(
        _ value: String,
        to url: URL
    ) {
        try? FileManager.default
            .createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        do {
            try value.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fputs(
                "FAIL: write \(url.path)\n",
                stderr
            )
            exit(1)
        }
    }

    static func main() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(
                "krali-self-diagnosis-" +
                UUID().uuidString,
                isDirectory: true
            )

        defer {
            try? fileManager.removeItem(
                at: root
            )
        }

        try? fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        _ = run(["init"], root: root)
        _ = run(
            [
                "config",
                "user.email",
                "krali-self-test@example.invalid"
            ],
            root: root
        )
        _ = run(
            [
                "config",
                "user.name",
                "KRALI Self Test"
            ],
            root: root
        )

        write(
            "0.11.2\n",
            to: root.appendingPathComponent(
                "VERSION"
            )
        )

        write(
            """
            struct ResearchPlanner {
                func plan() {
                    let researchCapability = "research.web"
                    let browserCapability = "browser.control"
                    let dependency = browserCapability
                    _ = researchCapability
                    _ = dependency
                }
            }
            """,
            to: root.appendingPathComponent(
                "App/ResearchPlanner.swift"
            )
        )

        write(
            """
            struct AgentOutcomePlanner {
                func strategies(availableCapabilityIDs: Set<String>) {
                    let kind = "retrievePublicInformation"
                    let preferredCapabilityIDs = ["research.web"]
                    let acceptableCapabilityIDs = [
                        "research.web",
                        "browser.control"
                    ]
                    let executableNow =
                        availableCapabilityIDs.contains("research.web")
                    _ = kind
                    _ = preferredCapabilityIDs
                    _ = acceptableCapabilityIDs
                    _ = executableNow
                }
            }
            """,
            to: root.appendingPathComponent(
                "App/AgentOutcomePlanner.swift"
            )
        )

        write(
            String(
                repeating:
                    "research browser planner semantic mission task graph capability evidence verification source runtime\n",
                count: 120
            ),
            to: root.appendingPathComponent(
                "App/AgentEngine.swift"
            )
        )

        write(
            """
            struct ResearchNotes {
                let primary = "research.web"
                let optionalUI = "browser.control"
                let note = "public research capability inventory"
            }
            """,
            to: root.appendingPathComponent(
                "App/ResearchNotes.swift"
            )
        )

        write(
            """
            {
              "appVersion": "0.10.43",
              "userInput": "public URL araştır",
              "goal": "research",
              "plan": "browser.control -> research.web",
              "verificationState": "attention",
              "verificationSummary": "browser.control unavailable blocked research.web",
              "taskGraph": [
                {"index":0,"capabilityID":"browser.control","available":false,"dependsOn":[]},
                {"index":1,"capabilityID":"research.web","available":true,"dependsOn":[0]}
              ],
              "researchEvidence": []
            }
            """,
            to: root.appendingPathComponent(
                "Mentor/latest.json"
            )
        )

        write(
            "IgnoredSecrets/\n",
            to: root.appendingPathComponent(
                ".gitignore"
            )
        )

        _ = run(["add", "."], root: root)
        _ = run(
            [
                "commit",
                "-m",
                "fixture"
            ],
            root: root
        )
        let head = run(
            ["rev-parse", "HEAD"],
            root: root
        )

        // Ignored local data may contain the same diagnosis terms but is not
        // part of the stamped source revision and must never become evidence.
        write(
            """
            {
              "research.web": "SECRET_TOKEN",
              "browser.control": "do not collect me",
              "dependency": "local-only"
            }
            """,
            to: root.appendingPathComponent(
                "IgnoredSecrets/config.json"
            )
        )

        let repository =
            AgentDeveloperRepository(
                path: root.path
            )
        let executor =
            AgentSelfDiagnosisExecutor()
        let mission =
            """
            Kendi research.web mimarini incele.
            browser.control unavailable iken public araştırma neden task graph dependency nedeniyle durdu?
            Bu görev için kullanma:
            - system.open.url
            - perception.screen
            Root cause evidence üret.
            """

        let package = executor.collect(
            userInput: mission,
            repository: repository,
            appVersion: "0.11.2",
            appSourceRevision: head
        )

        expect(
            package.sourceIdentity.isExact,
            "exact source identity"
        )
        expect(
            package.prohibitedCapabilityIDs.contains(
                "system.open.url"
            ) &&
            package.prohibitedCapabilityIDs.contains(
                "perception.screen"
            ),
            "mission capability prohibitions parsed"
        )
        expect(
            package.evidence.contains(
                where: {
                    $0.kind == "source"
                }
            ),
            "source evidence discovered"
        )
        let sourceEvidence =
            package.evidence.filter {
                $0.kind == "source"
            }
        let outcomePlannerIndex =
            sourceEvidence.firstIndex {
                $0.path ==
                    "App/AgentOutcomePlanner.swift"
            }
        let noisyEngineIndex =
            sourceEvidence.firstIndex {
                $0.path ==
                    "App/AgentEngine.swift"
            }

        expect(
            outcomePlannerIndex != nil,
            "causal outcome planner evidence discovered"
        )
        if let outcomePlannerIndex,
           let noisyEngineIndex {
            expect(
                outcomePlannerIndex <
                    noisyEngineIndex,
                "causal architecture outranks noisy generic source"
            )
        }
        expect(
            sourceEvidence.first(
                where: {
                    $0.path ==
                        "App/AgentOutcomePlanner.swift"
                }
            )?.excerpt.contains(
                "research.web"
            ) == true,
            "causal snippet contains public research mechanism"
        )
        expect(
            package.evidence.contains(
                where: {
                    $0.kind ==
                        "diagnostic_history"
                }
            ),
            "historical mentor evidence discovered"
        )
        expect(
            !package.evidence.contains(
                where: {
                    $0.path.contains(
                        "IgnoredSecrets"
                    )
                }
            ),
            "ignored local files excluded from evidence"
        )

        guard
            let sourceID =
                package.evidence.first(
                    where: {
                        $0.kind == "source" &&
                        $0.path ==
                            "App/ResearchPlanner.swift"
                    }
                )?.id,
            let failureID =
                package.evidence.first(
                    where: {
                        $0.kind ==
                            "diagnostic_history"
                    }
                )?.id
        else {
            fputs(
                "FAIL: required evidence ids\n",
                stderr
            )
            exit(1)
        }

        let alternative =
            AgentSelfDiagnosisAlternative(
                title:
                    "Filter invalid dependency before execution",
                advantages: [
                    "general"
                ],
                risks: [
                    "planner regression"
                ],
                architecturalImpact:
                    "planner feasibility",
                generalizability:
                    "all public research",
                changeSize:
                    "small",
                testability:
                    "behavioral graph fixture"
            )

        let proposal =
            AgentSelfDiagnosisProposal(
                problem:
                    "Research is blocked by an unnecessary unavailable dependency.",
                evidence: [
                    sourceID,
                    failureID
                ],
                rootCause:
                    "Planner dependency feasibility is not aligned with executable capability surface.",
                existingArchitecture:
                    "Planner -> graph -> runtime",
                selectedStrategy:
                    "Filter invalid dependency before execution",
                expectedBehavior:
                    "Public research proceeds without unnecessary computer control.",
                allowedScope: [
                    "planner",
                    "task graph"
                ],
                risks: [
                    "over-filtering"
                ],
                verificationContract: [
                    "public research graph has no unavailable browser dependency"
                ],
                behavioralBenchmark: [
                    "browser-specific task still requires browser capability"
                ],
                rollbackCondition:
                    "browser-specific tasks lose required dependencies"
            )

        let output =
            AgentSelfDiagnosisModelOutput(
                failureReconstruction:
                    "Historical trace shows browser unavailable before research.",
                proximateCause:
                    "Unavailable browser dependency blocked downstream research.",
                architecturalRootCause:
                    "Dependency feasibility was not aligned with the executable capability surface.",
                rootCauseEvidenceIDs: [
                    sourceID,
                    failureID
                ],
                confidence:
                    .high,
                architectureInspected: [
                    "App/ResearchPlanner.swift"
                ],
                capabilityAssessment: [
                    "research.web is independently present"
                ],
                alternatives: [
                    alternative,
                    AgentSelfDiagnosisAlternative(
                        title:
                            "Add a new browser provider",
                        advantages: [
                            "interactive coverage"
                        ],
                        risks: [
                            "unnecessary coupling"
                        ],
                        architecturalImpact:
                            "larger provider surface",
                        generalizability:
                            "interactive browser tasks",
                        changeSize:
                            "large",
                        testability:
                            "provider integration tests"
                    )
                ],
                decision:
                    "IMPROVE — fix dependency feasibility before creating a new capability.",
                developmentProposal:
                    proposal,
                remainingLimitations: []
            )

        let report =
            executor.assembleReport(
                package: package,
                modelOutput: output
            )

        expect(
            report.evidenceBound,
            "evidence-bound report"
        )
        expect(
            !report.mutationStarted,
            "diagnosis never mutates"
        )
        expect(
            report.developmentProposal != nil,
            "proposal available after evidence binding"
        )

        let invalidOutput =
            AgentSelfDiagnosisModelOutput(
                failureReconstruction:
                    output.failureReconstruction,
                proximateCause:
                    output.proximateCause,
                architecturalRootCause:
                    output.architecturalRootCause,
                rootCauseEvidenceIDs: [
                    "E999"
                ],
                confidence:
                    .high,
                architectureInspected:
                    output.architectureInspected,
                capabilityAssessment:
                    output.capabilityAssessment,
                alternatives:
                    output.alternatives,
                decision:
                    output.decision,
                developmentProposal:
                    proposal,
                remainingLimitations: []
            )

        let invalidReport =
            executor.assembleReport(
                package: package,
                modelOutput: invalidOutput
            )

        expect(
            !invalidReport.evidenceBound,
            "invented evidence rejected"
        )
        expect(
            invalidReport.developmentProposal == nil,
            "invalid evidence cannot produce mutation proposal"
        )

        let unrelatedSourceID =
            package.evidence.first(
                where: {
                    $0.kind == "source" &&
                    $0.path ==
                        "App/ResearchNotes.swift"
                }
            )?.id

        expect(
            unrelatedSourceID != nil,
            "deterministic unrelated source evidence discovered"
        )

        if let unrelatedSourceID {
            let weakSupportOutput =
                AgentSelfDiagnosisModelOutput(
                    failureReconstruction:
                        output.failureReconstruction,
                    proximateCause:
                        output.proximateCause,
                    architecturalRootCause:
                        output.architecturalRootCause,
                    rootCauseEvidenceIDs: [
                        unrelatedSourceID,
                        failureID
                    ],
                    confidence:
                        .high,
                    architectureInspected:
                        output.architectureInspected,
                    capabilityAssessment:
                        output.capabilityAssessment,
                    alternatives:
                        output.alternatives,
                    decision:
                        output.decision,
                    developmentProposal:
                        proposal,
                    remainingLimitations: []
                )

            let weakSupportReport =
                executor.assembleReport(
                    package: package,
                    modelOutput:
                        weakSupportOutput
                )

            expect(
                !weakSupportReport.evidenceBound,
                "unrelated source evidence cannot bind root cause"
            )
        }

        let prohibitedProposal =
            AgentSelfDiagnosisProposal(
                problem:
                    proposal.problem,
                evidence:
                    proposal.evidence,
                rootCause:
                    proposal.rootCause,
                existingArchitecture:
                    proposal.existingArchitecture,
                selectedStrategy:
                    "Use safe fallback",
                expectedBehavior:
                    "Use system.open.url with perception.screen as fallback.",
                allowedScope:
                    proposal.allowedScope,
                risks:
                    proposal.risks,
                verificationContract: [
                    "system.open.url succeeds"
                ],
                behavioralBenchmark:
                    proposal.behavioralBenchmark,
                rollbackCondition:
                    proposal.rollbackCondition
            )

        let prohibitedOutput =
            AgentSelfDiagnosisModelOutput(
                failureReconstruction:
                    output.failureReconstruction,
                proximateCause:
                    output.proximateCause,
                architecturalRootCause:
                    output.architecturalRootCause,
                rootCauseEvidenceIDs:
                    output.rootCauseEvidenceIDs,
                confidence:
                    .high,
                architectureInspected:
                    output.architectureInspected,
                capabilityAssessment:
                    output.capabilityAssessment,
                alternatives: [
                    AgentSelfDiagnosisAlternative(
                        title:
                            "Use safe fallback",
                        advantages: [
                            "simple"
                        ],
                        risks: [],
                        architecturalImpact:
                            "system.open.url + perception.screen",
                        generalizability:
                            "public research",
                        changeSize:
                            "small",
                        testability:
                            "behavioral"
                    ),
                    output.alternatives[1]
                ],
                decision:
                    output.decision,
                developmentProposal:
                    prohibitedProposal,
                remainingLimitations: []
            )

        let prohibitedReport =
            executor.assembleReport(
                package: package,
                modelOutput:
                    prohibitedOutput
            )

        expect(
            !prohibitedReport.evidenceBound,
            "prohibited capability cannot appear in selected strategy or proposal"
        )
        expect(
            prohibitedReport.developmentProposal == nil,
            "constraint-violating proposal suppressed"
        )

        write(
            """
            struct ResearchPlanner {
                // dirty working tree
            }
            """,
            to: root.appendingPathComponent(
                "App/ResearchPlanner.swift"
            )
        )

        let dirtyPackage =
            executor.collect(
                userInput: mission,
                repository: repository,
                appVersion: "0.11.2",
                appSourceRevision: head
            )

        expect(
            !dirtyPackage
                .sourceIdentity
                .isExact,
            "dirty repository blocks exact identity"
        )
        expect(
            !dirtyPackage
                .canDiagnoseCurrentSource,
            "dirty repository blocks diagnosis"
        )

        _ = run(
            ["checkout", "--", "."],
            root: root
        )

        let wrongRevision =
            executor.collect(
                userInput: mission,
                repository: repository,
                appVersion: "0.11.2",
                appSourceRevision:
                    String(
                        repeating: "0",
                        count: 40
                    )
            )

        expect(
            !wrongRevision
                .sourceIdentity
                .exactRevisionMatch,
            "wrong build revision rejected"
        )

        let router = AgentMissionRouter()
        let routing = router.classify(
            "Kendi kodunu incele, root cause'u bul ve geliştir."
        )
        let firewall =
            AgentDeveloperContextFirewall()

        expect(
            firewall.shouldIsolate(
                routing: routing
            ),
            "developer context firewall"
        )

        print(
            "self_diagnosis_executor_self_test_ok"
        )
        print(
            "source_revision_binding=pass"
        )
        print(
            "historical_evidence=pass"
        )
        print(
            "evidence_binding=pass"
        )
        print(
            "mutation_started=false"
        )
        print(
            "developer_context_firewall=pass"
        )
    }
}
