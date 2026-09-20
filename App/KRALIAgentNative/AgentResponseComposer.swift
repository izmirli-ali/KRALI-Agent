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

            return polish(reply)

        case .attention:
            var reply: String

            if !unavailable.isEmpty {
                reply =
                    "Görev tamamlanamadı. Eksik kabiliyet: " +
                    unavailable.map(\.name).joined(separator: ", ") +
                    "."
            } else {
                let cleaned =
                    removeCompletionClaim(
                        from: baseReply
                    )
                reply = cleaned.isEmpty
                    ? "Görev doğrulanamadı."
                    : cleaned
            }

            reply += "\n\nDoğrulama: " + verification.summary

            if let fallbackPlan, !fallbackPlan.isEmpty {
                reply += "\nAlternatif plan: " + fallbackPlan
            }

            if let learning = learningPlans.first {
                reply += "\nYetkinlik kazanma planı: " + learning.nextStep
            }

            return polish(reply)

        case .passed, .skipped:
            return polish(baseReply)

        case .idle, .checking:
            return polish(baseReply)
        }
    }

    private func polish(
        _ text: String
    ) -> String {
        let replacements: [
            (String, String)
        ] = [
            ("Kapanışda", "Kapanışta"),
            ("kapanışda", "kapanışta"),
            ("Şuan", "Şu an"),
            ("şuan", "şu an"),
            ("Birşey", "Bir şey"),
            ("birşey", "bir şey"),
            ("Yada", "Ya da"),
            ("yada", "ya da"),
            ("Yanlız", "Yalnız"),
            ("yanlız", "yalnız"),
            ("Herkez", "Herkes"),
            ("herkez", "herkes"),
            ("Değilmi", "Değil mi"),
            ("değilmi", "değil mi")
        ]

        var result = text

        for pair in replacements {
            result = result.replacingOccurrences(
                of: pair.0,
                with: pair.1
            )
        }

        return result
            .replacingOccurrences(
                of: #"\n{3,}"#,
                with: "\n\n",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
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
