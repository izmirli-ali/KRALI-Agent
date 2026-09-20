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

    func planMission(
        userInput: String,
        contextMemory: [AgentContextMemoryEntry],
        capabilities: [AgentCapability],
        hasWorkspace: Bool
    ) async -> AgentSemanticMission? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
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

            let instructions = """
            Sen KRALİ'nin semantic mission planner katmanısın.
            Kullanıcının cümlesini anahtar kelime eşlemesiyle değil, gerçek dünyadaki nihai amacına göre yorumla.
            Görevi hedefe ulaşmak için gereken alt işlere böl.
            Her alt iş için yalnızca capability kataloğunda bulunan capabilityID değerlerinden birini seç.
            Kullanıcı açıkça söylemese bile hedef doğal olarak araştırma, dosya bulma, uygulama açma, düzenleme veya doğrulama gerektiriyorsa bunları plana ekle.
            Örnek: "son çekimle ilgili kurgu yapmamız gerekiyor" => son çekimleri bul, medyayı değerlendir, kurgu uygulamasında düzenle, sonucu doğrula.
            Örnek: "X markası için tasarım hazırlamak istiyorum" => markayı araştır, görsel standartları analiz et, tasarım uygulamasında üret, ekran sonucunu doğrula.
            Gereksiz soru sorma. Makul ve geri alınabilir varsayımla ilerlenebiliyorsa requiresUserInput=false yap.
            Ancak sonucu kökten değiştirecek zorunlu bilgi varsa ve güvenilir varsayım yapılamıyorsa requiresUserInput=true yap.
            Capability kullanılamıyor olsa bile görev için gerçekten gerekiyorsa requiredCapabilityIDs içine koy.
            Kullanıcı gerçek bir dijital çıktı, dosya, tasarım, kurgu, uygulama işlemi, web işlemi veya medya üzerinde çalışma istiyorsa yalnızca core.reasoning/context.local ile yetinme; hedefi gerçekten uygulayacak capability'leri ekle.
            Uygulama veya araç capability'si unavailable görünse bile görevin doğal olarak ihtiyacı varsa mission'a dahil et; availability planlama kararını bastırmamalı.
            Son adıma kadar düşün: yalnızca hazırlık/analiz değil, üretim/uygulama ve mümkünse sonucu doğrulama adımlarını da planla.
            Yerel dosya, mevcut bağlam ve uygulama capability'leriyle çözülebilecek bir görev için sırf genel bilgi toplamak amacıyla research.web ekleme. Web araştırmasını yalnızca hedef için dış/güncel/bilinmeyen bilgi gerçekten gerekiyorsa kullan.
            Marka özelindeki hafızayı başka markalara taşımayı önleyen kullanıcı kurallarına uy.
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

            Şu JSON şemasını döndür:
            {
              "objective": "kullanıcının nihai hedefi",
              "outcomes": ["locate", "research", "analyze", "compose", "edit", "explain"],
              "steps": [
                {
                  "title": "kısa adım adı",
                  "purpose": "bu adım neden gerekli",
                  "capabilityID": "catalogdaki.id",
                  "operation": "kısa makine işlemi etiketi",
                  "dependsOn": []
                }
              ],
              "requiredCapabilityIDs": ["catalogdaki.id"],
              "requiresUserInput": false,
              "userInputReason": null,
              "confidence": 0.0
            }

            Kurallar:
            - 2 ile 10 arası anlamlı step üret; gerçekten tek adımlı doğal konuşmada 1 step olabilir.
            - dependsOn dizisinde 0 tabanlı önceki step indekslerini kullan.
            - outcomes yalnızca şu değerlerden oluşsun: converse, locate, shortlist, assessContent, analyze, ideate, compose, transform, explain, organize, open, remember, research, edit, communicate.
            - Kullanıcının nihai sonucunu tanımlayan outcome'ları seç; araç isimlerini outcome olarak kullanma.
            - requiredCapabilityIDs, steps içinde kullanılan capabilityID'lerin tekilleştirilmiş listesini içersin.
            - confidence 0 ile 1 arasında olsun.
            """

            do {
                let session = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )

                let response = try await session.respond(to: prompt)
                let raw = response.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard let json = extractJSONObject(from: raw),
                      let data = json.data(using: .utf8),
                      let mission = try? JSONDecoder().decode(
                        AgentSemanticMission.self,
                        from: data
                      ) else {
                    return nil
                }

                let knownIDs = Set(capabilities.map(\.id))
                guard validateMission(
                    mission,
                    knownCapabilityIDs: knownIDs
                ) else {
                    return nil
                }

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]

                guard
                    let missionData = try? encoder.encode(mission),
                    let missionJSON = String(
                        data: missionData,
                        encoding: .utf8
                    )
                else {
                    return mission
                }

                let reviewPrompt = """
                İlk mission taslağını şimdi eleştirel olarak denetle.

                Orijinal kullanıcı mesajı:
                \(userInput)

                İlk mission:
                \(missionJSON)

                Capability kataloğu:
                \(capabilityCatalog)

                Denetim kuralları:
                - Mission kullanıcının nihai hedefini gerçekten uçtan uca tamamlıyor mu?
                - Kullanıcı bir gerçek dünya/dijital iş istiyorsa yalnızca reasoning/context adımları yeterli değildir.
                - Dosya bulma gerekiyorsa files.search/files.metadata ekle.
                - Medyanın içeriğini görmeden karar verilecekse perception.media ekle.
                - macOS uygulama açma/pencere/klavye/mouse etkileşimi gerekiyorsa desktop.control ekle.
                - Web arayüzünde gezinme veya oturumlu işlem gerekiyorsa browser.control ekle.
                - Premiere içinde gerçek kurgu gerekiyorsa premiere.control ekle.
                - Photoshop içinde gerçek tasarım gerekiyorsa photoshop.control ekle.
                - Ekrandaki sonucu görsel olarak kontrol etmek gerekiyorsa perception.screen ekle.
                - Marka/şirket hakkında güncel veya bilinmeyen bilgi gerekiyorsa research.web ekle.
                - Yerel dosya/kurgu gibi dış bilgi gerektirmeyen görevlerde gereksiz research.web ekleme.
                - Capability unavailable olsa bile görev gerektiriyorsa mission'a dahil et.
                - Gereksiz capability ekleme.
                - Gerekli adımları bağımlılık sırasına koy.
                - JSON dışında hiçbir şey döndürme.

                Aynı JSON şemasıyla düzeltilmiş mission'ı döndür.
                """

                let reviewedResponse = try await session.respond(
                    to: reviewPrompt
                )
                let reviewedRaw = reviewedResponse.content
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                if let reviewedJSON =
                    extractJSONObject(from: reviewedRaw),
                   let reviewedData =
                    reviewedJSON.data(using: .utf8),
                   let reviewedMission =
                    try? JSONDecoder().decode(
                        AgentSemanticMission.self,
                        from: reviewedData
                    ),
                   validateMission(
                        reviewedMission,
                        knownCapabilityIDs: knownIDs
                   ),
                   isOperationallyComplete(
                        reviewedMission
                   ) {
                    return reviewedMission
                }

                return isOperationallyComplete(mission)
                    ? mission
                    : nil
            } catch {
                return nil
            }
        }
        #endif

        return nil
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
            })
        else {
            return false
        }

        let allowedOutcomes = Set([
            "converse",
            "locate",
            "shortlist",
            "assessContent",
            "analyze",
            "ideate",
            "compose",
            "transform",
            "explain",
            "organize",
            "open",
            "remember",
            "research",
            "edit",
            "communicate"
        ])

        return mission.outcomes.allSatisfy {
            allowedOutcomes.contains($0)
        }
    }

    private func isOperationallyComplete(
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
                  ids.contains("browser.control")
            else {
                return false
            }
        }

        if outcomes.contains("assessContent") {
            guard ids.contains("perception.media") ||
                  ids.contains("perception.screen")
            else {
                return false
            }
        }

        if outcomes.contains("research") {
            guard ids.contains("research.web") ||
                  ids.contains("browser.control")
            else {
                return false
            }
        }

        if outcomes.contains("organize") {
            guard ids.contains("files.move.reversible") ||
                  ids.contains("desktop.control")
            else {
                return false
            }
        }

        if outcomes.contains("open") {
            guard ids.contains("files.reveal") ||
                  ids.contains("desktop.control") ||
                  ids.contains("browser.control")
            else {
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
                  ids.contains("browser.control")
            else {
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

    func reviewMission(
        userInput: String,
        mission: AgentSemanticMission,
        capabilities: [AgentCapability]
    ) async -> AgentMissionReview? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                return nil
            }

            let capabilityCatalog = capabilities
                .map {
                    "- \($0.id): \($0.summary) [\($0.isAvailable ? "available" : "unavailable")]"
                }
                .joined(separator: "\n")

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            guard
                let missionData = try? encoder.encode(mission),
                let missionJSON = String(
                    data: missionData,
                    encoding: .utf8
                )
            else {
                return nil
            }

            let instructions = """
            Sen KRALİ Arena'nın bağımsız Reviewer ajanısın.
            Planner değilsin; sana verilen mission'ı eleştiriyorsun.
            Kullanıcının gerçek hedefini uçtan uca tamamlayıp tamamlamadığını değerlendir.
            Capability unavailable olsa bile hedef için gerekiyorsa eksik say.
            Gereksiz tool/capability kullanımını da işaretle.
            Özellikle şu hataları ara:
            - Yerel dosya işi için gereksiz web araştırması
            - Gerçek kurgu/tasarım hedefinde uygulama provider'ının olmaması
            - Dosya bulma gereken işte files.search eksikliği
            - Medya içeriğini değerlendiren işte perception eksikliği
            - Uygulama sonucunu doğrulaması gereken işte perception.screen eksikliği
            - Yeni marka görevine alakasız eski marka bağlamı taşınması
            - Kullanıcıdan gereksiz bilgi isteme
            JSON dışında hiçbir metin üretme.
            """

            let prompt = """
            Kullanıcı isteği:
            \(userInput)

            Mission:
            \(missionJSON)

            Capability kataloğu:
            \(capabilityCatalog)

            Şu JSON şemasını döndür:
            {
              "passed": true,
              "summary": "kısa değerlendirme",
              "missingCapabilityIDs": [],
              "unnecessaryCapabilityIDs": [],
              "riskNotes": []
            }
            """

            do {
                let session = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )

                let response = try await session.respond(
                    to: prompt
                )
                let raw = response.content
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard let json = extractJSONObject(from: raw),
                      let data = json.data(using: .utf8),
                      let review = try? JSONDecoder().decode(
                        AgentMissionReview.self,
                        from: data
                      ) else {
                    return nil
                }

                let knownIDs = Set(capabilities.map(\.id))

                guard
                    review.missingCapabilityIDs.allSatisfy({
                        knownIDs.contains($0)
                    }),
                    review.unnecessaryCapabilityIDs.allSatisfy({
                        knownIDs.contains($0)
                    })
                else {
                    return nil
                }

                return review
            } catch {
                return nil
            }
        }
        #endif

        return nil
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
            - Kullanıcı mevcut bir fikri/çıktıyı senaryoya, çekim planına, metne veya başka bir formata "çevir / dönüştür / uyarla" diyorsa yeni alternatif fikir listesi üretme. Referans verdiği tek öğeyi seç ve istenen süre, sayı, sıra ve formata sadık biçimde dönüştür.
            - Kullanıcı doğrudan yeni bir içerik, çekim planı, senaryo, caption veya metin hazırlamanı istiyorsa bunu bir dosya arama görevi gibi yorumlama; belirtilen süre, bölüm sayısı, ton ve biçim kısıtlarını eksiksiz uygula.
            - Kullanıcı bir metni tırnak içinde veya mesajın içinde verip "yeniden yaz / düzelt / düzgün Türkçeyle yaz" diyorsa kaynak olarak yalnızca verilen metni esas al; alakasız önceki bağlamı cevaba karıştırma ve düzeltilmiş metni doğrudan ver.
            - "Birincisini", "ikincisini", "sonuncusunu" gibi seçim ifadelerini önceki bağlamdaki ilgili öğe sırasına göre çöz.
            - Gerçek kaynak kanıtı ile kendi çıkarımını birbirinden ayır.
            - Kanıtta olmayan somut bilgileri uydurma.
            - Eksik veya kullanılamayan capability varsa, o işi gerçekten yapmış gibi konuşma.
            - Araştırma sonucunda çelişki veya belirsizlik varsa açıkça belirt.
            - Türkçe yazım, ek kullanımı ve noktalama açısından cevabı göndermeden önce sessizce kontrol et; bariz yazım hatalarını düzelt.
            - "şuan", "birşey", "yada", "yanlız", "herkez", "kapanışda" gibi hatalı biçimleri kullanma; doğal Türkiye Türkçesi yaz.
            - Uzun yanıtlarda kısa başlıklar ve maddeler kullan. Başlıkları veya önemli etiketleri **kalın**, açıklamaları normal ağırlıkta bırak; tüm paragrafı kalın yazma.
            - Gereksiz "Hedef / Çözüm / Fırsat / Risk / Belirsizlik" şablonunu mekanik biçimde tekrar etme; yalnızca kullanıcıya gerçekten yardımcıysa kullan.
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
