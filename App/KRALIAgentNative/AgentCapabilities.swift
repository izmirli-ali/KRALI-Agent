import Foundation

enum AgentCapabilityRisk: String, Hashable {
    case reasoning
    case readOnly
    case reversibleWrite
    case external
}

struct AgentCapability: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let risk: AgentCapabilityRisk
    let isAvailable: Bool
    let requiresWorkspace: Bool
}

struct AgentCapabilityRegistry {
    let all: [AgentCapability] = [
        AgentCapability(
            id: "core.reasoning",
            name: "Akıl yürütme",
            summary: "Hedef, kısıt, alternatif ve sonuç ilişkisini işler.",
            risk: .reasoning,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "context.local",
            name: "Bağlam",
            summary: "Aktif konuşma, ilgili önceki görevler, son sonuçlar ve çalışma alanı bağlamını taşır.",
            risk: .reasoning,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "files.search",
            name: "Dosya arama",
            summary: "Seçili çalışma alanını salt-okunur tarar ve filtreler.",
            risk: .readOnly,
            isAvailable: true,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "files.metadata",
            name: "Dosya metadata",
            summary: "Dosya türü, yol ve tarih bilgilerini değerlendirir.",
            risk: .readOnly,
            isAvailable: true,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "files.reveal",
            name: "Finder",
            summary: "Çözülen dosya veya klasörü Finder'da gösterir.",
            risk: .readOnly,
            isAvailable: true,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "files.move.reversible",
            name: "Geri alınabilir dosya işlemi",
            summary: "Seçili alan içindeki izinli dosyaları çakışma güvenliğiyle taşır.",
            risk: .reversibleWrite,
            isAvailable: true,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "files.write.text",
            name: "Metin dosyası yazma",
            summary: "Görev çıktısını kullanıcının belirttiği veya çözülen çalışma alanı içindeki hedefe yeni bir metin dosyası olarak atomik yazar; mevcut dosyayı sessizce ezmez ve çalışma alanı dışına çıkmaz.",
            risk: .reversibleWrite,
            isAvailable: true,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "memory.local",
            name: "Yerel hafıza",
            summary: "Açık kullanıcı kurallarını ve tamamlanan görev bağlamını yapılandırılmış biçimde yerel olarak saklar.",
            risk: .reasoning,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "speech.input",
            name: "Sesli giriş",
            summary: "Mikrofon konuşmasını metne çevirir.",
            risk: .external,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "speech.output",
            name: "Sesli yanıt",
            summary: "Sesli modda yanıtı Türkçe sentezler.",
            risk: .external,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "perception.media",
            name: "Görsel / video algısı",
            summary: "Kadraj, netlik, hareket, görüntü ve ses içeriğini doğrudan analiz eder.",
            risk: .readOnly,
            isAvailable: false,
            requiresWorkspace: true
        ),
        AgentCapability(
            id: "research.web",
            name: "Web araştırma",
            summary: "Anahtarsız bootstrap arama sağlayıcısıyla güncel web kaynaklarını bulur; sonuçları doğrulama/sentez için Core'a verir.",
            risk: .external,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "perception.screen",
            name: "Ekran algısı",
            summary: "ScreenCaptureKit + Vision ile ekranı salt-okunur gözlemler; pencere, uygulama ve OCR kanıtını hedefe göre doğrular.",
            risk: .readOnly,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "desktop.app",
            name: "Uygulama kontrolü",
            summary: "Yüklü macOS uygulamasını doğal dilde çözer; açar veya öne getirir. NSWorkspace/Accessibility ile odaklar ve ScreenCaptureKit pencere z-order kanıtıyla görünür foreground durumunu doğrular.",
            risk: .external,
            isAvailable: true,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "desktop.control",
            name: "macOS UI kontrolü",
            summary: "Accessibility / AXUIElement ile menü, buton, alan, klavye, mouse, clipboard ve sistem arayüzü etkileşimlerini yürütür.",
            risk: .external,
            isAvailable: false,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "photoshop.control",
            name: "Photoshop kontrolü",
            summary: "Photoshop içinde belge oluşturma, asset yerleştirme, katman düzenleme ve tasarım işlemlerini uygular.",
            risk: .external,
            isAvailable: false,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "browser.control",
            name: "Tarayıcı kontrolü",
            summary: "Web arayüzlerinde gezinir ve izin verilen işlemleri tamamlar.",
            risk: .external,
            isAvailable: false,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "premiere.control",
            name: "Premiere kontrolü",
            summary: "Kurgu görevlerini Premiere içinde uygular ve doğrular.",
            risk: .external,
            isAvailable: false,
            requiresWorkspace: false
        ),
        AgentCapability(
            id: "mail.work",
            name: "Mail",
            summary: "Taslak, okuma ve izinli gönderim iş akışlarını yürütür.",
            risk: .external,
            isAvailable: false,
            requiresWorkspace: false
        )
    ]

    func select(
        for rawText: String,
        decision: AgentDecision,
        context: AgentContextSnapshot,
        goal: AgentGoalProfile
    ) -> [AgentCapability] {
        let text = normalize(rawText)
        var ids = ["core.reasoning", "context.local"]
        ids += goal.requiredCapabilityIDs.sorted()

        switch decision.intent {
        case .fileSearch:
            ids += ["files.search", "files.metadata"]

        case .compoundFileTask:
            ids += ["files.search", "files.metadata"]

            if decision.target == .video || decision.target == .image {
                if containsAny(text, [
                    "uygun", "kalite", "net", "kadraj", "hareket",
                    "incele", "değerlendir", "degerlendir", "hangileri"
                ]) {
                    ids.append("perception.media")
                }
            }

        case .openPreviousResult:
            ids += ["files.reveal"]

        case .organizeScreenshots, .approve, .undo, .reject:
            ids += ["files.search", "files.move.reversible"]

        case .assessWorkspace, .contextSuggestion:
            ids += ["files.search", "files.metadata"]

        case .remember:
            ids += ["memory.local"]

        case .workMail:
            ids += ["mail.work"]

        case .futureCapability:
            if containsAny(text, ["premiere", "kurgu", "sequence", "altyaz"]) {
                ids.append("premiere.control")
            }
            if containsAny(text, ["araştır", "arastir", "web", "internet"]) {
                ids.append("research.web")
            }
            if containsAny(text, [
                "tarayıcıda", "tarayicida", "siteye gir", "sayfayı aç",
                "sayfayi ac", "tıkla", "tikla", "formu doldur"
            ]) {
                ids.append("browser.control")
            }
            if containsAny(text, ["mail", "gmail"]) {
                ids.append("mail.work")
            }

        case .conversation, .general:
            break
        }

        if containsAny(text, ["araştır", "arastir", "internetten", "webde", "web'de"]) {
            ids.append("research.web")
        }

        if containsAny(text, [
            "siteye gir", "sitesine gir", "resmi sitesine gir",
            "web sitesine gir", "web sitesini aç", "web sitesini ac",
            "sayfayı aç", "sayfayi ac", "tarayıcıda", "tarayicida",
            "tıkla", "tikla", "formu doldur", "sayfaları incele",
            "sayfalari incele", "ürün sayfalarını incele", "urun sayfalarini incele"
        ]) {
            ids.append("browser.control")
        }

        var seen = Set<String>()
        return ids.compactMap { id in
            guard !seen.contains(id) else { return nil }
            seen.insert(id)
            return all.first { $0.id == id }
        }
    }

    func resolve(
        ids: [String]
    ) -> [AgentCapability] {
        var seen = Set<String>()

        return ids.compactMap { id in
            guard !seen.contains(id),
                  let capability = all.first(
                    where: { $0.id == id }
                  ) else {
                return nil
            }

            seen.insert(id)
            return capability
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased(with: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.contains($0) }
    }
}
