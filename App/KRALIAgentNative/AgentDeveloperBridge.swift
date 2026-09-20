import Foundation

struct DeveloperAgentStatus: Hashable {
    let state: String
    let message: String
    let branch: String?
    let worktree: String?

    var isReadyForReview: Bool {
        state == "ready_for_review" ||
        state == "build_failed"
    }

    var isLearningActive: Bool {
        [
            "learning",
            "running",
            "retrying",
            "verifying",
            "repairing_cline",
            "repairing_runtime",
            "sdk_fallback_preparing",
            "sdk_fallback_running",
            "sdk_importing",
            "sdk_import_ready",
            "sdk_provider_ready",
            "sdk_runtime_starting",
            "sdk_runtime_ready",
            "sdk_session_starting",
            "sdk_session_running",
            "sdk_tools_running",
            "sdk_tool_completed",
            "sdk_session_ended",
            "sdk_session_completed",
            "provider_platform_bug"
        ].contains(state)
    }

    var shouldShowLearningStatus: Bool {
        isLearningActive ||
        [
            "ready_for_review",
            "build_failed",
            "sdk_provider_failed",
            "sdk_failed",
            "sdk_watchdog_timeout",
            "failed"
        ].contains(state)
    }

    var learningStageTitle: String {
        switch state {
        case "learning":
            return "Öğreniyor"
        case "running":
            return "Analiz ediyor"
        case "retrying":
            return "Daha hafif modda tekrar deniyor"
        case "verifying":
            return "Adayı doğruluyor"
        case "repairing_cline":
            return "Cline onarılıyor"
        case "repairing_runtime":
            return "Runtime hazırlanıyor"
        case "provider_platform_bug":
            return "Provider platform hatası bulundu"
        case "sdk_fallback_preparing":
            return "SDK fallback hazırlanıyor"
        case "sdk_fallback_running":
            return "SDK üzerinden öğreniyor"
        case "sdk_importing":
            return "SDK yükleniyor"
        case "sdk_import_ready":
            return "SDK hazır"
        case "sdk_provider_ready":
            return "Provider / model hazır"
        case "sdk_runtime_starting":
            return "SDK runtime başlatılıyor"
        case "sdk_runtime_ready":
            return "SDK runtime hazır"
        case "sdk_session_starting":
            return "Model oturumu başlatılıyor"
        case "sdk_session_running":
            return "Model öğreniyor"
        case "sdk_tools_running":
            return "Araçlar çalışıyor"
        case "sdk_tool_completed":
            return "Araç adımı tamamlandı"
        case "sdk_session_ended":
            return "SDK oturumu sonuçlandı"
        case "sdk_session_completed":
            return "Öğrenme oturumu tamamlandı"
        case "ready_for_review":
            return "Öğrenme adayı hazır"
        case "build_failed":
            return "Aday doğrulanamadı"
        case "sdk_provider_failed":
            return "Provider ayarı eksik"
        case "sdk_failed":
            return "SDK öğrenmesi durdu"
        case "sdk_watchdog_timeout":
            return "SDK oturumu takıldı"
        case "failed":
            return "Öğrenme durdu"
        default:
            return "Öğrenme"
        }
    }

    var isSetupRequired: Bool {
        [
            "setup_required",
            "setup_node",
            "setup_homebrew",
            "setup_node_upgrade",
            "setup_cline",
            "setup_node_supported",
            "setup_cline_repair",
            "setup_cline_auth",
            "waiting_cline_auth"
        ].contains(state)
    }

    var setupHint: String? {
        switch state {
        case "setup_node":
            return "Terminal: brew install node"
        case "setup_homebrew":
            return "Önce Homebrew kur; ardından brew install node"
        case "setup_node_upgrade":
            return "Node.js 20+ gerekiyor; Homebrew kullanıyorsan brew upgrade node"
        case "setup_node_supported":
            return "Developer Agent için desteklenen Node.js runtime hazırlanamadı."
        case "waiting_cline_auth":
            return "Cline giriş penceresi otomatik açıldı; tarayıcıdaki girişi tamamla."
        case "setup_cline_repair":
            return "Cline otomatik onarılamadı; Developer Agent logu incelenmeli."
        case "setup_cline_auth":
            return "KRALİ giriş penceresini otomatik açmayı yeniden deneyecek."
        case "setup_cline", "setup_required":
            return "Terminal: npm install -g cline → cline auth openai-codex"
        default:
            return nil
        }
    }
}

enum AgentDebugKind: String, Hashable {
    case dependency
    case authentication
    case permission
    case providerRuntime
    case verificationMismatch
    case externalState
    case unknown

    var title: String {
        switch self {
        case .dependency:
            return "Bağımlılık"
        case .authentication:
            return "Kimlik doğrulama"
        case .permission:
            return "İzin"
        case .providerRuntime:
            return "Provider / Runtime"
        case .verificationMismatch:
            return "Doğrulama uyuşmazlığı"
        case .externalState:
            return "Dış durum"
        case .unknown:
            return "Bilinmeyen hata"
        }
    }

    var systemImage: String {
        switch self {
        case .dependency:
            return "shippingbox"
        case .authentication:
            return "person.badge.key"
        case .permission:
            return "lock.trianglebadge.exclamationmark"
        case .providerRuntime:
            return "terminal"
        case .verificationMismatch:
            return "checkmark.circle.trianglebadge.exclamationmark"
        case .externalState:
            return "arrow.triangle.2.circlepath"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

enum AgentDebugProgress: String, Hashable {
    case investigating
    case recovering
    case recovered
    case escalated

    var title: String {
        switch self {
        case .investigating:
            return "Hata ayıklanıyor"
        case .recovering:
            return "Recovery uygulanıyor"
        case .recovered:
            return "Düzeldi"
        case .escalated:
            return "Geliştirmeye yükseltildi"
        }
    }

    var isActive: Bool {
        self == .investigating ||
        self == .recovering
    }
}

struct AgentDebugIncident: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let source: String
    let kind: AgentDebugKind
    let progress: AgentDebugProgress
    let summary: String
    let evidence: String?
    let recoveryPlan: String
    let attempt: Int

    init(
        source: String,
        kind: AgentDebugKind,
        progress: AgentDebugProgress,
        summary: String,
        evidence: String? = nil,
        recoveryPlan: String,
        attempt: Int = 1
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.source = source
        self.kind = kind
        self.progress = progress
        self.summary = summary
        self.evidence = evidence
        self.recoveryPlan = recoveryPlan
        self.attempt = attempt
    }
}

struct AgentDebugRecoveryCenter {
    func classify(
        source: String,
        message: String,
        evidence: String? = nil,
        exitCode: Int? = nil,
        progress: AgentDebugProgress = .investigating
    ) -> AgentDebugIncident {
        let text = (
            source + " " +
            message + " " +
            (evidence ?? "")
        ).lowercased()

        let kind: AgentDebugKind

        if text.contains("oauth") ||
           text.contains("auth") ||
           text.contains("login") ||
           text.contains("sign in") {
            kind = .authentication
        } else if text.contains("permission") ||
                  text.contains("not authorized") ||
                  text.contains("accessibility") ||
                  text.contains("izin") {
            kind = .permission
        } else if text.contains("node") ||
                  text.contains("npm") ||
                  text.contains("dependency") ||
                  text.contains("package") ||
                  text.contains("install") ||
                  text.contains("engine") ||
                  text.contains("module") {
            kind = .dependency
        } else if exitCode == 137 ||
                  text.contains("sigkill") ||
                  text.contains("killed") ||
                  text.contains("timeout") ||
                  text.contains("provider") ||
                  text.contains("runtime") {
            kind = .providerRuntime
        } else if text.contains("foreground=false") ||
                  text.contains("doğrulanamad") ||
                  text.contains("verification") ||
                  text.contains("verify") {
            kind = .verificationMismatch
        } else if text.contains("window") ||
                  text.contains("state") ||
                  text.contains("external") {
            kind = .externalState
        } else {
            kind = .unknown
        }

        return AgentDebugIncident(
            source: source,
            kind: kind,
            progress: progress,
            summary: message,
            evidence: evidence,
            recoveryPlan: recoveryPlan(for: kind),
            attempt: 1
        )
    }

    func recovered(
        from incident: AgentDebugIncident,
        summary: String
    ) -> AgentDebugIncident {
        AgentDebugIncident(
            source: incident.source,
            kind: incident.kind,
            progress: .recovered,
            summary: summary,
            evidence: incident.evidence,
            recoveryPlan: incident.recoveryPlan,
            attempt: incident.attempt
        )
    }

    func escalated(
        from incident: AgentDebugIncident,
        summary: String
    ) -> AgentDebugIncident {
        AgentDebugIncident(
            source: incident.source,
            kind: incident.kind,
            progress: .escalated,
            summary: summary,
            evidence: incident.evidence,
            recoveryPlan: incident.recoveryPlan,
            attempt: incident.attempt
        )
    }

    private func recoveryPlan(
        for kind: AgentDebugKind
    ) -> String {
        switch kind {
        case .dependency:
            return "Runtime/dependency sürümünü doğrula → güvenli self-heal uygula → health probe ile tekrar doğrula."
        case .authentication:
            return "Credential durumunu doğrula → gerekli kullanıcı girişini başlat → provider probe'u yeniden çalıştır."
        case .permission:
            return "İzin durumunu doğrula → yalnız gereken izni iste → aynı postcondition'ı tekrar ölç."
        case .providerRuntime:
            return "Provider health probe → tek kontrollü retry → uygun fallback → hâlâ başarısızsa Developer Agent."
        case .verificationMismatch:
            return "Gerçek observation'ı yeniden al → beklenen postcondition ile karşılaştır → alternatif verifier dene → sahte PASS verme."
        case .externalState:
            return "Dış uygulama/durum değişimini yeniden gözle → state'i tazele → görevi idempotent biçimde tekrar planla."
        case .unknown:
            return "Kanıt topla → minimal failure sınıfını belirle → güvenli retry veya Developer Agent'a yükselt."
        }
    }
}

struct AgentDeveloperBridge {
    private let fileManager = FileManager.default

    var statusURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KRALI Agent/Developer/latest.txt",
                isDirectory: false
            )
    }

    var scriptURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent/Scripts/run-developer-agent.command",
                isDirectory: false
            )
    }

    func readStatus() -> DeveloperAgentStatus {
        guard
            let text = try? String(
                contentsOf: statusURL,
                encoding: .utf8
            )
        else {
            return DeveloperAgentStatus(
                state: "idle",
                message: "Developer Agent henüz çalıştırılmadı.",
                branch: nil,
                worktree: nil
            )
        }

        let parts = text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .split(
                separator: "|",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        return DeveloperAgentStatus(
            state: parts.indices.contains(0)
                ? parts[0]
                : "unknown",
            message: parts.indices.contains(1)
                ? parts[1]
                : "Durum bilgisi yok.",
            branch: parts.indices.contains(2) &&
                !parts[2].isEmpty
                ? parts[2]
                : nil,
            worktree: parts.indices.contains(3) &&
                !parts[3].isEmpty
                ? parts[3]
                : nil
        )
    }

    func writeStatus(
        _ status: DeveloperAgentStatus
    ) {
        let directory = statusURL
            .deletingLastPathComponent()

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let value = [
            status.state,
            status.message,
            status.branch ?? "",
            status.worktree ?? ""
        ]
        .joined(separator: "|")

        try? value.write(
            to: statusURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func run() async -> DeveloperAgentStatus {
        guard fileManager.fileExists(
            atPath: scriptURL.path
        ) else {
            return DeveloperAgentStatus(
                state: "setup_required",
                message: "Developer Agent scripti bulunamadı. Önce KRALİ'yi güncelle.",
                branch: nil,
                worktree: nil
            )
        }

        let scriptPath = scriptURL.path

        let result = await Task.detached(
            priority: .utility
        ) {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(
                fileURLWithPath: "/bin/zsh"
            )
            process.arguments = [
                scriptPath
            ]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                _ = pipe.fileHandleForReading
                    .readDataToEndOfFile()

                return Int(
                    process.terminationStatus
                )
            } catch {
                return -1
            }
        }
        .value

        let status = readStatus()

        if result == 0 || status.state != "idle" {
            return status
        }

        return DeveloperAgentStatus(
            state: "failed",
            message: "Developer Agent başlatılamadı.",
            branch: nil,
            worktree: nil
        )
    }
}
