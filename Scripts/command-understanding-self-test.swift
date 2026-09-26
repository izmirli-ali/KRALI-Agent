import Foundation

@main
struct CommandUnderstandingSelfTest {
    static func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }

    static let emptyContext = AgentContextSnapshot(
        hasWorkspace: false, workspaceName: nil, fileCount: 0,
        imageCount: 0, videoCount: 0, projectCount: 0, documentCount: 0,
        screenshotCount: 0, hasPendingAction: false,
        previousFileResultCount: 0, previousFolderResultCount: 0,
        lastTarget: nil, lastGoal: nil, relevantMemoryCount: 0,
        lastMemoryGoal: nil
    )

    static let general = AgentDecision(
        intent: .general, target: .any, dateRange: nil, dateField: .either,
        sortMode: .relevance, route: [], goal: "", selectedPlan: "",
        alternatives: [], proactiveSuggestion: nil, usePreviousResults: false,
        resultSelection: nil
    )

    static func main() {
        let interpreter = AgentGoalInterpreter()
        let clear = interpreter.interpret(
            "Anthropic Claude Code ürününü güncel kaynaklarla araştır.",
            decision: general,
            context: emptyContext
        )
        expect(clear.commandAssessment.confidence >= 0.9, "clear research command is confident")

        let ambiguous = interpreter.interpret(
            "Bunu aç veya araştır ve Premiere'de düzenle.",
            decision: general,
            context: emptyContext
        )
        expect(ambiguous.commandAssessment.requiresClarification, "ambiguous mixed command requests clarification")
        print("command_understanding_self_test_ok")
        print("clear_command=confident")
        print("ambiguous_command=clarification_required")
    }
}
