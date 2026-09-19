import Foundation

struct AgentResponseComposer {
    func compose(
        baseReply: String,
        verification: AgentVerificationResult,
        goal: AgentGoalProfile,
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        fallbackPlan: String?
    ) -> String {
        let unavailable = capabilities.filter { !$0.isAvailable }

        switch verification.state {
        case .partial:
            var reply = "Görevin yapabildiğim kısmını tamamladım."
            let cleaned = removeCompletionClaim(from: baseReply)

            if !cleaned.isEmpty {
                reply += "\n\n" + cleaned
            }

            reply += "\n\nKısmi doğrulama: " + verification.summary

            if !unavailable.isEmpty {
                reply += "\nEksik kabiliyet: " +
                    unavailable.map(\.name).joined(separator: ", ") + "."
            }

            if let learning = learningPlans.first {
                reply += "\nYetkinlik kazanma planı: " + learning.nextStep
            }

            return reply

        case .attention:
            var reply = baseReply
            reply += "\n\nDoğrulama: " + verification.summary

            if let fallbackPlan, !fallbackPlan.isEmpty {
                reply += "\nAlternatif plan: " + fallbackPlan
            }

            if let learning = learningPlans.first {
                reply += "\nYetkinlik kazanma planı: " + learning.nextStep
            }

            return reply

        case .passed, .skipped:
            return baseReply

        case .idle, .checking:
            return baseReply
        }
    }

    private func removeCompletionClaim(from text: String) -> String {
        var result = text

        let prefixes = [
            "Görevi zincir halinde tamamladım. ",
            "Görevi zincir halinde tamamladım.\n\n",
            "Görevi zincir halinde tamamladım:",
            "Görevi tamamladım. ",
            "Görevi tamamladım.\n\n"
        ]

        for prefix in prefixes where result.hasPrefix(prefix) {
            result.removeFirst(prefix.count)
            break
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
