import Foundation

struct SubscriptionIntelligenceResult: Sendable {
    let text: String
    let provider: String
}

struct SubscriptionMissionResult: Sendable {
    let mission: AgentSemanticMission
    let provider: String
}

actor AgentSubscriptionIntelligence {
    private let fileManager = FileManager.default
    private var failureReason: String?

    func lastFailureReason() -> String? {
        failureReason
    }

    func planMission(
        userInput: String,
        contextMemory: [AgentContextMemoryEntry],
        capabilities: [AgentCapability],
        hasWorkspace: Bool
    ) async -> SubscriptionMissionResult? {
        failureReason = nil

        guard let clinePath = clineExecutablePath() else {
            failureReason = "Semantic planner fallback için Cline CLI bulunamadı."
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
            failureReason =
                "Semantic planner çalışma alanı hazırlanamadı: " +
                error.localizedDescription
            return nil
        }

        let capabilityCatalog = capabilities
            .map {
                "- \($0.id): \($0.summary) [\($0.isAvailable ? "available" : "unavailable")]"
            }
            .joined(separator: "\n")

        let memoryText = contextMemory
            .prefix(5)
            .map {
                "[\($0.kind.rawValue)] \($0.title): \($0.summary)"
            }
            .joined(separator: "\n")

        let systemPrompt = """
        Sen KRALİ'nin semantic mission planner fallback katmanısın.
        Araç kullanma, shell komutu çalıştırma, dosya değiştirme veya web çağrısı yapma.
        Yalnızca verilen kullanıcı isteğinden yapılandırılmış görev mission'ı üret.

        Amaç:
        - Kullanıcının söylediği yüzey cümlesini değil, ulaşmak istediği gerçek dünya sonucunu anla.
        - Görevi uçtan uca tamamlayacak alt adımları çıkar.
        - Kullanıcı tek tek araç söylemese bile gereken capability'leri kendin seç.
        - Capability unavailable olsa bile hedef için gerekliyse plana dahil et.
        - Yalnızca hazırlık/analizde durma; gerekiyorsa gerçek uygulama/üretim ve sonuç doğrulamasını da planla.
        - Yeni marka/şirket/işletmeye eski başka bir markanın task/research bağlamını taşıma.
        - Makul ve geri alınabilir varsayımla ilerlenebiliyorsa kullanıcıdan gereksiz bilgi isteme.

        Capability rehberi:
        - Yerel dosya bulma: files.search + gerektiğinde files.metadata
        - Medya içeriğini görme/değerlendirme: perception.media
        - Ekrandaki sonucu görme: perception.screen
        - macOS uygulama/pencere/klavye/mouse: desktop.control
        - Web araştırması: research.web
        - Etkileşimli web gezinme/oturum: browser.control
        - Premiere içinde gerçek kurgu: premiere.control
        - Photoshop içinde gerçek tasarım: photoshop.control
        - Mail işi: mail.work
        - Yerel bağlam: context.local
        - Akıl yürütme: core.reasoning

        Gerçek bir edit/tasarım/kurgu işi sadece core.reasoning ile tamamlanmış sayılmaz.
        JSON dışında hiçbir metin üretme.
        """

        let prompt = """
        Kullanıcı mesajı:
        \(userInput)

        Çalışma alanı bağlı mı:
        \(hasWorkspace ? "evet" : "hayır")

        İlgili hafıza:
        \(memoryText.isEmpty ? "Yok" : memoryText)

        Capability kataloğu:
        \(capabilityCatalog)

        Şu JSON şemasını eksiksiz döndür:
        {
          "objective": "kullanıcının nihai hedefi",
          "outcomes": ["locate", "research", "analyze", "compose", "edit", "explain"],
          "steps": [
            {
              "title": "kısa adım adı",
              "purpose": "neden gerekli",
              "capabilityID": "catalogdaki.id",
              "operation": "kısa işlem etiketi",
              "dependsOn": []
            }
          ],
          "requiredCapabilityIDs": ["catalogdaki.id"],
          "requiresUserInput": false,
          "userInputReason": null,
          "confidence": 0.0
        }

        Outcomes yalnızca şunlardan olabilir:
        converse, locate, shortlist, assessContent, analyze, ideate, compose, transform, explain, organize, open, remember, research, edit, communicate.

        1-10 arası anlamlı step üret. dependsOn 0 tabanlı önceki step indeksleridir.
        """

        let process = Process()
        let outputURL = workspace.appendingPathComponent(
            "cline-semantic-mission-output.ndjson",
            isDirectory: false
        )

        fileManager.createFile(
            atPath: outputURL.path,
            contents: nil
        )

        guard let outputHandle = try? FileHandle(
            forWritingTo: outputURL
        ) else {
            failureReason =
                "Semantic planner çıktı dosyası açılamadı."
            return nil
        }

        process.executableURL = URL(
            fileURLWithPath: clinePath
        )
        process.arguments = [
            "--json",
            "--auto-approve", "true",
            "--provider", "openai-codex",
            "--thinking", "medium",
            "--retries", "1",
            "--timeout", "150",
            "--cwd", workspace.path,
            "--system", systemPrompt,
            prompt
        ]
        process.standardOutput = outputHandle
        process.standardError = outputHandle

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] =
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["CLINE_COMMAND_PERMISSIONS"] =
            #"{"allow":[],"deny":["*"],"allowRedirects":false}"#
        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()
            try? outputHandle.close()
        } catch {
            try? outputHandle.close()
            failureReason =
                "Semantic planner fallback başlatılamadı: " +
                error.localizedDescription
            return nil
        }

        let rawOutput = (
            try? String(
                contentsOf: outputURL,
                encoding: .utf8
            )
        ) ?? ""

        try? fileManager.removeItem(at: outputURL)

        guard process.terminationStatus == 0 else {
            failureReason =
                "Semantic planner fallback hata kodu " +
                String(process.terminationStatus) +
                ": " +
                String(rawOutput.suffix(1200))
            return nil
        }

        guard
            let final = finalText(fromNDJSON: rawOutput),
            let json = extractJSONObject(from: final),
            let data = json.data(using: .utf8),
            let mission = try? JSONDecoder().decode(
                AgentSemanticMission.self,
                from: data
            ),
            validateMission(
                mission,
                knownCapabilityIDs:
                    Set(capabilities.map(\.id))
            )
        else {
            failureReason =
                "Semantic planner fallback geçerli mission JSON üretmedi."
            return nil
        }

        failureReason = nil
        return SubscriptionMissionResult(
            mission: mission,
            provider:
                "ChatGPT Subscription / openai-codex"
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
    ) async -> SubscriptionIntelligenceResult? {
        failureReason = nil

        guard let clinePath = clineExecutablePath() else {
            failureReason = "Cline CLI bulunamadı."
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
            failureReason =
                "Sentez çalışma alanı hazırlanamadı: " +
                error.localizedDescription
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
            .joined(separator: "\n\n")

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
        - Kullanıcı mevcut bir fikri/çıktıyı "çevir / dönüştür / uyarla" diyorsa yeni alternatifler icat etme. Referans verdiği öğeyi önceki bağlamdan seç ve istenen süre, sayı, sıra ve formatta dönüştür.
        - Kullanıcı doğrudan yeni bir içerik, çekim planı, senaryo, caption veya metin hazırlamanı istiyorsa bunu bir araç/dosya görevi gibi yorumlama; verilen süre, bölüm sayısı, ton ve biçim kısıtlarını uygula.
        - Kullanıcı metni doğrudan mesaj içinde verip "yeniden yaz / düzelt / düzgün Türkçeyle yaz" diyorsa kaynak olarak yalnızca verilen metni esas al; alakasız önceki bağlamı cevaba karıştırma ve düzeltilmiş metni doğrudan ver.
        - "Birincisini", "ikincisini", "sonuncusunu" gibi seçimleri önceki bağlamdaki öğe sırasına göre çöz.
        - Rakip, ürün, tarihçe veya güncel durum için kanıt yetersizse bunu açıkça söyle; boşluğu tahminle doldurma.
        - Aynı haberi tekrar eden kaynakları bağımsız doğrulama gibi sunma.
        - Takipçi sayısı, gönderi sayısı, fiyat, stok gibi hızlı değişen canlı metrikleri yalnızca kanıtta açıkça mevcutsa sayı olarak ver. Güncel değer doğrulanamıyorsa bunu net söyle ve tahmin etme.
        - Sosyal medya hesabı araştırmasında doğrulanabilen profil kimliği, içerik türleri ve sonuca dair belirsizlikleri ayrı belirt.
        - Cevabın sonunda kullandığın kaynakları kısa bir "Kaynaklar" bölümünde [1], [2] biçiminde göster.
        - Kullanıcının hedefini doğrudan cevapla; iç çalışma planını anlatma.
        - Türkçe yazım, ek kullanımı ve noktalama açısından cevabı göndermeden önce sessizce kontrol et; bariz yazım hatalarını düzelt.
        - "şuan", "birşey", "yada", "yanlız", "herkez", "kapanışda" gibi hatalı biçimleri kullanma; doğal Türkiye Türkçesi yaz.
        - Uzun yanıtlarda kısa başlıklar ve maddeler kullan. Başlıkları veya önemli etiketleri **kalın**, açıklamaları normal ağırlıkta bırak; tüm paragrafı kalın yazma.
        - Gereksiz "Hedef / Çözüm / Fırsat / Risk / Belirsizlik" şablonunu mekanik biçimde tekrar etme; yalnızca gerçekten faydalıysa kullan.
        - Kullanıcı "bu hesap", "bu marka", "az önceki analiz", "bunlardan" gibi referanslar kullanıyorsa yalnızca verilen önceki ilgili bağlamla çöz; bağlamda olmayan şeyi uydurma.
        - Yeni araştırma kanıtı yoksa fakat ilgili önceki bağlam varsa, gereksiz yeniden araştırma yapmadan o bağlam üzerinden devam edebilirsin.
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

        Araç doğrulaması:
        \(verification.state.rawValue) — \(verification.summary)

        Kullanılamayan capability'ler:
        \(unavailableCapabilities.isEmpty ? "Yok" : unavailableCapabilities)

        Doğrulanmış kaynak kanıtları:
        \(evidenceText.isEmpty ? "Bu turda doğrulanmış web kanıtı yok." : evidenceText)

        Şimdi yalnızca kullanıcıya verilecek nihai cevabı üret.
        """

        let process = Process()
        let outputURL = workspace.appendingPathComponent(
            "cline-synthesis-output.ndjson",
            isDirectory: false
        )

        fileManager.createFile(
            atPath: outputURL.path,
            contents: nil
        )

        guard let outputHandle = try? FileHandle(
            forWritingTo: outputURL
        ) else {
            failureReason = "Cline çıktı dosyası açılamadı."
            return nil
        }

        process.executableURL = URL(
            fileURLWithPath: clinePath
        )
        process.arguments = [
            "--json",
            "--auto-approve", "true",
            "--provider", "openai-codex",
            "--thinking", "medium",
            "--retries", "1",
            "--timeout", "150",
            "--cwd", workspace.path,
            "--system", systemPrompt,
            prompt
        ]
        process.standardOutput = outputHandle
        process.standardError = outputHandle

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] =
            "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["CLINE_COMMAND_PERMISSIONS"] =
            #"{"allow":[],"deny":["*"],"allowRedirects":false}"#
        process.environment = environment

        do {
            try process.run()
            process.waitUntilExit()
            try? outputHandle.close()
        } catch {
            try? outputHandle.close()
            failureReason =
                "Cline başlatılamadı: " +
                error.localizedDescription
            return nil
        }

        let rawOutput = (
            try? String(
                contentsOf: outputURL,
                encoding: .utf8
            )
        ) ?? ""

        try? fileManager.removeItem(
            at: outputURL
        )

        guard process.terminationStatus == 0 else {
            let tail = String(
                rawOutput.suffix(1400)
            )
            failureReason =
                "Cline sentez süreci hata kodu " +
                String(process.terminationStatus) +
                (tail.isEmpty ? "." : ": " + tail)
            return nil
        }

        guard let text = finalText(
            fromNDJSON: rawOutput
        ) else {
            failureReason =
                "Cline tamamlandı ancak kullanılabilir nihai metin üretmedi."
            return nil
        }

        failureReason = nil

        return SubscriptionIntelligenceResult(
            text: text,
            provider: "ChatGPT Subscription / openai-codex"
        )
    }

    private func validateMission(
        _ mission: AgentSemanticMission,
        knownCapabilityIDs: Set<String>
    ) -> Bool {
        guard
            !mission.objective.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            !mission.steps.isEmpty,
            mission.steps.count <= 10,
            mission.steps.allSatisfy({
                knownCapabilityIDs.contains(
                    $0.capabilityID
                )
            }),
            mission.requiredCapabilityIDs.allSatisfy({
                knownCapabilityIDs.contains($0)
            }),
            mission.confidence >= 0,
            mission.confidence <= 1
        else {
            return false
        }

        let allowedOutcomes = Set([
            "converse", "locate", "shortlist",
            "assessContent", "analyze", "ideate",
            "compose", "transform", "explain",
            "organize", "open", "remember",
            "research", "edit", "communicate"
        ])

        return mission.outcomes.allSatisfy {
            allowedOutcomes.contains($0)
        }
    }

    private func extractJSONObject(
        from raw: String
    ) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start <= end else {
            return nil
        }

        return String(raw[start...end])
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
