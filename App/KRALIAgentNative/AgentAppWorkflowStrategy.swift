import Foundation

struct AppWorkflowStrategyResult: Hashable, Sendable {
    let frontmostApplication: String
    let observationEvidence: String
    let workflowOutput: String
    let preparedWithoutCommit: Bool
}

enum AppWorkflowStrategyError: LocalizedError {
    case noFrontmostApplication
    case noObservableEvidence
    case externalCommitRequested
    case interpretationUnavailable

    var errorDescription: String? {
        switch self {
        case .noFrontmostApplication:
            return "Uygulama içi iş akışı için öndeki uygulama doğrulanamadı."
        case .noObservableEvidence:
            return "Uygulama içi hedefi destekleyen okunabilir ekran kanıtı bulunamadı."
        case .externalCommitRequested:
            return "İstenen iş akışı dış dünyada değişiklik yapıyor; generic strategy bunu kullanıcı onayı ve güvenli UI provider'ı olmadan uygulayamaz."
        case .interpretationUnavailable:
            return "Ekran kanıtı alındı ancak hedefe uygun güvenilir sonuç çıkarılamadı."
        }
    }
}

actor AgentAppWorkflowStrategy {
    private let screenPerception = AgentScreenPerception()
    private let localIntelligence = AgentLocalIntelligence()

    func execute(
        objective: String,
        stepTitle: String,
        stepPurpose: String,
        dependencyEvidence: String
    ) async throws -> AppWorkflowStrategyResult {
        guard !Self.requestsExternalCommit(objective) else {
            throw AppWorkflowStrategyError.externalCommitRequested
        }

        let observationGoal = [
            objective,
            "Aktif iş akışı adımı: " + stepTitle,
            stepPurpose,
            "Yalnızca görünür uygulama içeriğini oku ve sonucu doğrula. Hiçbir tıklama, yazma, gönderme, kaydetme veya başka dış değişiklik yapma.",
            dependencyEvidence
        ]
        .filter {
            !$0.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
        .joined(separator: "\n")

        let report = try await screenPerception.observe(
            goal: String(observationGoal.prefix(8_000))
        )

        guard let frontmostApplication = report.frontmostApplication?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !frontmostApplication.isEmpty else {
            throw AppWorkflowStrategyError.noFrontmostApplication
        }

        let rawEvidence = Self.observationEvidence(from: report)
        guard !report.recognizedText.isEmpty,
              !rawEvidence.isEmpty else {
            throw AppWorkflowStrategyError.noObservableEvidence
        }

        let interpreted = await localIntelligence.executeReasoningStep(
            goal: objective,
            title: stepTitle,
            purpose: stepPurpose + " Değişiklik isteyen kısmı yalnız uygulanmamış hazırlık/taslak olarak belirt.",
            operation: "app.workflow.observe-and-prepare",
            dependencyEvidence: rawEvidence
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let workflowOutput = interpreted?.isEmpty == false
            ? interpreted!
            : report.semanticSummary.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !workflowOutput.isEmpty else {
            throw AppWorkflowStrategyError.interpretationUnavailable
        }

        return AppWorkflowStrategyResult(
            frontmostApplication: frontmostApplication,
            observationEvidence: rawEvidence,
            workflowOutput: workflowOutput,
            preparedWithoutCommit: true
        )
    }

    static func requestsExternalCommit(
        _ value: String
    ) -> Bool {
        let text = normalize(value)
        let preparationTerms = [
            "hazirla", "taslak", "onay almadan",
            "degisiklik yapma", "commit etmeden"
        ]

        if preparationTerms.contains(where: text.contains) {
            return false
        }

        let commitTerms = [
            "gonder", "yayinla", "paylas", "sil",
            "satinal", "satin al", "kaydet", "ekle",
            "olustur", "degistir", "uygula", "onayla"
        ]

        return commitTerms.contains(where: text.contains)
    }

    private static func observationEvidence(
        from report: ScreenPerceptionReport
    ) -> String {
        let windows = report.visibleWindows
            .prefix(20)
            .joined(separator: "\n")
        let text = report.recognizedText
            .prefix(100)
            .joined(separator: "\n")

        return [
            "Öndeki uygulama: " +
                (report.frontmostApplication ?? "Bilinmiyor"),
            "Görünen pencereler:\n" +
                (windows.isEmpty ? "Yok" : windows),
            "OCR gözlemi:\n" +
                (text.isEmpty ? "Yok" : text),
            "Ekran yorumlama kanıtı:\n" +
                report.semanticSummary
        ]
        .joined(separator: "\n\n")
    }

    private static func normalize(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
    }
}