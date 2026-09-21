import Foundation

struct AgentPlanner {
    func makePlan(
        decision: AgentDecision,
        context: AgentContextSnapshot,
        capabilities: [AgentCapability],
        learningPlans: [CapabilityLearningPlan],
        goal: AgentGoalProfile
    ) -> AgentExecutionPlan {
        var steps: [AgentExecutionStep] = [
            AgentExecutionStep(
                title: "Hedefi çöz",
                detail: "Hedef sözleşmesi: \(goal.summary). Kısıtları ve mevcut bağlamı anlamlandır.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )
        ]

        if decision.usePreviousResults ||
           context.previousFileResultCount > 0 ||
           context.previousFolderResultCount > 0 {
            steps.append(
                AgentExecutionStep(
                    title: "Bağlamı bağla",
                    detail: "Önceki sonuçları ve son hedefi yeni isteğin referanslarıyla eşleştir.",
                    kind: .reasoning,
                    capabilityID: "context.local"
                )
            )
        }

        var fallback: String?
        var requiresVerification = false

        switch decision.intent {
        case .conversation:
            steps.append(
                AgentExecutionStep(
                    title: "Yanıt oluştur",
                    detail: "Konuşma bağlamına uygun, kısa ve doğal yanıt üret.",
                    kind: .response
                )
            )

        case .fileSearch:
            steps.append(
                action(
                    "Kapsamı tara",
                    decision.usePreviousResults
                        ? "Önceki sonuç kümesinde istenen filtreyi uygula."
                        : decision.selectedPlan,
                    capability: "files.search"
                )
            )

            if decision.sortMode == .newestFirst || decision.dateRange != nil {
                steps.append(
                    action(
                        "Sonuçları daralt",
                        "Tarih ve sıralama ölçütlerini sonuç kümesine uygula.",
                        capability: "files.metadata"
                    )
                )
            }

            steps.append(verificationStep("Sonuç kümesini yeniden okuyup hedefi doğrula."))
            fallback = "Filtreyi güvenli biçimde gevşet ve aynı hedefi bir kez daha ara."
            requiresVerification = true

        case .compoundFileTask:
            steps += [
                action(
                    "Adayları bul",
                    "Hedef dosyaları salt-okunur ara.",
                    capability: "files.search"
                ),
                action(
                    "Kısa liste oluştur",
                    "İstenen ölçütlere göre sonuç kümesini daha anlamlı adaylara indir.",
                    capability: "files.metadata"
                )
            ]

            if let perception = capabilities.first(where: { $0.id == "perception.media" }) {
                steps.append(
                    action(
                        "İçeriği analiz et",
                        perception.isAvailable
                            ? "Dosyaların görüntü / ses içeriğini doğrudan değerlendir."
                            : "Bu adım için görsel/video algısı gerekiyor; capability bağlı olmadığı için adım bekliyor.",
                        capability: perception.id
                    )
                )
            } else {
                steps.append(
                    action(
                        "Adayları değerlendir",
                        "Mevcut yerel metadata ile açıklanabilir ön değerlendirme yap.",
                        capability: "files.metadata"
                    )
                )
            }

            if goal.outcomes.contains(.explain) {
                steps.append(
                    AgentExecutionStep(
                        title: "Gerekçeyi açıkla",
                        detail: "Tamamlanan ve tamamlanamayan kısımları ayır; sonucu nedenleriyle açıkla.",
                        kind: .response
                    )
                )
            }

            steps.append(verificationStep("Zincirin ürettiği kısa listeyi ve hedef sonucunu doğrula."))
            fallback = "Gereksiz dar filtreleri kaldırıp aynı zinciri salt-okunur yeniden çalıştır."
            requiresVerification = true

        case .assessWorkspace:
            steps += [
                action(
                    "Çalışma alanını gözlemle",
                    "Dosya ve klasör dağılımını değiştirmeden oku.",
                    capability: "files.search"
                ),
                action(
                    "Seçenek üret",
                    "Düşük riskli alternatifleri mevcut dağılıma göre oluştur.",
                    capability: "core.reasoning"
                ),
                verificationStep("İncelemenin dosya değişikliği yapmadan tamamlandığını kontrol et.")
            ]
            fallback = "Daha küçük bir çalışma alanıyla yeniden gözlemle."
            requiresVerification = true

        case .organizeScreenshots:
            steps += [
                action(
                    "Adayları bul",
                    "Doğrudan seçili klasördeki ekran görüntülerini güvenli biçimde belirle.",
                    capability: "files.search"
                ),
                action(
                    "Taşıma planı hazırla",
                    "Hedef klasörü ve çakışma güvenliğini hesapla; henüz dosyayı değiştirme.",
                    capability: "files.move.reversible"
                ),
                action(
                    "Onay bekle",
                    "Gerçek yazma işleminden önce kullanıcı onayını bekle.",
                    capability: "files.move.reversible"
                ),
                verificationStep("Bekleyen planın gerçek işlem yapmadan hazırlandığını doğrula.")
            ]
            fallback = "Dosyaları değiştirmeden yalnızca aday listesini göster."
            requiresVerification = true

        case .approve:
            steps += [
                action(
                    "Güvenlik sınırını kontrol et",
                    "Kaynakların seçili çalışma alanında olduğunu yeniden doğrula.",
                    capability: "files.move.reversible"
                ),
                action(
                    "İşlemi uygula",
                    "Onaylanmış geri alınabilir dosya işlemini uygula.",
                    capability: "files.move.reversible"
                ),
                action(
                    "Durumu yenile",
                    "Dosya sistemini tekrar indeksle ve geri alma kaydını oluştur.",
                    capability: "files.search"
                ),
                verificationStep("Gerçek işlemin hedefe ulaştığını ve geri alma kaydını doğrula.")
            ]
            fallback = "Yazmayı durdur, yeniden indeksle ve güvenli planı tekrar oluştur."
            requiresVerification = true

        case .undo:
            steps += [
                action(
                    "Geri alma kaydını çöz",
                    "Son geri alınabilir hareketleri ters sırada hazırla.",
                    capability: "files.move.reversible"
                ),
                action(
                    "Konumları geri yükle",
                    "Dosyaları çakışma güvenliğiyle önceki konumlarına taşı.",
                    capability: "files.move.reversible"
                ),
                verificationStep("Geri alma kaydının temizlendiğini ve işlemin tamamlandığını kontrol et.")
            ]
            fallback = "Kalan dosya konumlarını yeniden indeksle ve geri alınamayan öğeleri raporla."
            requiresVerification = true

        case .reject:
            steps += [
                action(
                    "Bekleyen planı kaldır",
                    "Dosyalara dokunmadan onay bekleyen işlemi iptal et.",
                    capability: "files.move.reversible"
                ),
                verificationStep("Bekleyen yazma planının temizlendiğini doğrula.")
            ]
            requiresVerification = true

        case .openPreviousResult:
            steps += [
                action(
                    "Referansı çöz",
                    "Önceki sonuçlardan istenen öğeyi belirle.",
                    capability: "context.local"
                ),
                action(
                    "Finder'da göster",
                    "Çözülen dosya veya klasörü Finder'da aç.",
                    capability: "files.reveal"
                ),
                verificationStep("Önceki sonuç bağlamının korunup korunmadığını kontrol et.")
            ]
            fallback = "Sonuçları yeniden listele ve referansı tekrar çöz."
            requiresVerification = true

        case .contextSuggestion:
            steps += [
                action(
                    "Adayları karşılaştır",
                    "Önceki sonuçları mevcut metadata ve bağlama göre karşılaştır.",
                    capability: "files.metadata"
                ),
                AgentExecutionStep(
                    title: "Öneriyi açıkla",
                    detail: "Seçim gerekçesini ve belirsizlikleri kullanıcıya açıkla.",
                    kind: .response
                )
            ]

        case .remember:
            steps += [
                action(
                    "Kuralı ayıkla",
                    "Mesajdan kalıcı çalışma tercihini temiz biçimde çıkar.",
                    capability: "core.reasoning"
                ),
                action(
                    "Yerel hafızaya kaydet",
                    "Açık kullanıcı kuralını yerel belleğe ekle.",
                    capability: "memory.local"
                )
            ]

        case .workMail, .futureCapability, .general:
            steps += [
                action(
                    "Gerekli yetenekleri tara",
                    "Hedef için mevcut ve eksik capability'leri ayır.",
                    capability: "core.reasoning"
                ),
                AgentExecutionStep(
                    title: "Uygulanabilir yolu açıkla",
                    detail: decision.selectedPlan,
                    kind: .response
                )
            ]
            fallback = decision.alternatives.first
        }

        if goal.outcomes.contains(.research) &&
           !steps.contains(where: {
               $0.capabilityID == "research.web"
           }) {
            let researchStep = action(
                "Web'de araştır",
                "Güncel web kaynaklarını bul, semantik olarak sırala ve güvenilir adayları Core'a getir.",
                capability: "research.web"
            )

            let readStep = action(
                "Kaynakları oku",
                "En alakalı kaynakların sayfa içeriğini aç, sorguyla ilgili kanıt cümlelerini çıkar ve yüzey başlık eşleşmesini gerçek içerikten ayır.",
                capability: "research.web"
            )

            if let responseIndex = steps.firstIndex(
                where: { $0.kind == .response }
            ) {
                steps.insert(contentsOf: [researchStep, readStep], at: responseIndex)
            } else if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(contentsOf: [researchStep, readStep], at: verificationIndex)
            } else {
                steps.append(researchStep)
                steps.append(readStep)
            }

            if !steps.contains(where: { $0.kind == .verification }) {
                steps.append(
                    verificationStep(
                        "Web araştırmasının alakalı sonuç üretip üretmediğini ve en az iki kaynaktan sayfa içeriği kanıtı çıkarılıp çıkarılmadığını doğrula."
                    )
                )
            }
            requiresVerification = true
        }

        if goal.outcomes.contains(.analyze) &&
           !steps.contains(where: {
               normalizeStepTitle($0.title).contains("analiz")
           }) {
            let analysisStep = AgentExecutionStep(
                title: "Analiz et",
                detail: "Toplanan kanıtları, bağlamı ve kısıtları birlikte değerlendir; yalnızca yüzey özetleme yapma, neden-sonuç ilişkileri ve belirsizlikleri ayır.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )

            if let responseIndex = steps.firstIndex(
                where: { $0.kind == .response }
            ) {
                steps.insert(analysisStep, at: responseIndex)
            } else if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(analysisStep, at: verificationIndex)
            } else {
                steps.append(analysisStep)
            }
        }

        if goal.outcomes.contains(.transform) &&
           !steps.contains(where: {
               normalizeStepTitle($0.title).contains("istenen formata")
           }) {
            let transformStep = AgentExecutionStep(
                title: "İstenen formata dönüştür",
                detail: "Dönüştürülecek kaynak kullanıcı mesajında doğrudan verilmişse onu kullan; aksi halde önceki bağlamda referans verilen öğeyi seç. Yeni alternatifler üretmeden kaynak içeriği istenen süre, biçim veya yapıya sadık kalarak dönüştür.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )

            if let responseIndex = steps.firstIndex(
                where: { $0.kind == .response }
            ) {
                steps.insert(transformStep, at: responseIndex)
            } else if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(transformStep, at: verificationIndex)
            } else {
                steps.append(transformStep)
            }
        }

        if goal.outcomes.contains(.compose) &&
           !steps.contains(where: {
               normalizeStepTitle($0.title).contains("icerigi olustur")
           }) {
            let composeStep = AgentExecutionStep(
                title: "İçeriği oluştur",
                detail: "Kullanıcının verdiği konu, süre, bölüm sayısı, ton ve biçim kısıtlarını koruyarak doğrudan kullanılabilir içeriği oluştur.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )

            if let responseIndex = steps.firstIndex(
                where: { $0.kind == .response }
            ) {
                steps.insert(composeStep, at: responseIndex)
            } else if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(composeStep, at: verificationIndex)
            } else {
                steps.append(composeStep)
            }
        }

        if goal.outcomes.contains(.ideate) &&
           !steps.contains(where: {
               normalizeStepTitle($0.title).contains("bagimsiz fikir")
           }) {
            let ideationStep = AgentExecutionStep(
                title: "Bağımsız fikir üret",
                detail: "Kullanıcının doğrudan söylediği maddeleri tekrar etmekle yetinme; kanıtlardan ve analizden türetilmiş yeni fırsatlar, alternatifler veya yaratıcı öneriler üret ve bunları gerekçelendir.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )

            if let responseIndex = steps.firstIndex(
                where: { $0.kind == .response }
            ) {
                steps.insert(ideationStep, at: responseIndex)
            } else if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(ideationStep, at: verificationIndex)
            } else {
                steps.append(ideationStep)
            }
        }

        if !learningPlans.isEmpty {
            let learningStep = AgentExecutionStep(
                title: "Yetkinlik edinme planı oluştur",
                detail: "Eksik capability için araştırma hedefini, ön koşulları, prototip/test yolunu ve etkinleştirme onayını çıkar.",
                kind: .reasoning,
                capabilityID: "core.reasoning"
            )

            if let verificationIndex = steps.firstIndex(
                where: { $0.kind == .verification }
            ) {
                steps.insert(learningStep, at: verificationIndex)
            } else {
                steps.append(learningStep)
            }
        }

        let hasUnavailableCapability = capabilities.contains {
            !$0.isAvailable
        }

        if hasUnavailableCapability {
            if !steps.contains(where: { $0.kind == .verification }) {
                steps.append(
                    verificationStep(
                        "Gerekli capability'lerin hazır olup olmadığını ve hedefin hangi kısmının gerçekten tamamlandığını doğrula."
                    )
                )
            }
            requiresVerification = true
        }

        return AgentExecutionPlan(
            goal: goal.summary,
            steps: steps,
            fallback: fallback,
            requiresVerification: requiresVerification
        )
    }

    private func normalizeStepTitle(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
    }

    private func action(
        _ title: String,
        _ detail: String,
        capability: String
    ) -> AgentExecutionStep {
        AgentExecutionStep(
            title: title,
            detail: detail,
            kind: .action,
            capabilityID: capability
        )
    }

    private func verificationStep(
        _ detail: String
    ) -> AgentExecutionStep {
        AgentExecutionStep(
            title: "Doğrula",
            detail: detail,
            kind: .verification
        )
    }
}
