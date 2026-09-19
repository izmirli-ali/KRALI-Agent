import Foundation

struct AgentPlanner {
    func makePlan(
        decision: AgentDecision,
        context: AgentContextSnapshot
    ) -> AgentExecutionPlan {
        let executeDetail: String
        let fallback: String?

        switch decision.intent {
        case .fileSearch:
            executeDetail = decision.usePreviousResults
                ? "Önceki sonuç kümesinde yeni filtreyi uygula."
                : "Seçili çalışma alanında salt-okunur aramayı çalıştır."
            fallback = "Filtreyi gevşet, kapsamı yeniden kontrol et veya dosya adına göre daralt."

        case .organizeScreenshots:
            executeDetail = "Aday ekran görüntülerini belirle ve gerçek taşıma öncesi onay planı oluştur."
            fallback = "Hiçbir dosyayı değiştirmeden adayları sadece listele."

        case .approve:
            executeDetail = "Onaylanmış dosya işlemini güvenlik sınırları içinde uygula."
            fallback = "İşlemi durdur, dosya durumunu yeniden indeksle ve güvenli planı tekrar oluştur."

        case .undo:
            executeDetail = "Son geri alınabilir dosya taşıma kaydını tersine uygula."
            fallback = "Dosya konumlarını yeniden indeksle ve geri alınamayan öğeleri ayrı raporla."

        case .openPreviousResult:
            executeDetail = "Konuşma bağlamındaki doğru sonucu çöz ve Finder'da göster."
            fallback = "Önceki sonuçları yeniden listele ve referansı yeniden çöz."

        case .assessWorkspace:
            executeDetail = "Çalışma alanını değiştirmeden oku, dağılımı incele ve seçenekleri çıkar."
            fallback = "Daha küçük bir klasör kapsamıyla yeniden incele."

        case .reject:
            executeDetail = "Bekleyen gerçek işlemi dosyalara dokunmadan iptal et."
            fallback = nil

        case .conversation, .contextSuggestion, .remember, .workMail, .futureCapability, .general:
            executeDetail = decision.selectedPlan
            fallback = decision.alternatives.first
        }

        let verifyDetail: String
        switch decision.intent {
        case .conversation, .contextSuggestion, .remember, .workMail, .futureCapability, .general:
            verifyDetail = "Bu turda gerçek araç işlemi olmadığı için yalnızca karar tutarlılığını kaydet."
        default:
            verifyDetail = "İşlem sonrası durumu tekrar oku ve hedefin gerçekleşip gerçekleşmediğini kontrol et."
        }

        let requiresVerification: Bool
        switch decision.intent {
        case .conversation, .contextSuggestion, .remember, .workMail, .futureCapability, .general:
            requiresVerification = false
        default:
            requiresVerification = true
        }

        let workspaceDetail = context.hasWorkspace
            ? "Aktif çalışma alanı ve son konuşma bağlamını hesaba kat."
            : "Aktif çalışma alanı yoksa bunu plan kısıtı olarak koru."

        return AgentExecutionPlan(
            goal: decision.goal,
            steps: [
                AgentExecutionStep(
                    title: "Anla",
                    detail: "Niyet, hedef, nesne ve zaman bilgisini çıkar."
                ),
                AgentExecutionStep(
                    title: "Bağlam + Plan",
                    detail: workspaceDetail + " " + decision.selectedPlan
                ),
                AgentExecutionStep(
                    title: "Uygula",
                    detail: executeDetail
                ),
                AgentExecutionStep(
                    title: "Doğrula",
                    detail: verifyDetail
                )
            ],
            fallback: fallback,
            requiresVerification: requiresVerification
        )
    }
}
