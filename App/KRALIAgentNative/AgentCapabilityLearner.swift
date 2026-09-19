import Foundation

enum CapabilityLearningState: String, Hashable {
    case readyToResearch
    case waitingForResearchAccess
    case bootstrapRequired
    case integrationRequired

    var title: String {
        switch self {
        case .readyToResearch: return "Araştırmaya hazır"
        case .waitingForResearchAccess: return "Araştırma erişimi bekliyor"
        case .bootstrapRequired: return "Bootstrap gerekli"
        case .integrationRequired: return "Entegrasyon gerekli"
        }
    }

    var systemImage: String {
        switch self {
        case .readyToResearch: return "magnifyingglass.circle.fill"
        case .waitingForResearchAccess: return "clock.badge.exclamationmark"
        case .bootstrapRequired: return "wrench.and.screwdriver.fill"
        case .integrationRequired: return "puzzlepiece.extension.fill"
        }
    }
}

struct CapabilityLearningPlan: Identifiable, Hashable {
    var id: String { capabilityID }

    let capabilityID: String
    let capabilityName: String
    let state: CapabilityLearningState
    let researchGoal: String
    let nextStep: String
    let canResearchAutonomously: Bool
    let requiresApprovalBeforeActivation: Bool
}

struct AgentCapabilityLearner {
    func makePlans(
        for capabilities: [AgentCapability],
        webResearchAvailable: Bool
    ) -> [CapabilityLearningPlan] {
        let unavailable = capabilities.filter { !$0.isAvailable }
        guard !unavailable.isEmpty else { return [] }

        return unavailable.map {
            plan(
                for: $0,
                webResearchAvailable: webResearchAvailable
            )
        }
    }

    private func plan(
        for capability: AgentCapability,
        webResearchAvailable: Bool
    ) -> CapabilityLearningPlan {
        if capability.id == "research.web" {
            return CapabilityLearningPlan(
                capabilityID: capability.id,
                capabilityName: capability.name,
                state: .bootstrapRequired,
                researchGoal: "Güvenilir web arama sağlayıcısı veya tarayıcı tabanlı araştırma köprüsü seç; kaynak güvenilirliği ve alıntı doğrulama kurallarını belirle.",
                nextStep: "Önce web araştırma capability'sini güvenli bir sağlayıcı / browser bridge ile KRALİ'ye bağla. Bu yetenek kendi kendini web üzerinden bootstrap edemez.",
                canResearchAutonomously: false,
                requiresApprovalBeforeActivation: true
            )
        }

        let researchGoal = researchGoal(for: capability)
        let nextStep = nextStep(
            for: capability,
            webResearchAvailable: webResearchAvailable
        )

        if !webResearchAvailable {
            return CapabilityLearningPlan(
                capabilityID: capability.id,
                capabilityName: capability.name,
                state: .waitingForResearchAccess,
                researchGoal: researchGoal,
                nextStep: nextStep,
                canResearchAutonomously: false,
                requiresApprovalBeforeActivation: true
            )
        }

        let needsExternalIntegration =
            capability.risk == .external ||
            capability.id == "premiere.control" ||
            capability.id == "mail.work" ||
            capability.id == "browser.control"

        return CapabilityLearningPlan(
            capabilityID: capability.id,
            capabilityName: capability.name,
            state: needsExternalIntegration ? .integrationRequired : .readyToResearch,
            researchGoal: researchGoal,
            nextStep: nextStep,
            canResearchAutonomously: true,
            requiresApprovalBeforeActivation: true
        )
    }

    private func researchGoal(
        for capability: AgentCapability
    ) -> String {
        switch capability.id {
        case "perception.media":
            return "macOS üzerinde video/görsel içerik analizi için Vision, AVFoundation, Core ML ve ses analizi seçeneklerini resmi dokümanlardan karşılaştır; yerel, hızlı ve doğrulanabilir bir mimari öner."

        case "browser.control":
            return "macOS tarayıcı otomasyonu için güvenli browser bridge, Accessibility ve desteklenen otomasyon API'lerini resmi kaynaklardan karşılaştır."

        case "premiere.control":
            return "Premiere Pro otomasyonu için güncel resmi API/UXP/CEP seçeneklerini, desteklenen komutları ve güvenli doğrulama yöntemlerini araştır."

        case "mail.work":
            return "Mail okuma/taslak/gönderim için sağlayıcı API'leri, OAuth izin kapsamları ve gönderim öncesi onay modelini araştır."

        default:
            return "\(capability.name) yeteneğini kazanmak için resmi dokümantasyon, güvenli entegrasyon seçenekleri ve test yöntemlerini araştır."
        }
    }

    private func nextStep(
        for capability: AgentCapability,
        webResearchAvailable: Bool
    ) -> String {
        if !webResearchAvailable {
            return "Ön koşul: Web araştırma capability'sini bağla. Ardından resmi kaynakları araştır, çözüm taslağı çıkar, izole prototip üret ve test et."
        }

        switch capability.risk {
        case .reasoning, .readOnly:
            return "Resmi kaynakları araştır → en düşük riskli yaklaşımı seç → izole prototip oluştur → test et → kullanıcı onayından sonra capability olarak etkinleştir."

        case .reversibleWrite:
            return "Resmi kaynakları araştır → geri alınabilir prototip oluştur → test et → yazma izinlerini ve geri alma davranışını kullanıcıya göster → onaydan sonra etkinleştir."

        case .external:
            return "Resmi API/entegrasyonu araştır → gereken hesap/izinleri çıkar → bağlantıyı sandbox/test ortamında doğrula → kullanıcı onayından sonra etkinleştir."
        }
    }
}
