import Foundation

struct AgentVerificationSnapshot {
    let hasWorkspace: Bool
    let fileResultCount: Int
    let folderResultCount: Int
    let hasPendingAction: Bool
    let hasUndoAction: Bool
    let unavailableCapabilityIDs: Set<String>
    let selectedCapabilityIDs: Set<String>
    let webResearchResultCount: Int
    let webResearchEvidenceCount: Int
    let webResearchUniqueDomainCount: Int
    let webResearchCanonicalEvidenceCount: Int
}

struct AgentVerifier {
    func verify(
        decision: AgentDecision,
        currentUserInput: String,
        goal: AgentGoalProfile,
        snapshot: AgentVerificationSnapshot
    ) -> AgentVerificationResult {
        if let mismatch = alignmentMismatch(
            decision: decision,
            currentUserInput: currentUserInput,
            goal: goal
        ) {
            return attention(
                mismatch,
                fallback: "Mevcut kullanıcı girdisinden hedefi yeniden türet; önceki turun goal / plan state'ini bu tura taşıma."
            )
        }

        switch decision.intent {
        case .fileSearch:
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

    private func alignmentMismatch(
        decision: AgentDecision,
        currentUserInput: String,
        goal: AgentGoalProfile
    ) -> String? {
        let input = normalize(currentUserInput)

        if decision.intent == .fileSearch ||
           decision.intent == .compoundFileTask {
            guard looksLikeFileSearch(input) else {
                return "Doğrulama durduruldu: seçilen dosya arama hedefi mevcut kullanıcı girdisiyle uyuşmuyor."
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

        if decision.intent == .general,
           goal.outcomes.contains(.locate),
           !looksLikeFileSearch(input) {
            return "Doğrulama durduruldu: mevcut cümle dosya araması istemediği halde eski bir locate hedefi taşındı."
        }

        return nil
    }

    private func looksLikeFileSearch(_ text: String) -> Bool {
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

        return containsAny(text, actions) &&
            containsAny(text, targets)
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
