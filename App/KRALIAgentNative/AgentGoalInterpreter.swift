import Foundation

enum AgentGoalOutcome: String, Hashable {
    case converse
    case locate
    case shortlist
    case assessContent
    case analyze
    case ideate
    case compose
    case transform
    case explain
    case organize
    case open
    case remember
    case research
    case edit
    case communicate
}

struct AgentCommandAssessment: Hashable {
    let confidence: Double
    let ambiguities: [String]

    var requiresClarification: Bool {
        confidence < 0.55 && !ambiguities.isEmpty
    }

    static let confident = AgentCommandAssessment(
        confidence: 0.95,
        ambiguities: []
    )
}

struct AgentGoalProfile: Hashable {
    let summary: String
    let outcomes: Set<AgentGoalOutcome>
    let requiredCapabilityIDs: Set<String>
    let isCompound: Bool
    let commandAssessment: AgentCommandAssessment

    init(
        summary: String,
        outcomes: Set<AgentGoalOutcome>,
        requiredCapabilityIDs: Set<String>,
        isCompound: Bool,
        commandAssessment: AgentCommandAssessment = .confident
    ) {
        self.summary = summary
        self.outcomes = outcomes
        self.requiredCapabilityIDs = requiredCapabilityIDs
        self.isCompound = isCompound
        self.commandAssessment = commandAssessment
    }
}

struct AgentGoalInterpreter {
    private let languageResolver =
        AgentNaturalLanguageResolver()
    func interpret(
        _ rawText: String,
        decision: AgentDecision,
        context: AgentContextSnapshot
    ) -> AgentGoalProfile {
        let text = normalize(rawText)

        if languageResolver.isSimpleOpenCommand(
            rawText
        ) {
            return AgentGoalProfile(
                summary:
                    "istenen uygulamayı aç veya öne getir",
                outcomes: [.open],
                requiredCapabilityIDs: [
                    "desktop.app"
                ],
                isCompound: false,
                commandAssessment: .confident
            )
        }

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

        let appOpenIntent =
            languageResolver
                .hasApplicationOpenIntent(
                    rawText
                )

        let browserWorkflow =
            languageResolver
                .requestsBrowserWorkflow(
                    rawText
                )

        if appOpenIntent {
            outcomes.insert(.open)
            capabilityIDs.insert(
                "desktop.app"
            )
        }

        if browserWorkflow {
            outcomes.formUnion([
                .research,
                .explain
            ])
            capabilityIDs.insert(
                "browser.control"
            )
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

        let asksTextRewrite = containsAny(text, [
            "yeniden yaz", "tekrar yaz",
            "düzgün türkçeyle", "duzgun turkceyle",
            "düzgün türkçe", "duzgun turkce",
            "yazım hatalarını düzelt", "yazim hatalarini duzelt",
            "imla hatalarını düzelt", "imla hatalarini duzelt",
            "metni düzelt", "metni duzelt",
            "proofread", "rewrite"
        ])

        let asksStructuredContentCreation = containsAny(text, [
            "çekim planı hazırla", "cekim plani hazirla",
            "çekim planı oluştur", "cekim plani olustur",
            "senaryo hazırla", "senaryo hazirla",
            "senaryo oluştur", "senaryo olustur",
            "senaryo yaz",
            "reels senaryosu",
            "reels planı hazırla", "reels plani hazirla",
            "reels planı oluştur", "reels plani olustur",
            "reel planı hazırla", "reel plani hazirla",
            "video planı hazırla", "video plani hazirla",
            "sosyal medya video planı", "sosyal medya video plani",
            "içerik planı hazırla", "icerik plani hazirla",
            "metin hazırla", "metin hazirla",
            "caption yaz", "açıklama yaz", "aciklama yaz"
        ])

        if asksStructuredContentCreation {
            outcomes.insert(.compose)
        }

        if isContextualTransformation || asksTextRewrite {
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

        let affirmativeWorkflowText =
            languageResolver
                .affirmativeWorkflowText(
                    rawText
                )

        let asksGenericAppWorkflow =
            appOpenIntent &&
            containsAny(
                affirmativeWorkflowText,
                [
                    "bul", "oku", "incele", "listele",
                    "soyle", "goster",
                    "sec", "ekle", "hazirla",
                    "ayarla", "degistir",
                    "hatirlatma",
                    "etkinlik", "randevu", "mesaj", "sarki",
                    "bolumune git",
                    "oynat", "play",
                    "tikla", "click",
                    "kaydir", "scroll",
                    "yaz", "type",
                    "ac ve", "open and"
                ]
            )

        let specializedAppDomain =
            containsAny(text, [
                "mail", "gmail", "e-posta", "eposta",
                "premiere", "photoshop"
            ]) ||
            browserWorkflow

        if asksGenericAppWorkflow &&
           !specializedAppDomain {
            capabilityIDs.formUnion([
                "app.workflow",
                "perception.screen"
            ])

            let interactionTerms = [
                "oynat", "play",
                "tikla", "click",
                "kaydir", "scroll",
                "sec", "select",
                "yaz", "type",
                "ekle", "add",
                "ayarla", "degistir"
            ]

            if interactionTerms.contains(
                where: {
                    affirmativeWorkflowText
                        .contains($0)
                }
            ) {
                capabilityIDs.insert(
                    "desktop.control"
                )
            }
        }

        if containsAny(text, ["aç", "ac", "finder'da", "finderda"]) &&
           (context.previousFileResultCount > 0 || context.previousFolderResultCount > 0) {
            outcomes.insert(.open)
            capabilityIDs.insert("files.reveal")
        }

        let isCompound =
            outcomes.subtracting([.converse, .explain, .ideate, .compose, .transform]).count > 1 ||
            decision.intent == .compoundFileTask

        let foundationalCapabilityIDs =
            Set([
                "core.reasoning",
                "context.local"
            ])

        let toolCapabilityIDs =
            capabilityIDs.subtracting(
                foundationalCapabilityIDs
            )

        let preservedUserGoal =
            rawText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let goalSummary =
            toolCapabilityIDs.isEmpty &&
            !preservedUserGoal.isEmpty
                ? preservedUserGoal
                : summary(
                    for: decision.target,
                    outcomes: outcomes,
                    fallback: decision.goal
                )

        return AgentGoalProfile(
            summary: goalSummary,
            outcomes: outcomes,
            requiredCapabilityIDs: capabilityIDs,
            isCompound: isCompound,
            commandAssessment: commandAssessment(
                rawText: rawText,
                outcomes: outcomes,
                context: context
            )
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
        if outcomes.contains(.compose) {
            parts.append("istenen içeriği oluştur")
        }
        if outcomes.contains(.transform) {
            parts.append("verilen veya önceki çıktıyı istenen formata dönüştür")
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

    private func commandAssessment(
        rawText: String,
        outcomes: Set<AgentGoalOutcome>,
        context: AgentContextSnapshot
    ) -> AgentCommandAssessment {
        let normalized = languageResolver.normalized(rawText)
        var ambiguities: [String] = []

        if containsAny(normalized, ["bunu", "şunu", "sunu", "onu", "burayı", "burayi"]) &&
            context.relevantMemoryCount == 0 &&
            context.previousFileResultCount == 0 &&
            context.previousFolderResultCount == 0 {
            ambiguities.append("hangi önceki öğe veya sonucu kastettiğin")
        }

        if containsAny(normalized, ["veya", "ya da", "hangisi", "birini"]) &&
            outcomes.count > 1 {
            ambiguities.append("hangi alternatifin öncelikli olduğu")
        }

        let toolOutcomes: Set<AgentGoalOutcome> = [
            .open, .research, .edit, .organize, .communicate, .locate
        ]
        if outcomes.intersection(toolOutcomes).count >= 3 {
            ambiguities.append("çoklu işlemlerin uygulanma sırası")
        }

        let confidence = max(
            0.25,
            0.95 - Double(ambiguities.count) * 0.28
        )
        return AgentCommandAssessment(
            confidence: confidence,
            ambiguities: ambiguities
        )
    }
}
