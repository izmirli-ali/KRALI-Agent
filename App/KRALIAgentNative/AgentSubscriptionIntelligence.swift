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
    private var localPlannerFailureReason: String?
    private var ollamaServeProcess: Process?

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
        localPlannerFailureReason = nil

        if let localMission =
            await planMissionWithLocalOllama(
                userInput: userInput,
                contextMemory: contextMemory,
                capabilities: capabilities,
                hasWorkspace: hasWorkspace
            ) {
            failureReason = nil
            return localMission
        }

        guard let clinePath = clineExecutablePath() else {
            failureReason =
                (localPlannerFailureReason.map {
                    "Local planner: " + $0 + " • "
                } ?? "") +
                "Semantic planner fallback için Cline CLI bulunamadı."
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
        - Yerel dosya ve uygulama capability'leriyle çözülebilen görevlerde gereksiz research.web ekleme. Yalnızca dış/güncel/bilinmeyen bilgi gerçekten gerekiyorsa araştırma planla.
        - Kullanıcı yalnızca bilgi, açıklama, fikir veya genel uzmanlık cevabı istiyorsa ve güncel/dış/özel kaynak gerekmiyorsa core.reasoning + gerektiğinde context.local ile kal; dosya, ekran, uygulama, web veya edit capability'si uydurma.
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
            "--plan",
            "--auto-approve", "true",
            "--provider", "openai-codex",
            "--thinking", "medium",
            "--retries", "1",
            "--timeout", "90",
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

        let clineStartedAt = Date()

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

        let diagnosticURL =
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Logs/KRALI-Semantic-Planner.log",
                    isDirectory: false
                )

        let clineDurationSeconds =
            Date().timeIntervalSince(
                clineStartedAt
            )

        let clineTerminationReason: String
        switch process.terminationReason {
        case .exit:
            clineTerminationReason = "exit"
        case .uncaughtSignal:
            clineTerminationReason = "uncaughtSignal"
        @unknown default:
            clineTerminationReason = "unknown"
        }

        if process.terminationStatus != 0 {
            let diagnostic = """
            \n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            KRALİ Semantic Planner Fallback
            status=\(process.terminationStatus)
            reason=\(clineTerminationReason)
            duration=\(String(format: "%.2f", clineDurationSeconds))s
            executable=\(clinePath)
            input=\(userInput)
            output:
            \(rawOutput)
            """

            if let data = diagnostic.data(using: .utf8) {
                if !fileManager.fileExists(
                    atPath: diagnosticURL.path
                ) {
                    fileManager.createFile(
                        atPath: diagnosticURL.path,
                        contents: data
                    )
                } else if let handle = try? FileHandle(
                    forWritingTo: diagnosticURL
                ) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            }
        }

        try? fileManager.removeItem(at: outputURL)

        guard process.terminationStatus == 0 else {
            let tail = String(
                rawOutput.suffix(1200)
            )
            failureReason =
                (localPlannerFailureReason.map {
                    "Local planner: " + $0 + " • "
                } ?? "") +
                "Semantic planner Cline başarısız • " +
                clineTerminationReason +
                "=" +
                String(process.terminationStatus) +
                " • süre=" +
                String(
                    format: "%.2f",
                    clineDurationSeconds
                ) +
                "sn" +
                (tail.isEmpty
                    ? " • ayrıntı: ~/Library/Logs/KRALI-Semantic-Planner.log"
                    : ": " + tail)
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
            ),
            missionCoverageIsValid(mission)
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

    private func planMissionWithLocalOllama(
        userInput: String,
        contextMemory: [AgentContextMemoryEntry],
        capabilities: [AgentCapability],
        hasWorkspace: Bool
    ) async -> SubscriptionMissionResult? {
        appendPlannerDiagnostic(
            "local.stage=ollama_check"
        )

        guard
            await ensureOllamaServiceReady()
        else {
            localPlannerFailureReason =
                "Ollama servisi hazır değil"
            appendPlannerDiagnostic(
                "local.failure=service_unavailable"
            )
            return nil
        }

        appendPlannerDiagnostic(
            "local.stage=service_ready"
        )

        guard
            let model =
                await availableLocalPlannerModel()
        else {
            localPlannerFailureReason =
                "Kurulu uygun Ollama modeli bulunamadı"
            appendPlannerDiagnostic(
                "local.failure=model_missing"
            )
            return nil
        }

        appendPlannerDiagnostic(
            "local.stage=model_found model=" +
            model
        )

        let capabilityCatalog =
            capabilities.map {
                "- \($0.id): \($0.summary) [\($0.isAvailable ? "available" : "unavailable")]"
            }
            .joined(separator: "\n")

        let memoryText =
            contextMemory.prefix(5).map {
                "[\($0.kind.rawValue)] \($0.title): \($0.summary)"
            }
            .joined(separator: "\n")

        let systemPrompt = """
        Sen KRALİ'nin yerel semantic mission planner katmanısın.
        Araç çalıştırma. Yalnızca JSON mission üret.

        Kurallar:
        - Güncel kullanıcı mesajı nihai hedeftir.
        - Kullanıcı yalnızca bilgi, açıklama, fikir veya genel uzmanlık cevabı istiyorsa ve güncel/dış/özel kaynak gerekmiyorsa yalnız core.reasoning ve gerekirse context.local kullan.
        - Dosya, ekran, uygulama, web veya edit capability'lerini yalnız başarı için gerçekten zorunluysa seç.
        - Kullanıcının istemediği dış durum değişikliğini plana ekleme.
        - Eski bağlamı yalnız güncel hedefle gerçekten ilgiliyse kullan.
        - Capability unavailable olsa bile gerçek görev için zorunluysa plana dahil edebilirsin.
        - Gerçek edit/tasarım/kurgu işi sadece core.reasoning ile tamamlanmış sayılmaz.
        - JSON dışında hiçbir metin üretme.
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

        Yalnız şu şemada JSON döndür:
        {
          "objective": "kullanıcının nihai hedefi",
          "outcomes": ["explain"],
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

        guard
            let url = URL(
                string:
                    "http://127.0.0.1:11434/api/chat"
            )
        else {
            localPlannerFailureReason =
                "Ollama chat URL oluşturulamadı"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "format": "json",
            "options": [
                "temperature": 0.1
            ],
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        guard
            let body = try?
                JSONSerialization.data(
                    withJSONObject: payload
                )
        else {
            localPlannerFailureReason =
                "Ollama request JSON oluşturulamadı"
            appendPlannerDiagnostic(
                "local.failure=request_encoding"
            )
            return nil
        }

        request.httpBody = body
        appendPlannerDiagnostic(
            "local.stage=request_started model=" +
            model
        )

        let startedAt = Date()

        do {
            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            let duration =
                Date().timeIntervalSince(startedAt)

            guard
                let http =
                    response as?
                        HTTPURLResponse
            else {
                localPlannerFailureReason =
                    "Ollama HTTP yanıtı çözülemedi"
                appendPlannerDiagnostic(
                    "local.failure=response_type duration=" +
                    String(
                        format: "%.2f",
                        duration
                    ) +
                    "s"
                )
                return nil
            }

            guard http.statusCode == 200 else {
                localPlannerFailureReason =
                    "Ollama HTTP " +
                    String(http.statusCode)
                appendPlannerDiagnostic(
                    "local.failure=http_status status=" +
                    String(http.statusCode) +
                    " duration=" +
                    String(
                        format: "%.2f",
                        duration
                    ) +
                    "s"
                )
                return nil
            }

            appendPlannerDiagnostic(
                "local.stage=response_received duration=" +
                String(
                    format: "%.2f",
                    duration
                ) +
                "s"
            )

            guard
                let object =
                    try JSONSerialization
                        .jsonObject(
                            with: data
                        ) as? [String: Any],
                let message =
                    object["message"]
                        as? [String: Any],
                let content =
                    message["content"]
                        as? String
            else {
                localPlannerFailureReason =
                    "Ollama yanıt gövdesi çözülemedi"
                appendPlannerDiagnostic(
                    "local.failure=response_decode"
                )
                return nil
            }

            guard
                let json =
                    extractJSONObject(
                        from: content
                    ),
                let missionData =
                    json.data(using: .utf8),
                let mission =
                    try? JSONDecoder().decode(
                        AgentSemanticMission.self,
                        from: missionData
                    )
            else {
                localPlannerFailureReason =
                    "Ollama geçerli mission JSON üretmedi"
                let preview =
                    String(
                        content
                            .replacingOccurrences(
                                of: "\n",
                                with: " "
                            )
                            .prefix(500)
                    )
                appendPlannerDiagnostic(
                    "local.failure=json_invalid preview=" +
                    preview
                )
                return nil
            }

            guard
                validateMission(
                    mission,
                    knownCapabilityIDs:
                        Set(
                            capabilities.map(\.id)
                        )
                )
            else {
                localPlannerFailureReason =
                    "Ollama mission schema validation reddedildi"
                appendPlannerDiagnostic(
                    "local.failure=schema_validation objective=" +
                    mission.objective
                )
                return nil
            }

            guard missionCoverageIsValid(mission)
            else {
                localPlannerFailureReason =
                    "Ollama mission capability coverage reddedildi"
                appendPlannerDiagnostic(
                    "local.failure=coverage_validation outcomes=" +
                    mission.outcomes.joined(
                        separator: ","
                    )
                )
                return nil
            }

            localPlannerFailureReason = nil
            appendPlannerDiagnostic(
                "local.stage=json_validated provider=Local Ollama/" +
                model
            )

            return SubscriptionMissionResult(
                mission: mission,
                provider:
                    "Local Ollama / " +
                    model
            )
        } catch {
            localPlannerFailureReason =
                "Ollama request hatası: " +
                error.localizedDescription
            appendPlannerDiagnostic(
                "local.failure=request_exception error=" +
                error.localizedDescription
            )
            return nil
        }
    }

    private func ensureOllamaServiceReady()
        async -> Bool {
        if await ollamaServiceResponds() {
            return true
        }

        appendPlannerDiagnostic(
            "local.stage=service_start_requested"
        )

        guard
            ollamaServeProcess == nil ||
            ollamaServeProcess?.isRunning == false,
            let executable =
                ollamaExecutablePath()
        else {
            appendPlannerDiagnostic(
                "local.failure=ollama_binary_missing_or_running"
            )
            return false
        }

        let logURL =
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Logs/KRALI-Ollama.log",
                    isDirectory: false
                )

        fileManager.createFile(
            atPath: logURL.path,
            contents: nil
        )

        guard
            let logHandle = try?
                FileHandle(
                    forWritingTo: logURL
                )
        else {
            appendPlannerDiagnostic(
                "local.failure=ollama_log_open"
            )
            return false
        }

        let process = Process()
        process.executableURL =
            URL(fileURLWithPath: executable)
        process.arguments = ["serve"]
        process.standardOutput = logHandle
        process.standardError = logHandle

        do {
            try process.run()
            ollamaServeProcess = process
        } catch {
            try? logHandle.close()
            appendPlannerDiagnostic(
                "local.failure=ollama_start error=" +
                error.localizedDescription
            )
            return false
        }

        for attempt in 1...12 {
            try? await Task.sleep(
                nanoseconds: 500_000_000
            )

            if await ollamaServiceResponds() {
                appendPlannerDiagnostic(
                    "local.stage=service_started attempt=" +
                    String(attempt)
                )
                return true
            }
        }

        appendPlannerDiagnostic(
            "local.failure=service_start_timeout"
        )
        return false
    }

    private func ollamaServiceResponds()
        async -> Bool {
        guard
            let url = URL(
                string:
                    "http://127.0.0.1:11434/api/tags"
            )
        else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        do {
            let (_, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as?
                        HTTPURLResponse
            else {
                return false
            }

            return http.statusCode == 200
        } catch {
            return false
        }
    }

    private func availableLocalPlannerModel()
        async -> String? {
        guard
            let url = URL(
                string:
                    "http://127.0.0.1:11434/api/tags"
            )
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5

        do {
            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as?
                        HTTPURLResponse,
                http.statusCode == 200,
                let object =
                    try JSONSerialization
                        .jsonObject(
                            with: data
                        ) as? [String: Any],
                let models =
                    object["models"]
                        as? [[String: Any]]
            else {
                return nil
            }

            let names = Set(
                models.compactMap {
                    $0["name"] as? String
                }
            )

            appendPlannerDiagnostic(
                "local.models=" +
                names.sorted()
                    .joined(separator: ",")
            )

            let preferred = [
                "devstral:24b",
                "qwen3:8b",
                "qwen2.5-coder:14b-instruct",
                "qwen2.5-coder:7b-instruct",
                "qwen3-coder:30b"
            ]

            return preferred.first {
                names.contains($0)
            }
        } catch {
            appendPlannerDiagnostic(
                "local.failure=model_list error=" +
                error.localizedDescription
            )
            return nil
        }
    }

    private func ollamaExecutablePath()
        -> String? {
        let candidates = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama"
        ]

        return candidates.first {
            fileManager.isExecutableFile(
                atPath: $0
            )
        }
    }

    private func appendPlannerDiagnostic(
        _ line: String
    ) {
        let diagnosticURL =
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Logs/KRALI-Semantic-Planner.log",
                    isDirectory: false
                )

        let entry =
            "\n[\(ISO8601DateFormatter().string(from: Date()))] " +
            line +
            "\n"

        guard
            let data = entry.data(
                using: .utf8
            )
        else {
            return
        }

        if !fileManager.fileExists(
            atPath: diagnosticURL.path
        ) {
            fileManager.createFile(
                atPath: diagnosticURL.path,
                contents: data
            )
            return
        }

        guard
            let handle = try?
                FileHandle(
                    forWritingTo:
                        diagnosticURL
                )
        else {
            return
        }

        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.close()
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

    private func missionCoverageIsValid(
        _ mission: AgentSemanticMission
    ) -> Bool {
        let ids = Set(
            mission.requiredCapabilityIDs +
            mission.steps.map(\.capabilityID)
        )
        let outcomes = Set(mission.outcomes)

        if outcomes.contains("locate") ||
           outcomes.contains("shortlist") {
            guard ids.contains("files.search") ||
                  ids.contains("browser.control") else {
                return false
            }
        }

        if outcomes.contains("assessContent") {
            guard ids.contains("perception.media") ||
                  ids.contains("perception.screen") else {
                return false
            }
        }

        if outcomes.contains("research") {
            guard ids.contains("research.web") ||
                  ids.contains("browser.control") else {
                return false
            }
        }

        if outcomes.contains("edit") {
            let editProviders = Set([
                "premiere.control",
                "photoshop.control",
                "desktop.control",
                "files.move.reversible"
            ])

            guard !ids.intersection(editProviders).isEmpty else {
                return false
            }
        }

        if outcomes.contains("communicate") {
            guard ids.contains("mail.work") ||
                  ids.contains("browser.control") else {
                return false
            }
        }

        return true
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
