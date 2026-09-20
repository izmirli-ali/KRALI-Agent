import Foundation

enum AgentIntentKind {
    case conversation
    case assessWorkspace
    case fileSearch
    case compoundFileTask
    case openPreviousResult
    case contextSuggestion
    case organizeScreenshots
    case remember
    case undo
    case approve
    case reject
    case workMail
    case futureCapability
    case general
}

enum AgentTargetKind {
    case any
    case video
    case image
    case document
    case project
    case screenshot
    case pdf
    case folder
}

enum AgentSortMode {
    case relevance
    case newestFirst
}

enum AgentDateField {
    case either
    case created
    case modified
}

enum AgentResultSelection {
    case first
    case last
}

struct AgentContextSnapshot {
    let hasWorkspace: Bool
    let workspaceName: String?
    let fileCount: Int
    let imageCount: Int
    let videoCount: Int
    let projectCount: Int
    let documentCount: Int
    let screenshotCount: Int
    let hasPendingAction: Bool
    let previousFileResultCount: Int
    let previousFolderResultCount: Int
    let lastTarget: AgentTargetKind?
    let lastGoal: String?
    let relevantMemoryCount: Int
    let lastMemoryGoal: String?
}

struct AgentDecision {
    let intent: AgentIntentKind
    let target: AgentTargetKind
    let dateRange: DateInterval?
    let dateField: AgentDateField
    let sortMode: AgentSortMode
    let route: [String]
    let goal: String
    let selectedPlan: String
    let alternatives: [String]
    let proactiveSuggestion: String?
    let usePreviousResults: Bool
    let resultSelection: AgentResultSelection?
}

struct AgentBrain {
    private let calendar = Calendar.autoupdatingCurrent

    func analyze(
        _ rawText: String,
        context: AgentContextSnapshot,
        now: Date = Date()
    ) -> AgentDecision {
        let text = normalize(rawText)

        if context.hasPendingAction && isApproval(text) {
            return decision(
                intent: .approve,
                route: ["Core", "Intent", "File Actions"],
                goal: "Bekleyen güvenli dosya işlemini onayla",
                plan: "Önceden hazırlanmış işlemi uygula ve sonucu doğrula",
                alternatives: ["İşlemi iptal et", "Önce ayrıntıları tekrar göster"]
            )
        }

        if context.hasPendingAction && isRejection(text) {
            return decision(
                intent: .reject,
                route: ["Core", "Intent", "File Actions"],
                goal: "Bekleyen dosya işlemini iptal et",
                plan: "Dosyalara dokunmadan bekleyen işlemi kaldır",
                alternatives: ["İşlem planını değiştir", "Yeni bir görev ver"]
            )
        }

        if containsAny(text, ["geri al", "undo", "önceki işlemi geri", "onceki islemi geri"]) {
            return decision(
                intent: .undo,
                route: ["Core", "Intent", "File Actions"],
                goal: "Son geri alınabilir işlemi tersine çevir",
                plan: "Son taşıma kaydını kullanarak dosyaları güvenli biçimde geri yükle",
                alternatives: ["Önce son işlemin ayrıntısını incele"]
            )
        }

        if isRememberIntent(text) {
            return decision(
                intent: .remember,
                route: ["Core", "Intent", "Learning"],
                goal: "Kullanıcının açık çalışma kuralını hafızaya al",
                plan: "Genellenebilir çalışma kuralını marka / konu özelindeki ayrıntılardan ayır ve yerel hafızaya kaydet",
                alternatives: ["Kuralı daha sonra düzenle", "Yeni bir çalışma kuralı ekle"]
            )
        }

        let hasPreviousResults =
            context.previousFileResultCount > 0 ||
            context.previousFolderResultCount > 0

        if hasPreviousResults && isOpenPreviousResultIntent(text) {
            let selection: AgentResultSelection = containsAny(
                text,
                ["sonuncu", "sonuncusunu", "en sondaki", "en sonuncu"]
            ) ? .last : .first

            return decision(
                intent: .openPreviousResult,
                route: ["Core", "Context", "Planner", "File Search"],
                goal: "Önceki sonuçlardan istenen öğeyi aç",
                plan: "Önceki arama sonuçlarını koru, referansı çöz ve Finder'da doğru öğeyi göster",
                alternatives: ["İlk sonucu aç", "Son sonucu aç", "Sonuçları yeniden listele"],
                resultSelection: selection
            )
        }

        if hasPreviousResults && isContextSuggestionIntent(text) {
            return decision(
                intent: .contextSuggestion,
                route: ["Core", "Context", "Planner"],
                goal: "Önceki sonuçlardan bir sonraki çalışma adayını seç",
                plan: "Önceki sonuçların tür ve tarih bilgisini kullanarak açıklanabilir bir başlangıç adayı öner",
                alternatives: ["En yeniyi seç", "İlk sonucu aç", "Sonuçları daralt"]
            )
        }

        if context.previousFileResultCount > 0 && isContextualResultFilter(text) {
            let resolvedTarget = resolveTarget(text)
            let target = resolvedTarget == .any
                ? (context.lastTarget ?? .any)
                : resolvedTarget
            let dateResolution = resolveDate(text, now: now)
            let sort: AgentSortMode = containsAny(
                text,
                ["son eklenen", "en yeni", "en son", "son çekilen", "son cekilen", "latest"]
            ) ? .newestFirst : .relevance

            return AgentDecision(
                intent: .fileSearch,
                target: target,
                dateRange: dateResolution.range,
                dateField: resolveDateField(text),
                sortMode: sort,
                route: ["Core", "Context", "Planner", "File Search"],
                goal: fileSearchGoal(
                    target: target,
                    dateDescription: dateResolution.description,
                    newestFirst: sort == .newestFirst
                ),
                selectedPlan: "Önceki sonuç kümesini bağlam olarak koru; yalnızca onun içinde yeni filtreyi uygula",
                alternatives: [
                    "Önceki sonuçların tamamını tekrar göster",
                    "Tarihe göre daralt",
                    "İlk veya son sonucu aç"
                ],
                proactiveSuggestion: nil,
                usePreviousResults: true,
                resultSelection: nil
            )
        }

        if context.relevantMemoryCount > 0 &&
           hasContextReference(text) {
            return decision(
                intent: .general,
                route: ["Core", "Context", "Planner"],
                goal: "Önceki görev bağlamını kullanarak devam et",
                plan: "İlgili önceki görev bağlamını geri çağır; yeni isteği ona bağla ve gerekmedikçe aynı araştırmayı baştan yapma",
                alternatives: [
                    "Önceki sonucu genişlet",
                    "Önceki bulgulardan yeni fikir üret",
                    "Gerekirse yalnızca eksik noktayı yeniden araştır"
                ]
            )
        }

        if isConversation(text) {
            return decision(
                intent: .conversation,
                route: ["Core", "Conversation"],
                goal: "Doğal konuşmayı sürdür",
                plan: "Kısa ve bağlama uygun cevap ver",
                alternatives: context.hasWorkspace
                    ? ["Çalışma alanının durumunu özetle", "Bir sonraki işi öner"]
                    : ["Bir çalışma alanı seç", "Ne yapmak istediğini konuş"]
            )
        }

        if isWorkspaceAssessment(text) {
            var alternatives = [
                "Dosya dağılımını incele",
                "Son eklenen dosyaları kontrol et",
                "Düşük riskli düzenleme önerileri üret"
            ]

            var suggestion: String?
            if context.screenshotCount >= 5 {
                alternatives.insert("Ekran görüntülerini ayrı klasörde toparla", at: 0)
                suggestion = "En düşük riskli ilk adım olarak ekran görüntülerini toparlamak mantıklı görünüyor."
            } else if context.fileCount >= 50 {
                suggestion = "Önce hangi dosya türlerinin alanı kalabalıklaştırdığını çıkarmak daha güvenli."
            }

            return decision(
                intent: .assessWorkspace,
                route: ["Core", "Context", "Planner"],
                goal: "Çalışma alanını incele ve yararlı seçenekler üret",
                plan: "Önce sadece oku; durumu özetle, alternatifleri karşılaştır ve değişiklik yapmadan öner",
                alternatives: alternatives,
                suggestion: suggestion
            )
        }

        if isScreenshotOrganizeIntent(text) {
            return decision(
                intent: .organizeScreenshots,
                target: .screenshot,
                route: ["Core", "Intent", "Context", "Planner", "File Actions"],
                goal: "Ekran görüntülerini güvenli biçimde toparla",
                plan: "Adayları bul, planı göster, onaydan sonra taşı ve geri alma kaydı oluştur",
                alternatives: ["Sadece ekran görüntülerini listele", "Tarihe göre daralt"]
            )
        }

        if isExplicitWebResearchIntent(text) {
            return decision(
                intent: .general,
                route: ["Core", "Goal", "Planner", "Research"],
                goal: "Web araştırması yap",
                plan: "Soruyu dosya araması olarak yorumlama; web araştırması için temiz bir sorgu oluştur, güncel kaynakları bul ve sonucu doğrula",
                alternatives: [
                    "Sorguyu daralt",
                    "Resmi kaynaklara öncelik ver",
                    "Bulunan kaynakları karşılaştır"
                ]
            )
        }

        if isCompoundFileTask(text) {
            let target = resolveTarget(text)
            let dateResolution = resolveDate(text, now: now)
            let sort: AgentSortMode = containsAny(
                text,
                ["son eklenen", "en yeni", "en yenilerini", "en son", "son çekilen", "son cekilen", "latest"]
            ) ? .newestFirst : .relevance

            return AgentDecision(
                intent: .compoundFileTask,
                target: target,
                dateRange: dateResolution.range,
                dateField: resolveDateField(text),
                sortMode: sort,
                route: ["Core", "Intent", "Context", "Planner", "File Search", "Synthesis"],
                goal: "Çok adımlı dosya görevini yürüt",
                selectedPlan: "Hedef dosyaları bul; istenen ölçüte göre kısa liste oluştur; mevcut metadata ile değerlendir; sonucu doğrula",
                alternatives: [
                    "Sadece adayları listele",
                    "En yeni adayları kısa listele",
                    "Görüntü içeriği analizi eklenene kadar metadata temelli ön seçim yap"
                ],
                proactiveSuggestion: nil,
                usePreviousResults: hasContextReference(text) && context.previousFileResultCount > 0,
                resultSelection: nil
            )
        }

        if isFileSearchIntent(text) {
            let target = resolveTarget(text)
            let dateResolution = resolveDate(text, now: now)
            let sort: AgentSortMode = containsAny(
                text,
                ["son eklenen", "en yeni", "en son", "son çekilen", "son cekilen", "latest"]
            ) ? .newestFirst : .relevance

            return AgentDecision(
                intent: .fileSearch,
                target: target,
                dateRange: dateResolution.range,
                dateField: resolveDateField(text),
                sortMode: sort,
                route: ["Core", "Intent", "Context", "File Search"],
                goal: fileSearchGoal(
                    target: target,
                    dateDescription: dateResolution.description,
                    newestFirst: sort == .newestFirst
                ),
                selectedPlan: "Seçili çalışma alanını salt-okunur tara, filtreleri uygula ve en uygun sonuçları göster",
                alternatives: [
                    "Dosya adına göre daralt",
                    "Tarihe göre daralt",
                    "Sonuçları en yeniye göre sırala"
                ],
                proactiveSuggestion: nil,
                usePreviousResults: false,
                resultSelection: nil
            )
        }

        if containsAny(text, ["17:55", "mail", "gmail"]) {
            return decision(
                intent: .workMail,
                route: ["Core", "Intent", "Planner", "Work/Mail"],
                goal: "İş maili görevini planla",
                plan: "Kaynağı belirle, taslağı hazırla ve gönderimden önce onay iste",
                alternatives: ["Sadece taslak hazırla", "Önce günlük işleri özetle"]
            )
        }

        if containsAny(text, ["premiere", "openai", "chatgpt"]) {
            return decision(
                intent: .futureCapability,
                route: ["Core", "Intent", "Planner"],
                goal: "Henüz bağlı olmayan bir yetenek için uygulanabilir plan üret",
                plan: "Mevcut yerel yeteneklerle yapılabilecek kısmı ayır; dış bağlantı gerektiren kısmı beklet",
                alternatives: ["Yerelde çözülebilen kısmı yap", "Gereken entegrasyonu daha sonra ekle"]
            )
        }

        return decision(
            intent: .general,
            route: ["Core", "Intent", "Context", "Planner"],
            goal: "Kullanıcının hedefini anlamlandır ve uygulanabilir bir sonraki adımı seç",
            plan: "Bağlamı incele; doğrudan araç eşleşmesi yoksa güvenli alternatifler üret",
            alternatives: context.hasWorkspace
                ? ["Çalışma alanını incele", "Dosya araması yap", "Yeni bir çalışma kuralı öğren"]
                : ["Çalışma alanı seç", "Hedefi biraz daha somutlaştır"]
        )
    }

    private func decision(
        intent: AgentIntentKind,
        target: AgentTargetKind = .any,
        route: [String],
        goal: String,
        plan: String,
        alternatives: [String],
        suggestion: String? = nil,
        usePreviousResults: Bool = false,
        resultSelection: AgentResultSelection? = nil
    ) -> AgentDecision {
        AgentDecision(
            intent: intent,
            target: target,
            dateRange: nil,
            dateField: .either,
            sortMode: .relevance,
            route: route,
            goal: goal,
            selectedPlan: plan,
            alternatives: alternatives,
            proactiveSuggestion: suggestion,
            usePreviousResults: usePreviousResults,
            resultSelection: resultSelection
        )
    }

    private func isConversation(_ text: String) -> Bool {
        containsAny(text, [
            "nasılsın", "nasilsin", "naber", "ne haber",
            "selam", "merhaba", "günaydın", "gunaydin",
            "iyi akşamlar", "iyi aksamlar", "ne yapıyorsun", "ne yapiyorsun"
        ])
    }

    private func isWorkspaceAssessment(_ text: String) -> Bool {
        containsAny(text, [
            "ne önerirsin", "ne onerirsin", "sence ne yapalım", "sence ne yapalim",
            "bu klasör dağınık", "bu klasor daginik", "klasör dağınık", "klasor daginik",
            "burayı düzenleyelim", "burayi duzenleyelim", "burada ne yapabiliriz",
            "çalışma alanını incele", "calisma alanini incele"
        ])
    }

    private func isRememberIntent(_ text: String) -> Bool {
        if containsAny(text, [
            "öğret:", "ogret:", "bunu unutma", "aklında tut", "aklinda tut",
            "bunu hatırla", "bunu hatirla", "bundan sonra"
        ]) {
            return true
        }

        let workflowReference = containsAny(text, [
            "çalışma biçimini", "calisma bicimini",
            "çalışma şeklini", "calisma seklini",
            "bu yöntemi", "bu yontemi",
            "bu düzeni", "bu duzeni",
            "bu yaklaşımı", "bu yaklasimi"
        ])

        let futureReuse = containsAny(text, [
            "ileride", "benzer", "bundan böyle", "bundan boyle",
            "için de kullan", "icin de kullan",
            "aynı şekilde kullan", "ayni sekilde kullan"
        ])

        let scopeBoundary = containsAny(text, [
            "başka markalara", "baska markalara",
            "başka markaya", "baska markaya",
            "otomatik uygulama", "otomatik taşıma", "otomatik tasima",
            "yalnızca bu marka", "yalnizca bu marka",
            "markaya özel", "markaya ozel"
        ])

        return (workflowReference && futureReuse) ||
            (workflowReference && scopeBoundary)
    }

    private func isScreenshotOrganizeIntent(_ text: String) -> Bool {
        let screenshot = containsAny(text, [
            "ekran görünt", "ekran gorunt", "ekran resmi", "screenshot", "screen shot"
        ])
        let action = containsAny(text, [
            "toparla", "taşı", "tasi", "klasöre", "klasore", "düzenle", "duzenle"
        ])
        return screenshot && action
    }

    private func hasContextReference(_ text: String) -> Bool {
        containsAny(text, [
            "bunlardan", "bunların", "bunlar", "onlardan", "onların",
            "şunlardan", "sunlardan", "sonuçlardan", "sonuclardan",
            "az önce", "az once", "az önceki", "az onceki",
            "bu hesap", "bu marka", "bu şirket", "bu sirket",
            "bu analiz", "bu rapor", "bu konu", "buna göre", "buna gore",
            "bulduklarından", "bulduklarindan", "gösterdiklerinden", "gosterdiklerinden"
        ])
    }

    private func isOpenPreviousResultIntent(_ text: String) -> Bool {
        let openAction = containsAny(text, [
            "aç", "ac", "finder'da göster", "finderda göster",
            "finder'da goster", "finderda goster"
        ])
        let selection = containsAny(text, [
            "ilkini", "birincisini", "sonuncusunu", "sonuncuyu",
            "en sondakini", "ilk sonucu", "son sonucu"
        ])

        return openAction && (selection || hasContextReference(text))
    }

    private func isContextSuggestionIntent(_ text: String) -> Bool {
        containsAny(text, [
            "hangisini düzenleyelim", "hangisini duzenleyelim",
            "hangisini seçelim", "hangisini secelim",
            "hangisiyle başlayalım", "hangisiyle baslayalim",
            "sence hangisi", "hangisinden başlayalım", "hangisinden baslayalim"
        ])
    }

    private func isContextualResultFilter(_ text: String) -> Bool {
        guard hasContextReference(text) else { return false }

        let target = resolveTarget(text)
        let filterAction = containsAny(text, [
            "göster", "goster", "listele", "bul", "çıkar", "cikar",
            "hangileri", "neler", "ne var"
        ])

        return target != .any && filterAction
    }

    private func isExplicitWebResearchIntent(_ text: String) -> Bool {
        let researchAction = containsAny(text, [
            "web'de araştır", "webde araştır",
            "web'de arastir", "webde arastir",
            "internetten araştır", "internetten arastir",
            "internette araştır", "internette arastir",
            "internet'te araştır", "internet'te arastir",
            "google'da araştır", "googleda araştır",
            "google'da arastir", "googleda arastir",
            "kaynak bul", "güncel kaynak", "guncel kaynak",
            "internetten bak", "web'den bak", "webden bak"
        ])

        return researchAction
    }

    private func isCompoundFileTask(_ text: String) -> Bool {
        let target = resolveTarget(text)

        guard target != .any, target != .folder else {
            return false
        }

        let searchAction = containsAny(text, [
            "bul", "ara", "göster", "goster", "listele", "incele", "getir"
        ])

        let selectionAction = containsAny(text, [
            "seç", "sec", "seçelim", "secelim", "en yenilerini",
            "en iyilerini", "ayırt", "ayirt", "daralt"
        ])

        let assessmentAction = containsAny(text, [
            "uygun", "değerlendir", "degerlendir", "hangileri",
            "hangisi", "öner", "oner", "seçmeye değer", "secmeye deger"
        ])

        let sequenceMarker = containsAny(text, [
            "sonra", "ardından", "ardindan", "ve sonra",
            "ve ardından", "ve ardindan", ","
        ])

        return searchAction &&
            sequenceMarker &&
            (selectionAction || assessmentAction)
    }

    private func isFileSearchIntent(_ text: String) -> Bool {
        let explicitLocalScope = containsAny(text, [
            "dosya", "klasör", "klasor", "finder",
            "masaüst", "masaustu", "desktop",
            "bilgisayarımda", "bilgisayarimda",
            "mac'imde", "macimde",
            "videolarım", "videolarim",
            "çekimlerim", "cekimlerim",
            "arşiv", "arsiv"
        ])

        let looksLikeKnowledgeComparison = containsAny(text, [
            "arasındaki fark", "arasindaki fark",
            "farklar neler", "farkı nedir", "farki nedir",
            "karşılaştır", "karsilastir", " vs ", "versus"
        ])

        let looksLikeContentCreation = containsAny(text, [
            "çekim planı", "cekim plani",
            "reels planı", "reels plani",
            "reel planı", "reel plani",
            "video planı", "video plani",
            "senaryo hazırla", "senaryo hazirla",
            "plan hazırla", "plan hazirla",
            "metni hazırla", "metni hazirla",
            "yeniden yaz", "tekrar yaz",
            "düzgün türkçeyle", "duzgun turkceyle",
            "yazım hat", "yazim hat",
            "kalın göster", "kalin goster",
            "başlık", "baslik"
        ])

        if (looksLikeKnowledgeComparison || looksLikeContentCreation) &&
           !explicitLocalScope {
            return false
        }

        let actions = [
            "bul", "ara", "göster", "goster", "listele", "nerede", "hangileri",
            "neler", "ne var", "incele", "inceler misin", "bak", "getir", "çıkar", "cikar"
        ]
        let targets = [
            "dosya", "video", "çekim", "cekim", "pdf", "görsel", "gorsel",
            "resim", "fotoğraf", "fotograf", "proje", "belge", "doküman",
            "dokuman", "logo", "klasör", "klasor", "ekran görünt", "ekran gorunt", "ekran resmi"
        ]
        return containsAny(text, actions) && containsAny(text, targets)
    }

    private func resolveTarget(_ text: String) -> AgentTargetKind {
        if containsAny(text, ["ekran görünt", "ekran gorunt", "ekran resmi", "screenshot"]) {
            return .screenshot
        }
        if containsAny(text, ["klasör", "klasor"]) {
            return .folder
        }
        if text.contains("pdf") {
            return .pdf
        }
        if containsAny(text, ["video", "videolar", "çekim", "cekim", "klip"]) {
            return .video
        }
        if containsAny(text, ["görsel", "gorsel", "resim", "fotoğraf", "fotograf"]) {
            return .image
        }
        if containsAny(text, ["proje", "project"]) {
            return .project
        }
        if containsAny(text, ["belge", "doküman", "dokuman"]) {
            return .document
        }
        return .any
    }

    private func resolveDateField(_ text: String) -> AgentDateField {
        if containsAny(text, ["eklenen", "eklendi", "oluşturulan", "olusturulan"]) {
            return .created
        }
        if containsAny(text, ["değiştirilen", "degistirilen", "düzenlenen", "duzenlenen"]) {
            return .modified
        }
        return .either
    }

    private func resolveDate(
        _ text: String,
        now: Date
    ) -> (range: DateInterval?, description: String?) {
        if containsAny(text, ["bugün", "bugun"]) {
            return (dayInterval(for: now), "bugün")
        }

        if containsAny(text, ["dün", "dun"]) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                return (nil, nil)
            }
            return (dayInterval(for: yesterday), "dün")
        }

        if containsAny(text, ["geçen hafta", "geçtiğimiz hafta", "gecen hafta", "gectigimiz hafta"]) {
            let startToday = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: startToday)
            let daysSinceMonday = (weekday + 5) % 7

            guard let thisMonday = calendar.date(
                byAdding: .day,
                value: -daysSinceMonday,
                to: startToday
            ),
            let previousMonday = calendar.date(
                byAdding: .day,
                value: -7,
                to: thisMonday
            ) else {
                return (nil, nil)
            }

            return (
                DateInterval(start: previousMonday, end: thisMonday),
                "geçen hafta"
            )
        }

        if containsAny(text, ["geçtiğimiz pazar", "geçen pazar", "gecen pazar", "gecmis pazar"]) {
            let startToday = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: startToday)
            let daysSinceSunday = (weekday - 1 + 7) % 7
            let daysBack = daysSinceSunday == 0 ? 7 : daysSinceSunday

            if let sunday = calendar.date(byAdding: .day, value: -daysBack, to: startToday) {
                return (dayInterval(for: sunday), "geçtiğimiz pazar")
            }
        }

        if let explicit = explicitDayMonth(in: text, now: now) {
            return (dayInterval(for: explicit.date), explicit.label)
        }

        return (nil, nil)
    }

    private func explicitDayMonth(
        in text: String,
        now: Date
    ) -> (date: Date, label: String)? {
        let months: [(names: [String], number: Int, display: String)] = [
            (["ocak"], 1, "Ocak"),
            (["şubat", "subat"], 2, "Şubat"),
            (["mart"], 3, "Mart"),
            (["nisan"], 4, "Nisan"),
            (["mayıs", "mayis"], 5, "Mayıs"),
            (["haziran"], 6, "Haziran"),
            (["temmuz"], 7, "Temmuz"),
            (["ağustos", "agustos"], 8, "Ağustos"),
            (["eylül", "eylul"], 9, "Eylül"),
            (["ekim"], 10, "Ekim"),
            (["kasım", "kasim"], 11, "Kasım"),
            (["aralık", "aralik"], 12, "Aralık")
        ]

        let tokens = text
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)

        for month in months {
            for monthName in month.names {
                guard let index = tokens.firstIndex(of: monthName) else { continue }

                let candidateIndexes = [index - 1, index + 1]
                for candidateIndex in candidateIndexes where tokens.indices.contains(candidateIndex) {
                    guard let day = Int(tokens[candidateIndex]), (1...31).contains(day) else {
                        continue
                    }

                    var components = calendar.dateComponents([.year], from: now)
                    components.month = month.number
                    components.day = day
                    components.hour = 12

                    if let date = calendar.date(from: components) {
                        return (date, "\(day) \(month.display)")
                    }
                }
            }
        }

        return nil
    }

    private func dayInterval(for date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    private func fileSearchGoal(
        target: AgentTargetKind,
        dateDescription: String?,
        newestFirst: Bool
    ) -> String {
        let targetText: String
        switch target {
        case .video: targetText = "videoları"
        case .image: targetText = "görselleri"
        case .document: targetText = "belgeleri"
        case .project: targetText = "proje dosyalarını"
        case .screenshot: targetText = "ekran görüntülerini"
        case .pdf: targetText = "PDF dosyalarını"
        case .folder: targetText = "klasörleri"
        case .any: targetText = "dosyaları"
        }

        var parts = [targetText]
        if let dateDescription {
            parts.append(dateDescription + " filtresiyle")
        }
        if newestFirst {
            parts.append("en yeniden eskiye")
        }

        return parts.joined(separator: " ") + " bul"
    }

    private func isApproval(_ text: String) -> Bool {
        [
            "evet", "onayla", "tamam", "devam", "yap",
            "olur", "taşı", "tasi", "onaylıyorum", "onayliyorum"
        ].contains(text)
    }

    private func isRejection(_ text: String) -> Bool {
        [
            "hayır", "hayir", "iptal", "vazgeç", "vazgec", "yapma"
        ].contains(text)
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
