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

    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            fputs("FAIL: repository path required\n", stderr)
            exit(1)
        }

        let root = CommandLine.arguments[1]
        let repository = AgentDeveloperRepository(path: root)
        let request = """
        SELF-DEVELOPMENT MISSION
        v0.10.43 benchmarkında research.web available iken browser.control unavailable oldu.
        Planner browser.control adımını research.web öncesinde dependency yaptı.
        Kendi repository geçmişini read-only incele, root cause'u kanıtla.
        Main'e merge etme. Push yapma. Filesystem yetkini genişletme.
        """

        let report = AgentSelfDiagnosisExecutor().diagnose(
            request: request,
            repository: repository,
            runningVersion: "0.11.2"
        )

        print("DEBUG target_version=\(report.targetVersion ?? "none")")
        print("DEBUG confidence=\(report.confidence)")
        print("DEBUG inspected=\(report.inspectedFiles.joined(separator: ","))")
        print("DEBUG evidence_paths=\(report.evidence.map { $0.path }.joined(separator: ","))")
        print("DEBUG root_cause=\(report.rootCause)")

        expect(report.repositoryRevision != "unknown", "repository revision resolved")
        expect(report.targetVersion == "0.10.43", "historical version resolved")
        expect(report.targetRevision != report.repositoryRevision, "historical revision differs from current")
        expect(!report.inspectedFiles.isEmpty, "source files inspected")
        expect(!report.evidence.isEmpty, "source evidence collected")
        expect(report.confidence != "LOW", "diagnosis confidence is bounded but useful")
        expect(report.mutationStarted == false, "mutation remains disabled")
        expect(report.proposal.contains("Verification Contract"), "proposal includes verification contract")
        expect(report.rendered.contains("Mutation Started?"), "rendered report is structured")

        print("self_diagnosis_executor_self_test_ok")
        print("target_version=\(report.targetVersion ?? "none")")
        print("confidence=\(report.confidence)")
        print("evidence=\(report.evidence.count)")
        print("mutation_started=\(report.mutationStarted)")
    }
}
