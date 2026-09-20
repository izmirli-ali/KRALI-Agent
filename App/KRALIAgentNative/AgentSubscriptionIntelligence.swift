import Foundation

struct SubscriptionIntelligenceResult: Sendable {
    let text: String
    let provider: String
}

actor AgentSubscriptionIntelligence {
    private let fileManager = FileManager.default

    func synthesize(
        userInput: String,
        goal: String,
        draft: String,
        verification: AgentVerificationResult,
        capabilities: [AgentCapability],
        researchEvidence: [WebSourceEvidence]
    ) async -> SubscriptionIntelligenceResult? {
        guard let clinePath = clineExecutablePath() else {
            return nil
        }

        let workspace = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Intelligence",
                isDirectory: true
            )

        do {
            try fileManager.createDirectory(
                at: workspace,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }

        let unavailableCapabilities = capabilities
            .filter { !$0.isAvailable }
            .map(\.name)
            .joined(separator: ", ")

        let evidenceText = researchEvidence
            .prefix(8)
            .enumerated()
            .map { index, evidence in
                """
                [\(index + 1)] \(evidence.source.title)
                Domain: \(evidence.source.domain)
                URL: \(evidence.source.url.absoluteString)
                Kanıt: \(String(evidence.excerpt.prefix(1600)))
                """
            }
            .joined(separator: "\n\n")

        let systemPrompt = """
        Sen KRALİ'nin yalnızca cevap sentezi yapan reasoning katmanısın.
        Araç kullanma, dosya okuma/yazma, shell komutu veya web çağrısı yapma.
        Sana verilen kullanıcı isteği, doğrulanmış kaynak kanıtları ve executor taslağından doğrudan son kullanıcı cevabı üret.
        Türkçe yaz.

        Kurallar:
        - Kaynakta olmayan somut bilgiyi gerçekmiş gibi uydurma.
        - Araştırma kanıtı ile kendi çıkarımını açıkça ayır.
        - Kullanıcı analiz istiyorsa yalnızca özetleme yapma; neden-sonuç, güçlü/zayıf yön, risk, fırsat ve belirsizlik çıkar.
        - Kullanıcı özgün fikir/fırsat istiyorsa istediği sayıya uymaya çalış ve her fikri kanıt/çıkarımla gerekçelendir.
        - Rakip, ürün, tarihçe veya güncel durum için kanıt yetersizse bunu açıkça söyle; boşluğu tahminle doldurma.
        - Aynı haberi tekrar eden kaynakları bağımsız doğrulama gibi sunma.
        - Cevabın sonunda kullandığın kaynakları kısa bir "Kaynaklar" bölümünde [1], [2] biçiminde göster.
        - Kullanıcının hedefini doğrudan cevapla; iç çalışma planını anlatma.
        """

        let prompt = """
        Kullanıcı isteği:
        \(userInput)

        Hedef sözleşmesi:
        \(goal)

        Executor taslağı:
        \(draft)

        Araç doğrulaması:
        \(verification.state.rawValue) — \(verification.summary)

        Kullanılamayan capability'ler:
        \(unavailableCapabilities.isEmpty ? "Yok" : unavailableCapabilities)

        Doğrulanmış kaynak kanıtları:
        \(evidenceText.isEmpty ? "Bu turda doğrulanmış web kanıtı yok." : evidenceText)

        Şimdi yalnızca kullanıcıya verilecek nihai cevabı üret.
        """

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(
            fileURLWithPath: clinePath
        )
        process.arguments = [
            "--json",
            "--auto-approve", "false",
            "--provider", "openai-codex",
            "--thinking", "medium",
            "--retries", "1",
            "--timeout", "150",
            "--cwd", workspace.path,
            "--system", systemPrompt,
            prompt
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] =
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["CLINE_COMMAND_PERMISSIONS"] =
            #"{"allow":[],"deny":["*"],"allowRedirects":false}"#
        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let outputData = outputPipe.fileHandleForReading
            .readDataToEndOfFile()

        guard let rawOutput = String(
            data: outputData,
            encoding: .utf8
        ) else {
            return nil
        }

        guard let text = finalText(
            fromNDJSON: rawOutput
        ) else {
            return nil
        }

        return SubscriptionIntelligenceResult(
            text: text,
            provider: "ChatGPT Subscription / openai-codex"
        )
    }

    private func clineExecutablePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/cline",
            "/usr/local/bin/cline"
        ]

        return candidates.first {
            fileManager.isExecutableFile(
                atPath: $0
            )
        }
    }

    private func finalText(
        fromNDJSON output: String
    ) -> String? {
        var candidates: [String] = []

        for line in output.split(separator: "\n") {
            guard
                let data = String(line).data(
                    using: .utf8
                ),
                let object = try? JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]
            else {
                continue
            }

            if let partial = object["partial"] as? Bool,
               partial {
                continue
            }

            if let type = object["type"] as? String,
               type == "say",
               let text = object["text"] as? String {
                appendCandidate(
                    text,
                    to: &candidates
                )
            }

            if let event = object["event"] as? [String: Any],
               let text = event["text"] as? String {
                appendCandidate(
                    text,
                    to: &candidates
                )
            }
        }

        return candidates
            .last?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func appendCandidate(
        _ text: String,
        to candidates: inout [String]
    ) {
        let cleaned = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleaned.count >= 40 else {
            return
        }

        candidates.append(cleaned)
    }
}
