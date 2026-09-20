import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum LocalIntelligenceState: Hashable {
    case checking
    case available
    case unavailable(String)

    var title: String {
        switch self {
        case .checking:
            return "Yerel zeka kontrol ediliyor…"
        case .available:
            return "Apple yerel zeka hazır"
        case .unavailable(let reason):
            return "Yerel zeka kullanılamıyor: \(reason)"
        }
    }

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
}

actor AgentLocalIntelligence {
    func availability() -> LocalIntelligenceState {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default

            if model.isAvailable {
                return .available
            }

            return .unavailable(
                "Apple Intelligence modeli bu Mac'te hazır değil"
            )
        }
        #endif

        return .unavailable(
            "Foundation Models için macOS 26+ gerekiyor"
        )
    }

    func synthesize(
        userInput: String,
        goal: String,
        draft: String,
        verification: AgentVerificationResult,
        capabilities: [AgentCapability],
        researchEvidence: [WebSourceEvidence],
        contextMemory: [AgentContextMemoryEntry]
    ) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                return nil
            }

            let unavailableCapabilities = capabilities
                .filter { !$0.isAvailable }
                .map(\.name)
                .joined(separator: ", ")

            let memoryText = contextMemory
                .prefix(4)
                .map {
                    "[\($0.kind.rawValue)] \($0.title): \($0.summary)"
                }
                .joined(separator: "\n")

            let evidenceText = researchEvidence
                .prefix(6)
                .enumerated()
                .map { index, evidence in
                    """
                    [\(index + 1)] \(evidence.source.title)
                    Kaynak: \(evidence.source.domain)
                    Kanıt: \(String(evidence.excerpt.prefix(1200)))
                    """
                }
                .joined(separator: "\n\n")

            let instructions = """
            Sen KRALİ'nin yerel akıl yürütme ve sentez katmanısın.
            Türkçe cevap ver.

            Kurallar:
            - Kullanıcının hedefini doğrudan cevapla; yalnızca plan veya süreç anlatma.
            - Verilen kanıtları özetlemekle yetinme. Neden-sonuç, örüntü, güçlü/zayıf yan, fırsat ve risk çıkarımları üret.
            - Kullanıcı fikir istiyorsa, söylediği maddeleri tekrarlamak yerine kanıtlardan türetilmiş özgün fikirler üret.
            - Gerçek kaynak kanıtı ile kendi çıkarımını birbirinden ayır.
            - Kanıtta olmayan somut bilgileri uydurma.
            - Eksik veya kullanılamayan capability varsa, o işi gerçekten yapmış gibi konuşma.
            - Araştırma sonucunda çelişki veya belirsizlik varsa açıkça belirt.
            - Gereksiz uzun süreç açıklaması yapma; kullanışlı sonuca odaklan.
            """

            let prompt = """
            Kullanıcı isteği:
            \(userInput)

            Hedef sözleşmesi:
            \(goal)

            Önceki ilgili bağlam:
            \(memoryText.isEmpty ? "İlgili önceki bağlam yok." : memoryText)

            Executor taslağı:
            \(draft)

            Verifier:
            \(verification.state.rawValue) — \(verification.summary)

            Kullanılamayan capability'ler:
            \(unavailableCapabilities.isEmpty ? "Yok" : unavailableCapabilities)

            Araştırma kanıtları:
            \(evidenceText.isEmpty ? "Bu turda web kanıtı yok." : evidenceText)

            Önceki bağlamı yalnızca gerçekten ilgiliyse kullan. Kullanıcının 'bu hesap', 'az önceki analiz', 'bunlardan' gibi referanslarını ilgili bağlamla çöz.
            Yukarıdaki bilgiye dayanarak kullanıcıya verilecek nihai cevabı üret.
            """

            do {
                let session = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )

                let response = try await session.respond(
                    to: prompt
                )

                let content = response.content
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                return content.isEmpty ? nil : content
            } catch {
                return nil
            }
        }
        #endif

        return nil
    }
}
