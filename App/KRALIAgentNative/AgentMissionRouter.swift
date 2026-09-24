import Foundation

enum AgentMissionOwner: String, Codable {
    case runtime
    case developer
    case stop
}

enum AgentMissionPhase: String, Codable {
    case runtime
    case diagnosis
    case authorityEscalation = "authority_escalation"
}

struct AgentMissionRoutingDecision: Codable, Hashable {
    let owner: AgentMissionOwner
    let phase: AgentMissionPhase
    let authorityIntent: String
    let authorityPolarity: String
    let reason: String
}

/// Owns the boundary between user work and KRALİ self-development.  This is a
/// policy decision only: it grants neither mutation nor broader authority.
struct AgentMissionRouter {
    func classify(_ input: String) -> AgentMissionRoutingDecision {
        let words = Set(normalize(input))
        let normalized = normalize(input).joined(separator: " ")

        let selfTerms: Set<String> = [
            "krali", "kralinin", "kralı", "sistemin", "uygulaman", "agentin",
            "agent", "kendi", "kendine", "mimarini", "mimarisini", "kodunu", "kodunda"
        ]
        let diagnosisTerms: Set<String> = [
            "neden", "basarisiz", "başarısız", "failure", "hata", "sorun",
            "root", "cause", "teshis", "diagnose", "incele", "denetle",
            "benchmark", "evidence", "kanıt"
        ]
        let improvementTerms: Set<String> = [
            "gelistir", "geliştir", "iyilestir", "iyileştir", "onar", "repair",
            "duzelt", "düzelt", "ekle", "capability", "yetkinlik", "implement"
        ]
        let protectedAuthorityTerms: Set<String> = [
            "merge", "push", "izin", "permission", "yetki", "secret", "sifre",
            "şifre", "credential", "filesystem", "dosya", "authority"
        ]

        let selfScore = words.intersection(selfTerms).count
        let diagnosisScore = words.intersection(diagnosisTerms).count
        let improvementScore = words.intersection(improvementTerms).count
        let protectedAuthority = !words.intersection(protectedAuthorityTerms).isEmpty
        let authority = authoritySemantics(normalized, mentionsProtected: protectedAuthority)

        // Protected authority is never allowed to fall through to runtime
        // when it is attached to even a tentative self-improvement request.
        if authority.isRequested {
            return AgentMissionRoutingDecision(
                owner: .stop,
                phase: .authorityEscalation,
                authorityIntent: authority.intent,
                authorityPolarity: authority.polarity,
                reason: "Self-development cannot grant protected authority; user review is required."
            )
        }

        // A self reference alone is deliberately insufficient.  The request
        // must join KRALİ-as-target with diagnosis or improvement intent.
        let developmentScore = diagnosisScore + improvementScore
        guard selfScore > 0 && (developmentScore >= 2 || (selfScore >= 2 && developmentScore >= 1)) else {
            return AgentMissionRoutingDecision(
                owner: .runtime,
                phase: .runtime,
                authorityIntent: authority.intent,
                authorityPolarity: authority.polarity,
                reason: "Goal is external/user work, not a supported KRALİ self-development intent."
            )
        }

        return AgentMissionRoutingDecision(
            owner: .developer,
            phase: .diagnosis,
            authorityIntent: authority.intent,
            authorityPolarity: authority.polarity,
            reason: "KRALİ is the target and the request asks for supported diagnosis/improvement."
        )
    }

    private func authoritySemantics(
        _ normalized: String,
        mentionsProtected: Bool
    ) -> (intent: String, polarity: String, isRequested: Bool) {
        guard mentionsProtected else { return ("none", "none", false) }

        let discussion = ["neden", "acikla", "açıkla", "analiz et", "tehlikeli", "ornek", "örnek", "policy"]
            .contains { normalized.contains($0) }
        let prohibition = ["merge etme", "push yapma", "genisletme", "genişletme", "bypass etme", "acma", "açma", "kaldirma", "kaldırma"]
            .contains { normalized.contains($0) }
        let selfGrant = normalized.contains("kendine tum filesystem erisimini ac") ||
            normalized.contains("kendine tüm filesystem erişimini aç") ||
            normalized.contains("kendine ver") ||
            normalized.contains("approval sistemini kaldir") ||
            normalized.contains("approval sistemini kaldır") ||
            normalized.contains("onay istemeden uygula") ||
            normalized.contains("onay istemeden main") ||
            normalized.contains("dogrudan maine merge et") ||
            normalized.contains("doğrudan maine merge et")

        if selfGrant && !prohibition && !discussion {
            return ("protected_authority", "requested", true)
        }
        if prohibition { return ("protected_authority", "prohibited", false) }
        if discussion { return ("protected_authority", "descriptive", false) }
        return ("protected_authority", "ambiguous", false)
    }

    private func normalize(_ value: String) -> [String] {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

struct AgentDeveloperRepository: Codable, Hashable {
    let path: String
}

/// Developer work is constrained to a repository with KRALİ's known source
/// shape.  A user-selected workspace is never a fallback candidate.
struct AgentDeveloperRepositoryResolver {
    private let fileManager = FileManager.default

    func resolve(
        configuredRoot: URL? = ProcessInfo.processInfo.environment["KRALI_REPO_ROOT"].map(URL.init(fileURLWithPath:)),
        userWorkspace: URL?
    ) -> AgentDeveloperRepository? {
        let candidate = configuredRoot ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Developer/KRALI-Agent", isDirectory: true)
        let canonical = candidate.standardizedFileURL

        guard canonical != userWorkspace?.standardizedFileURL,
              isKRALIRepository(canonical)
        else { return nil }

        return AgentDeveloperRepository(path: canonical.path)
    }

    private func isKRALIRepository(_ url: URL) -> Bool {
        [".git", "VERSION", "Scripts/run-developer-agent.command", "App/KRALIAgentNative.xcodeproj"]
            .allSatisfy { fileManager.fileExists(atPath: url.appendingPathComponent($0).path) }
    }
}
