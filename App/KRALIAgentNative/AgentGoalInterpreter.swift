import Foundation

enum AgentGoalOutcome: String, Hashable {
    case converse
    case locate
    case shortlist
    case assessContent
    case analyze
    case ideate
    case transform
    case explain
    case organize
    case open
    case remember
    case research
    case edit
    case communicate
}

struct AgentGoalProfile: Hashable {
    let summary: String
    let outcomes: Set<AgentGoalOutcome>
    let requiredCapabilityIDs: Set<String>
    let isCompound: Bool
}

struct AgentGoalInterpreter {
    func interpret(
        _ rawText: String,
        decision: AgentDecision,
        context: AgentContextSnapshot
    ) -> AgentGoalProfile {
        let text = normalize(rawText)
        var outcomes = Set<AgentGoalOutcome>()
        var capabilityIDs = Set<String>(["core.reasoning", "context.local"])

        switch decision.intent {
        case .conversation:
            outcomes.insert(.converse)

        case .fileSearch:
            outcomes.insert(.locate)
            capabilityIDs.formUnion(["files.search", "files.metadata"])

        case .compoundFileTask:
            outcomes.formUnion([.locate, .shortlist])
            capabilityIDs.formUnion(["files.search", "files.metadata"])

        case .openPreviousResult:
            outcomes.insert(.open)
            capabilityIDs.insert("files.reveal")

        case .contextSuggestion:
            outcomes.formUnion([.shortlist, .explain])
            capabilityIDs.insert("files.metadata")

        case .organizeScreenshots:
            outcomes.formUnion([.locate, .organize])
            capabilityIDs.formUnion(["files.search", "files.move.reversible"])

        case .remember:
            outcomes.insert(.remember)
            capabilityIDs.insert("memory.local")

        case .approve, .undo, .reject:
            outcomes.insert(.organize)
            capabilityIDs.formUnion(["files.search", "files.move.reversible"])

        case .assessWorkspace:
            outcomes.formUnion([.locate, .explain])
            capabilityIDs.formUnion(["files.search", "files.metadata"])

        case .workMail:
            outcomes.insert(.communicate)
            capabilityIDs.insert("mail.work")

        case .futureCapability, .general:
            break
        }

        let mentionsMedia = containsAny(text, [
            "video", "görsel", "gorsel", "görüntü", "goruntu",
            "fotoğraf", "fotograf", "kadraj", "netlik", "hareket"
        ])

        if containsAny(text, [
            "uygun", "kalite", "netlik", "kadraj", "hareket",
            "görüntü içeri", "goruntu iceri", "ses analizi",
            "hangisi daha iyi", "hangileri daha iyi", "kurgu potansiyeli",
            "içerikten yorum", "icerikten yorum"
        ]) && (
            decision.target == .video ||
            decision.target == .image ||
            mentionsMedia
        ) {
            outcomes.insert(.assessContent)
            capabilityIDs.insert("perception.media")
        }

        let asksComparison = containsAny(text, [
            "karşılaştır", "karsilastir",
            "arasındaki fark", "arasindaki fark",
            "farklar neler", "farkı nedir", "farki nedir",
            " vs ", "versus"
        ])

        if containsAny(text, [
            "analiz et", "analizini yap", "değerlendir", "degerlendir",
            "karşılaştır", "karsilastir", "çıkarım", "cikarim",
            "güçlü ve zayıf", "guclu ve zayif", "fırsat", "firsat",
            "eksik gördüğün", "eksik gordugun",
            "arasındaki fark", "arasindaki fark",
            "farklar neler", "farkı nedir", "farki nedir"
        ]) {
            outcomes.insert(.analyze)
        }

        if asksComparison {
            outcomes.insert(.explain)

            if decision.intent == .general {
                outcomes.insert(.research)
                capabilityIDs.insert("research.web")
            }
        }

        if containsAny(text, [
            "kendi fikir", "kendi yorum", "benim söylemediğim",
            "benim soylemedigim", "özgün fikir", "ozgun fikir",
            "fikir üret", "fikir uret", "fikri üret", "fikri uret",
            "fikirleri üret", "fikirleri uret",
            "fikir çıkar", "fikir cikar", "fikri çıkar", "fikri cikar",
            "fikirleri çıkar", "fikirleri cikar",
            "öneri üret", "oneri uret",
            "özgün içerik", "ozgun icerik", "büyüme fikri", "buyume fikri",
            "olası fırsat", "olasi firsat"
        ]) {
            outcomes.insert(.ideate)
        }

        if containsAny(text, [
            "neden", "nedenlerini", "açıkla", "acikla",
            "söyle", "soyle", "raporla", "özetle", "ozetle",
            "çıkarımları", "cikarimlari", "yorumlarını", "yorumlarini",
            "yorum yap", "yorumla", "hakkında yorum", "hakkinda yorum"
        ]) {
            outcomes.insert(.explain)
        }

        if containsAny(text, [
            "araştır", "arastir", "internetten", "internette",
            "webde", "web'de", "kaynak bul", "doğrula", "dogrula"
        ]) {
            outcomes.insert(.research)
            capabilityIDs.insert("research.web")

            if containsAny(text, [
                "detaylı araştır", "detayli arastir",
                "detaylı incele", "detayli incele",
                "detaylı bak", "detayli bak",
                "araştırır mısın", "arastirir misin",
                "hakkında detaylı", "hakkinda detayli"
            ]) {
                outcomes.insert(.explain)
            }
        }

        let mentionsSocialProfile = containsAny(text, [
            "instagram", "tiktok", "linkedin", "youtube",
            "sosyal medya", "sosyalmedya", "profil", "hesabı", "hesabi"
        ])

        let asksSocialProfileFacts = containsAny(text, [
            "takipçi", "takipci", "takipçisi", "takipcisi",
            "içerik", "icerik", "paylaşım", "paylasim",
            "gönderi", "gonderi", "reels", "reel",
            "kaç", "kac", "bakabilir", "bakabilir misin",
            "incele", "neler", "bio"
        ])

        let isContextualCreativeFollowup =
            context.relevantMemoryCount > 0 &&
            containsAny(text, [
                "fikir", "öneri", "oneri", "strateji",
                "çıkar", "cikar", "üret", "uret",
                "devam et", "devam edelim",
                "az önce", "az once", "bunlardan",
                "senaryo", "senaryoya", "senaryosuna",
                "çekim plan", "cekim plan",
                "çevir", "cevir", "uyarla",
                "dönüştür", "donustur"
            ])

        let isContextualTransformation =
            context.relevantMemoryCount > 0 &&
            containsAny(text, [
                "senaryo", "senaryoya", "senaryosuna",
                "çekim plan", "cekim plan",
                "çevir", "cevir", "uyarla",
                "dönüştür", "donustur"
            ])

        if isContextualTransformation {
            outcomes.insert(.transform)
        }

        if mentionsSocialProfile &&
           asksSocialProfileFacts &&
           !isContextualCreativeFollowup {
            outcomes.formUnion([.research, .explain])
            capabilityIDs.insert("research.web")
        }

        if containsAny(text, [
            "hangi yeteneğin eksik", "hangi yetenegin eksik",
            "neyin eksik olduğunu bul", "neyin eksik oldugunu bul",
            "öğrenme planı", "ogrenme plani", "kendine öğren",
            "kendine ogren", "nasıl yapıldığını araştır", "nasil yapildigini arastir"
        ]) {
            outcomes.formUnion([.analyze, .explain])
        }

        if containsAny(text, [
            "premiere'de", "premierede", "sequence", "timeline",
            "kurgu yap", "kurgula", "montaj yap", "altyazı ekle", "altyazi ekle"
        ]) {
            outcomes.insert(.edit)
            capabilityIDs.insert("premiere.control")
        }

        if containsAny(text, ["mail", "gmail", "e-posta", "eposta"]) {
            outcomes.insert(.communicate)
            capabilityIDs.insert("mail.work")
        }

        if containsAny(text, [
            "siteye gir", "sitesine gir", "resmi sitesine gir",
            "web sitesine gir", "web sitesini aç", "web sitesini ac",
            "sayfayı aç", "sayfayi ac", "tarayıcıda", "tarayicida",
            "tıkla", "tikla", "formu doldur", "sayfaları incele",
            "sayfalari incele", "ürün sayfalarını incele", "urun sayfalarini incele"
        ]) {
            capabilityIDs.insert("browser.control")
        }

        if containsAny(text, ["aç", "ac", "finder'da", "finderda"]) &&
           (context.previousFileResultCount > 0 || context.previousFolderResultCount > 0) {
            outcomes.insert(.open)
            capabilityIDs.insert("files.reveal")
        }

        let isCompound =
            outcomes.subtracting([.converse, .explain, .ideate, .transform]).count > 1 ||
            decision.intent == .compoundFileTask

        return AgentGoalProfile(
            summary: summary(
                for: decision.target,
                outcomes: outcomes,
                fallback: decision.goal
            ),
            outcomes: outcomes,
            requiredCapabilityIDs: capabilityIDs,
            isCompound: isCompound
        )
    }

    private func summary(
        for target: AgentTargetKind,
        outcomes: Set<AgentGoalOutcome>,
        fallback: String
    ) -> String {
        let object: String
        switch target {
        case .video: object = "videoları"
        case .image: object = "görselleri"
        case .document: object = "belgeleri"
        case .project: object = "proje dosyalarını"
        case .screenshot: object = "ekran görüntülerini"
        case .pdf: object = "PDF dosyalarını"
        case .folder: object = "klasörleri"
        case .any: object = "hedef öğeleri"
        }

        var parts: [String] = []

        if outcomes.contains(.locate) {
            parts.append(object + " bul")
        }
        if outcomes.contains(.shortlist) {
            parts.append("anlamlı adaylara indir")
        }
        if outcomes.contains(.assessContent) {
            parts.append("içeriği doğrudan değerlendir")
        }
        if outcomes.contains(.analyze) {
            parts.append("bulguları analiz et")
        }
        if outcomes.contains(.ideate) {
            parts.append("bağımsız fikir ve çıkarım üret")
        }
        if outcomes.contains(.transform) {
            parts.append("önceki çıktıyı istenen formata dönüştür")
        }
        if outcomes.contains(.organize) {
            parts.append("güvenli biçimde düzenle")
        }
        if outcomes.contains(.open) {
            parts.append("istenen sonucu aç")
        }
        if outcomes.contains(.research) {
            parts.append("güncel kaynaklarla araştır")
        }
        if outcomes.contains(.edit) {
            parts.append("uygulamada işle")
        }
        if outcomes.contains(.communicate) {
            parts.append("iletişim görevini yürüt")
        }
        if outcomes.contains(.remember) {
            parts.append("çalışma kuralını öğren")
        }
        if outcomes.contains(.explain) {
            parts.append("sonucu ve gerekçeyi açıkla")
        }
        if outcomes.contains(.converse) {
            parts.append("doğal konuşmayı sürdür")
        }

        return parts.isEmpty ? fallback : parts.joined(separator: " → ")
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
