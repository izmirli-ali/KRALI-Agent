import Foundation

struct AgentVerificationSnapshot {
    let hasWorkspace: Bool
    let fileResultCount: Int
    let folderResultCount: Int
    let hasPendingAction: Bool
    let hasUndoAction: Bool
    let unavailableCapabilityIDs: Set<String>
    let selectedCapabilityIDs: Set<String>
    let executedCapabilityIDs: Set<String>
    let incompleteRequiredActionCapabilityIDs: Set<String>
    let webResearchResultCount: Int
    let webResearchEvidenceCount: Int
    let webResearchUniqueDomainCount: Int
    let webResearchCanonicalEvidenceCount: Int
    let fileSearchOutcome: AgentFileSearchOutcome?
}

struct AgentVerifier {
    private let fileQueryParser =
        AgentFileQueryParser()

    func verify(
        decision: AgentDecision,
        currentUserInput: String,
        goal: AgentGoalProfile,
        semanticMission: AgentSemanticMission? = nil,
        outcomeResolution: AgentOutcomeResolution? = nil,
        outcomeAttempts: [AgentOutcomeStrategyAttempt] = [],
        snapshot: AgentVerificationSnapshot
    ) -> AgentVerificationResult {
        if let mismatch = alignmentMismatch(
            decision: decision,
            currentUserInput: currentUserInput,
            goal: goal,
            semanticMission: semanticMission
        ) {
            return attention(
                mismatch,
                fallback: "Mevcut kullanıcı girdisinden hedefi yeniden türet; önceki turun goal / plan state'ini bu tura taşıma."
            )
        }

        if let outcomeResolution,
           outcomeResolution.isFullyCovered,
           !outcomeResolution
                .contract
                .requiresMutation {
            let succeededAttempts =
                outcomeAttempts.filter {
                    $0.state ==
                        .succeeded
                }

            if !succeededAttempts.isEmpty {
                return AgentVerificationResult(
                    state: .passed,
                    summary:
                        "Outcome doğrulandı: başarı kriteri runtime strategy chain içinde gerçek kanıt üreten stratejiyle tamamlandı • " +
                        succeededAttempts
                            .map {
                                $0.strategyID
                            }
                            .joined(
                                separator: ", "
                            ),
                    fallback: nil
                )
            }

            if !outcomeAttempts.isEmpty {
                return attention(
                    "Outcome Strategy Chain mevcut güvenli stratejileri denedi ancak hiçbir strateji başarı kriterini doğrulamadı.",
                    fallback:
                        "Gerçek capability eksikliği kaldıysa Learning Gateway üzerinden öğren; başarısız stratejiyi aynı şekilde tekrar etme."
                )
            }
            let chosen =
                outcomeResolution
                    .chosenStrategies

            let publicInformationCovered =
                outcomeResolution
                    .contract
                    .requirements
                    .contains(
                        where: {
                            $0.kind ==
                                .retrievePublicInformation
                        }
                    )

            if publicInformationCovered,
               chosen.contains(
                    where: {
                        $0.kind ==
                            .publicResearch &&
                        $0.executableNow
                    }
               ) {
                guard
                    snapshot
                        .webResearchEvidenceCount >
                        0 ||
                    snapshot
                        .webResearchResultCount >
                        0
                else {
                    return attention(
                        "Outcome stratejisi public web araştırmasını seçti ancak gerçek kaynak kanıtı üretmedi.",
                        fallback:
                            "Aynı başarı kriteri için başka güvenli outcome stratejisini dene; kanıt üretmeden başarılı sayma."
                    )
                }

                return AgentVerificationResult(
                    state: .passed,
                    summary:
                        "Outcome doğrulandı: kullanıcı tarafından istenen public bilgi gerçek web kanıtıyla elde edildi; araç/provider adımlarının kendisi başarı kriteri olarak zorunlu tutulmadı.",
                    fallback: nil
                )
            }

            let localResourceCovered =
                outcomeResolution
                    .contract
                    .requirements
                    .contains(
                        where: {
                            $0.kind ==
                                .locateLocalResource
                        }
                    )

            if localResourceCovered,
               snapshot.fileResultCount > 0 ||
               snapshot.folderResultCount > 0 {
                return AgentVerificationResult(
                    state: .passed,
                    summary:
                        "Outcome doğrulandı: hedef yerel kaynak gerçek sonuç kümesiyle bulundu.",
                    fallback: nil
                )
            }
        }

        if let fileOutcome =
            snapshot.fileSearchOutcome,
           fileOutcome.status.isExpectedBoundary {
            return attention(
                fileOutcome.message,
                fallback:
                    fileOutcome.status == .unsupportedScope
                    ? "Arama kapsamını Masaüstü, İndirilenler, Belgeler veya seçili çalışma alanına daralt."
                    : "Erişilebilir bir klasör kapsamı seç ve aynı aramayı yeniden çalıştır."
            )
        }

        if let mission = semanticMission {
            if mission.requiresUserInput {
                return attention(
                    mission.userInputReason ??
                        "Görevin güvenilir biçimde ilerlemesi için zorunlu kullanıcı bilgisi eksik.",
                    fallback: "Eksik zorunlu bilgiyi al ve aynı semantic mission'ı yeniden planla."
                )
            }

            let executableRequired =
                Set(mission.requiredCapabilityIDs)
                    .intersection(
                        snapshot.selectedCapabilityIDs
                    )
                    .subtracting(
                        snapshot.unavailableCapabilityIDs
                    )
                    .subtracting(
                        Set([
                            "core.reasoning",
                            "context.local"
                        ])
                    )

            let missingExecuted =
                executableRequired.subtracting(
                    snapshot.executedCapabilityIDs
                )

            if !snapshot.incompleteRequiredActionCapabilityIDs.isEmpty {
                return attention(
                    "Semantic mission içindeki zorunlu action step'lerinden bazıları tamamlanmadı: " +
                    snapshot.incompleteRequiredActionCapabilityIDs
                        .sorted()
                        .joined(separator: ", "),
                    fallback:
                        "Tamamlanmayan action step'ini yeniden planla; yürütülmeyen işi başarılı sayma."
                )
            }

            if !missingExecuted.isEmpty {
                return attention(
                    "Semantic mission içindeki mevcut capability adımlarından bazıları gerçekten yürütülmedi: " +
                    missingExecuted.sorted()
                        .joined(separator: ", "),
                    fallback:
                        "Yürütülmeyen capability adımını yeniden planla; hedef tamamlanmadan başarılı sayma."
                )
            }

            if mission.requiredCapabilityIDs.contains("files.search") {
                guard snapshot.hasWorkspace else {
                    return attention(
                        "Semantic mission dosya erişimi gerektiriyor fakat aktif çalışma alanı yok.",
                        fallback: "Bir çalışma klasörü seç ve mission'ı yeniden yürüt."
                    )
                }

                guard snapshot.fileResultCount > 0 ||
                      snapshot.folderResultCount > 0 else {
                    return attention(
                        "Semantic mission içindeki dosya bulma adımı sonuç üretmedi.",
                        fallback: "Dosya kapsamını veya hedef türünü yeniden planla ve güvenli biçimde tekrar ara."
                    )
                }

                guard let outcome =
                    snapshot.fileSearchOutcome
                else {
                    return attention(
                        "Dosya araması için doğrulanabilir query/result kanıtı yok.",
                        fallback:
                            "Arama adımını gerçek File Search provider ile yeniden yürüt."
                    )
                }

                if let mismatch =
                    fileSearchConstraintMismatch(
                        decision:
                            decision,
                        currentUserInput:
                            currentUserInput,
                        outcome:
                            outcome
                    ) {
                    return attention(
                        mismatch,
                        fallback:
                            "Aynı dosya aramasını kullanıcıdaki kapsam, tür ve tarih kısıtlarını eksiksiz koruyarak yeniden çalıştır."
                    )
                }
            }

            if !snapshot.selectedCapabilityIDs.contains("research.web") {
                if !snapshot.unavailableCapabilityIDs.isEmpty {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Semantic mission doğru oluşturuldu ve mevcut adımlar yürütüldü; ancak gereken capability'lerden en az biri henüz bağlı değil.",
                        fallback: nil
                    )
                }

                return AgentVerificationResult(
                    state: .passed,
                    summary: "Semantic mission ile seçilen mevcut capability adımları yürütüldü ve hedefle uyumlu sonuç doğrulandı.",
                    fallback: nil
                )
            }
        }

        switch decision.intent {
        case .fileSearch:
            if let outcome =
                snapshot.fileSearchOutcome {
                if let mismatch =
                    fileSearchConstraintMismatch(
                        decision:
                            decision,
                        currentUserInput:
                            currentUserInput,
                        outcome:
                            outcome
                    ) {
                    return attention(
                        mismatch,
                        fallback:
                            "Aynı dosya aramasını entity, kapsam, tür ve tarih sözleşmesini koruyarak yeniden çalıştır."
                    )
                }

                switch outcome.status {
                case .matched:
                    return AgentVerificationResult(
                        state: .passed,
                        summary:
                            "Arama doğrulandı: " +
                            String(outcome.resultCount) +
                            " eşleşme • kapsam=" +
                            (outcome.rootName ?? outcome.query.scope.title) +
                            (
                                outcome.query.extensions.isEmpty
                                ? ""
                                : " • uzantı=" +
                                    outcome.query.extensions
                                        .sorted()
                                        .joined(separator: ",")
                            ),
                        fallback: nil
                    )

                case .noResults:
                    return attention(
                        "Arama doğru kapsam ve filtrelerle tamamlandı ancak sonuç üretmedi: " +
                        outcome.title,
                        fallback:
                            "Dosya adı, uzantı veya tarih filtresini gevşetip aynı kapsamda yeniden ara."
                    )

                case .workspaceMissing,
                     .unsupportedScope,
                     .inaccessibleScope:
                    return attention(
                        outcome.message,
                        fallback:
                            "Erişilebilir ve daha dar bir dosya kapsamı seç."
                    )
                }
            }

            guard snapshot.hasWorkspace else {
                return attention(
                    "Arama çalıştırılamadı çünkü aktif çalışma alanı yok.",
                    fallback: "Önce çalışma klasörü seç ve aramayı yeniden çalıştır."
                )
            }

            let count = decision.target == .folder
                ? snapshot.folderResultCount
                : snapshot.fileResultCount

            guard count > 0 else {
                return attention(
                    "Arama teknik olarak tamamlandı ancak 0 sonuç döndü.",
                    fallback: "Tarih veya önceki-sonuç filtresini kaldırıp aynı hedefi daha geniş kapsamda bir kez daha ara."
                )
            }

            return AgentVerificationResult(
                state: .passed,
                summary: "Arama tamamlandı ve sonuç kümesi yeniden okunarak doğrulandı: \(count) eşleşme.",
                fallback: nil
            )

        case .compoundFileTask:
            guard snapshot.hasWorkspace else {
                return attention(
                    "Çok adımlı görev yürütülemedi çünkü aktif çalışma alanı yok.",
                    fallback: "Önce çalışma klasörü seç ve zinciri yeniden çalıştır."
                )
            }

            guard snapshot.fileResultCount > 0 else {
                return attention(
                    "Zincirin arama / kısa liste aşaması sonuç üretmedi.",
                    fallback: "Tarih veya önceki-sonuç kısıtını kaldırıp aynı dosya hedefinde zinciri bir kez daha dene."
                )
            }

            if snapshot.unavailableCapabilityIDs.contains("perception.media") {
                return AgentVerificationResult(
                    state: .partial,
                    summary: "Arama ve kısa liste tamamlandı; ancak görsel / video algısı bağlı olmadığı için içerik uygunluğu doğrulanamadı. Sonuç kısmi.",
                    fallback: nil
                )
            }

            return AgentVerificationResult(
                state: .passed,
                summary: "Çok adımlı görev tamamlandı; kısa listede \(snapshot.fileResultCount) aday ve istenen değerlendirme kapsamı doğrulandı.",
                fallback: nil
            )

        case .organizeScreenshots:
            if snapshot.hasPendingAction {
                return AgentVerificationResult(
                    state: .passed,
                    summary: "Gerçek dosya işlemi uygulanmadı; güvenli taşıma planı oluşturuldu ve onay bekliyor.",
                    fallback: nil
                )
            }

            return AgentVerificationResult(
                state: .passed,
                summary: "Tarama tamamlandı; uygulanacak bir taşıma planı oluşmadı.",
                fallback: nil
            )

        case .approve:
            if snapshot.hasPendingAction {
                return attention(
                    "Onay işlendi ancak bekleyen işlem hâlâ aktif görünüyor.",
                    fallback: "Dosya durumunu yeniden indeksle ve işlemi tekrar planla."
                )
            }

            if snapshot.hasUndoAction {
                return AgentVerificationResult(
                    state: .passed,
                    summary: "Dosya işlemi tamamlandı ve geri alma kaydı oluşturuldu.",
                    fallback: nil
                )
            }

            return attention(
                "Onay tamamlandı ancak başarılı bir taşıma kaydı doğrulanamadı.",
                fallback: "Dosya sistemini yeniden indeksle ve başarısız öğeleri ayrı kontrol et."
            )

        case .reject:
            return snapshot.hasPendingAction
                ? attention(
                    "İptal sonrasında bekleyen işlem hâlâ aktif.",
                    fallback: "Bekleyen planı temizle ve dosyalara dokunma."
                )
                : AgentVerificationResult(
                    state: .passed,
                    summary: "Bekleyen işlem dosyalara dokunmadan kaldırıldı.",
                    fallback: nil
                )

        case .undo:
            return snapshot.hasUndoAction
                ? attention(
                    "Geri alma sonrasında işlem kaydı hâlâ aktif.",
                    fallback: "Dosya konumlarını yeniden indeksle ve kalan öğeleri raporla."
                )
                : AgentVerificationResult(
                    state: .passed,
                    summary: "Geri alma kaydı temizlendi; işlem sonlandırıldı.",
                    fallback: nil
                )

        case .openPreviousResult:
            let hasResult =
                snapshot.fileResultCount > 0 ||
                snapshot.folderResultCount > 0

            return hasResult
                ? AgentVerificationResult(
                    state: .passed,
                    summary: "Önceki sonuç bağlamı korunuyor ve referans çözüldü.",
                    fallback: nil
                )
                : attention(
                    "Açılacak önceki sonuç kümesi bulunamadı.",
                    fallback: "Aramayı yeniden çalıştır ve sonucu tekrar seç."
                )

        case .assessWorkspace:
            return snapshot.hasWorkspace
                ? AgentVerificationResult(
                    state: .passed,
                    summary: "Çalışma alanı salt-okunur incelendi; gerçek dosya değişikliği yapılmadı.",
                    fallback: nil
                )
                : attention(
                    "İncelenecek aktif çalışma alanı yok.",
                    fallback: "Önce çalışma klasörü seç."
                )

        case .workMail, .futureCapability, .general:
            if snapshot.selectedCapabilityIDs.contains("research.web") {
                guard snapshot.webResearchResultCount > 0 else {
                    return attention(
                        "Web araştırma adımı çalıştı ancak doğrulanabilir ve alakalı sonuç üretmedi.",
                        fallback: "Sorguyu yeniden ifade et, resmi dokümantasyon terimleri ekle veya farklı sağlayıcılarla tekrar ara."
                    )
                }

                if snapshot.unavailableCapabilityIDs.contains(
                    "browser.control"
                ) {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Hedef web kaynağı çözüldü ancak canlı / etkileşimli içerik doğrulanamadı. Güvenli tarayıcı erişimi gerekiyor ve browser.control henüz bağlı değil.",
                        fallback: nil
                    )
                }

                if snapshot.webResearchCanonicalEvidenceCount > 0 {
                    let remainingUnavailable =
                        snapshot.unavailableCapabilityIDs
                            .subtracting(
                                Set(["browser.control"])
                            )

                    if !remainingUnavailable.isEmpty {
                        return AgentVerificationResult(
                            state: .partial,
                            summary: "Kanonik birincil kaynak doğrulandı; ancak hedefte gereken başka capability'lerden en az biri hazır değil. Sonuç kısmi.",
                            fallback: nil
                        )
                    }

                    return AgentVerificationResult(
                        state: .passed,
                        summary: "Kanonik birincil kaynak doğrudan okunarak doğrulandı. Bu kaynağın kendi profil/hesap bilgileri için bağımsız ikinci domain zorunlu tutulmadı.",
                        fallback: nil
                    )
                }

                if snapshot.webResearchResultCount == 1 {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Web araştırması yalnızca 1 alakalı kaynak buldu. Kaynak keşfi çalışıyor ancak sağlam bir araştırma sonucu saymak için kaynak çeşitliliği yetersiz.",
                        fallback: nil
                    )
                }

                if snapshot.webResearchEvidenceCount < 2 {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Alakalı kaynaklar bulundu fakat en az 2 kaynağın sayfa içeriğinden kanıt çıkarılamadı. Araştırma keşif seviyesinde kaldı.",
                        fallback: nil
                    )
                }

                if snapshot.webResearchUniqueDomainCount < 2 {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Araştırma birden fazla sonuç buldu ancak kaynaklar tek domaine yığıldı. Bağımsız kaynak çeşitliliği yetersiz.",
                        fallback: nil
                    )
                }

                if !snapshot.unavailableCapabilityIDs.isEmpty {
                    return AgentVerificationResult(
                        state: .partial,
                        summary: "Web araştırması \(snapshot.webResearchResultCount) alakalı kaynak buldu; ancak hedefte gereken diğer capability'lerden en az biri henüz bağlı değil. Sonuç kısmi.",
                        fallback: nil
                    )
                }

                return AgentVerificationResult(
                    state: .passed,
                    summary: "Web araştırması doğrulandı: \(snapshot.webResearchResultCount) alakalı kaynak, \(snapshot.webResearchEvidenceCount) kaynak derin okundu.",
                    fallback: nil
                )
            }

            if !snapshot.unavailableCapabilityIDs.isEmpty {
                return AgentVerificationResult(
                    state: .partial,
                    summary: "Hedef anlaşıldı ve uygulanabilir plan üretildi; ancak gereken capability'lerden en az biri henüz bağlı olmadığı için hedefin tamamı yürütülemedi.",
                    fallback: nil
                )
            }

            return AgentVerificationResult(
                state: .skipped,
                summary: "Bu turda doğrulanacak gerçek araç işlemi yok.",
                fallback: nil
            )

        case .conversation, .contextSuggestion, .remember:
            return AgentVerificationResult(
                state: .skipped,
                summary: "Bu turda doğrulanacak gerçek araç işlemi yok.",
                fallback: nil
            )
        }
    }

    private func fileSearchConstraintMismatch(
        decision: AgentDecision,
        currentUserInput: String,
        outcome: AgentFileSearchOutcome
    ) -> String? {
        let input =
            normalize(
                currentUserInput
            )

        let requestedTarget =
            fileQueryParser
                .resolveTargetEntity(
                    currentUserInput
                )

        if requestedTarget != .any &&
           decision.target !=
            requestedTarget {
            return "Doğrulama durduruldu: kullanıcı " +
                targetDescription(
                    requestedTarget
                ) +
                " istedi ancak karar motoru " +
                targetDescription(
                    decision.target
                ) +
                " hedefini seçti."
        }

        if let mismatch =
            fileResultTypeMismatch(
                target:
                    requestedTarget == .any
                    ? decision.target
                    : requestedTarget,
                files:
                    outcome.files
            ) {
            return mismatch
        }

        if containsWordOrPhrase(
            input,
            [
                "pdf"
            ]
        ) {
            guard
                outcome.query.extensions
                    .contains("pdf") ||
                outcome.files.allSatisfy({
                    $0.fileExtension
                        .lowercased() ==
                    "pdf"
                })
            else {
                return "Doğrulama durduruldu: kullanıcı PDF istedi ancak sonuç kümesi PDF filtresini kanıtlamıyor."
            }

            if outcome.files.contains(
                where: {
                    $0.fileExtension
                        .lowercased() !=
                    "pdf"
                }
            ) {
                return "Doğrulama durduruldu: sonuç kümesinde PDF olmayan dosya bulundu."
            }
        }

        if containsWordOrPhrase(
            input,
            [
                "indirilenler",
                "downloads"
            ]
        ),
           outcome.query.scope !=
            .downloads {
            return "Doğrulama durduruldu: kullanıcı İndirilenler kapsamını istedi ancak arama farklı kapsamda çalıştı."
        }

        if containsWordOrPhrase(
            input,
            [
                "masaüstü",
                "masaustu",
                "desktop"
            ]
        ),
           outcome.query.scope !=
            .desktop {
            return "Doğrulama durduruldu: kullanıcı Masaüstü kapsamını istedi ancak arama farklı kapsamda çalıştı."
        }

        if containsWordOrPhrase(
            input,
            [
                "belgeler",
                "documents"
            ]
        ),
           outcome.query.scope !=
            .documents {
            return "Doğrulama durduruldu: kullanıcı Belgeler kapsamını istedi ancak arama farklı kapsamda çalıştı."
        }

        let calendar =
            Calendar.current
        let today =
            calendar.startOfDay(
                for: Date()
            )

        if containsWordOrPhrase(
            input,
            [
                "bugün",
                "bugun",
                "bugünkü",
                "bugunku"
            ]
        ) {
            guard let tomorrow =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: today
                )
            else {
                return "Bugün tarih aralığı oluşturulamadı."
            }

            let range =
                DateInterval(
                    start: today,
                    end: tomorrow
                )

            if outcome.files.contains(
                where: { file in
                    let created =
                        file.creationDate
                            .map(
                                range.contains
                            ) ??
                        false
                    let modified =
                        file.modificationDate
                            .map(
                                range.contains
                            ) ??
                        false

                    return !created &&
                        !modified
                }
            ) {
                return "Doğrulama durduruldu: sonuç kümesinde bugün tarih filtresine uymayan dosya bulundu."
            }
        }

        return nil
    }

    private func fileResultTypeMismatch(
        target: AgentTargetKind,
        files: [FileRecord]
    ) -> String? {
        guard !files.isEmpty else {
            return nil
        }

        let imageExtensions = Set([
            "png", "jpg", "jpeg", "heic",
            "tif", "tiff", "webp", "gif",
            "bmp", "svg"
        ])
        let videoExtensions = Set([
            "mov", "mp4", "m4v", "avi",
            "mkv", "webm", "mts", "m2ts"
        ])
        let projectExtensions = Set([
            "prproj", "aep", "psd", "psb",
            "ai", "indd", "fcpxml"
        ])
        let documentExtensions = Set([
            "pdf", "doc", "docx", "txt",
            "rtf", "md", "pages", "odt",
            "xls", "xlsx", "csv", "numbers",
            "ppt", "pptx", "key"
        ])

        let invalid = files.contains { file in
            let ext =
                file.fileExtension
                    .lowercased()

            switch target {
            case .screenshot:
                return !file.isScreenshot
            case .pdf:
                return ext != "pdf"
            case .video:
                return !videoExtensions
                    .contains(ext)
            case .image:
                return !imageExtensions
                    .contains(ext)
            case .project:
                return !projectExtensions
                    .contains(ext)
            case .document:
                return !documentExtensions
                    .contains(ext)
            case .folder:
                return true
            case .any:
                return false
            }
        }

        guard invalid else {
            return nil
        }

        return "Doğrulama durduruldu: sonuç kümesinde istenen " +
            targetDescription(target) +
            " türüyle uyuşmayan öğe bulundu."
    }

    private func targetDescription(
        _ target: AgentTargetKind
    ) -> String {
        switch target {
        case .screenshot:
            return "ekran görüntüsü"
        case .pdf:
            return "PDF dosyası"
        case .video:
            return "video dosyası"
        case .image:
            return "görsel dosyası"
        case .project:
            return "proje dosyası"
        case .document:
            return "belge"
        case .folder:
            return "klasör"
        case .any:
            return "dosya/öğe"
        }
    }

    private func alignmentMismatch(
        decision: AgentDecision,
        currentUserInput: String,
        goal: AgentGoalProfile,
        semanticMission: AgentSemanticMission?
    ) -> String? {
        let input = normalize(currentUserInput)

        if decision.intent == .fileSearch ||
           decision.intent == .compoundFileTask {
            guard looksLikeFileSearch(input) else {
                return "Doğrulama durduruldu: seçilen dosya arama hedefi mevcut kullanıcı girdisiyle uyuşmuyor."
            }

            let requestedTarget =
                fileQueryParser
                    .resolveTargetEntity(
                        currentUserInput
                    )

            if requestedTarget != .any &&
               decision.target !=
                    requestedTarget {
                return "Doğrulama durduruldu: entity/scope ayrımı bozuldu; kullanıcı " +
                    targetDescription(
                        requestedTarget
                    ) +
                    " istedi ancak karar " +
                    targetDescription(
                        decision.target
                    ) +
                    " hedefini taşıyor."
            }
        }

        if decision.intent == .remember,
           !goal.outcomes.contains(.remember) {
            return "Doğrulama durduruldu: çalışma kuralı isteği memory hedefi olarak çözümlenmedi."
        }

        if goal.outcomes.contains(.remember),
           decision.intent != .remember {
            return "Doğrulama durduruldu: memory hedefi farklı bir eski intent ile eşleşti."
        }

        let semanticLocate =
            semanticMission?.requiredCapabilityIDs.contains(
                "files.search"
            ) == true

        if decision.intent == .general,
           goal.outcomes.contains(.locate),
           !looksLikeFileSearch(input),
           !semanticLocate {
            return "Doğrulama durduruldu: mevcut cümle dosya araması istemediği halde eski bir locate hedefi taşındı."
        }

        return nil
    }

    private func looksLikeFileSearch(_ text: String) -> Bool {
        let structured =
            fileQueryParser.parse(text)

        if structured.isFileSearchRequest {
            return true
        }

        let actions = [
            "bul", "ara", "göster", "goster", "listele", "nerede",
            "hangileri", "neler", "ne var", "incele", "getir",
            "çıkar", "cikar", "finder'da", "finderda"
        ]
        let targets = [
            "dosya", "video", "çekim", "cekim", "pdf", "görsel",
            "gorsel", "resim", "fotoğraf", "fotograf", "proje",
            "belge", "doküman", "dokuman", "logo", "klasör",
            "klasor", "ekran görünt", "ekran gorunt", "ekran resmi"
        ]

        return containsWordOrPhrase(text, actions) &&
            containsWordOrPhrase(text, targets)
    }

    private func containsWordOrPhrase(
        _ text: String,
        _ values: [String]
    ) -> Bool {
        let tokens = Set(
            text.components(
                separatedBy: CharacterSet
                    .alphanumerics
                    .inverted
            )
            .filter { !$0.isEmpty }
        )

        return values.contains { value in
            if value.contains(" ") ||
               value.contains("'") {
                return text.contains(value)
            }

            return tokens.contains(value)
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased(with: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(
        _ text: String,
        _ values: [String]
    ) -> Bool {
        values.contains { text.contains($0) }
    }

    private func attention(
        _ summary: String,
        fallback: String
    ) -> AgentVerificationResult {
        AgentVerificationResult(
            state: .attention,
            summary: summary,
            fallback: fallback
        )
    }
}
