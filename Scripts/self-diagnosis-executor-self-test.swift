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
        let pipe = Pipe()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/git"
        )
        process.arguments =
            ["-C", root.path] +
            arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fputs(
                "FAIL: git launch \(error)\n",
                stderr
            )
            exit(1)
        }

        let data = pipe.fileHandleForReading
            .readDataToEndOfFile()
        let output = String(
            data: data,
            encoding: .utf8
        ) ?? ""

        if process.terminationStatus != 0 {
            fputs(
                "FAIL: git \(arguments.joined(separator: " ")) => \(output)\n",
                stderr
            )
            exit(1)
        }

        return output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
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
            {
              "appVersion": "0.10.43",
              "userInput": "public URL araştır",
              "goal": "research",
              "plan": "browser.control -> research.web",
              "verificationState": "attention",
              "verificationSummary": "browser.control unavailable",
              "taskGraph": [
                {"capabilityID":"browser.control","available":false},
                {"capabilityID":"research.web","available":true}
              ],
              "researchEvidence": []
            }
            """,
            to: root.appendingPathComponent(
                "Mentor/latest.json"
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
            package.evidence.contains(
                where: {
                    $0.kind == "source"
                }
            ),
            "source evidence discovered"
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

        guard
            let sourceID =
                package.evidence.first(
                    where: {
                        $0.kind == "source"
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
                    "Improve dependency feasibility",
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
