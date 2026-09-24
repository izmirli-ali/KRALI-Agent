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
    let reason: String
}

/// Owns the boundary between user work and KRALİ self-development.  This is a
/// policy decision only: it grants neither mutation nor broader authority.
struct AgentMissionRouter {
    func classify(_ input: String) -> AgentMissionRoutingDecision {
        let words = Set(normalize(input))

        let selfTerms: Set<String> = [
            "krali", "kralinin", "kralı", "sistemin", "uygulaman", "agentin",
            "agent", "kendi", "mimarini", "mimarisini", "kodunu"
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

        // Protected authority is never allowed to fall through to runtime
        // when it is attached to even a tentative self-improvement request.
        if selfScore > 0 && (diagnosisScore + improvementScore) > 0 && protectedAuthority {
            return AgentMissionRoutingDecision(
                owner: .stop,
                phase: .authorityEscalation,
                reason: "Self-development cannot grant protected authority; user review is required."
            )
        }

        // A self reference alone is deliberately insufficient.  The request
        // must join KRALİ-as-target with diagnosis or improvement intent.
        guard selfScore > 0 && (diagnosisScore + improvementScore) >= 2 else {
            return AgentMissionRoutingDecision(
                owner: .runtime,
                phase: .runtime,
                reason: "Goal is external/user work, not a supported KRALİ self-development intent."
            )
        }

        return AgentMissionRoutingDecision(
            owner: .developer,
            phase: .diagnosis,
            reason: "KRALİ is the target and the request asks for supported diagnosis/improvement."
        )
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
