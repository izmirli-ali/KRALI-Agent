import Foundation

struct DeveloperAgentStatus: Hashable {
    let state: String
    let message: String
    let branch: String?
    let worktree: String?
    let appVersion: String?
    let updatedAt: Date?
    let runID: String?

    init(
        state: String,
        message: String,
        branch: String?,
        worktree: String?,
        appVersion: String? = nil,
        updatedAt: Date? = nil,
        runID: String? = nil
    ) {
        self.state = state
        self.message = message
        self.branch = branch
        self.worktree = worktree
        self.appVersion = appVersion
        self.updatedAt = updatedAt
        self.runID = runID
    }

    func freshForApp(
        _ currentAppVersion: String,
        maxHeartbeatAge: TimeInterval = 300
    ) -> DeveloperAgentStatus {
        guard shouldShowLearningStatus else {
            return self
        }

        guard appVersion == currentAppVersion,
              let updatedAt,
              Date().timeIntervalSince(updatedAt) <=
                maxHeartbeatAge else {
            return DeveloperAgentStatus(
                state: "stale_run",
                message:
                    "Önceki Developer Agent oturumu aktif değil veya bu sürüme ait değil.",
                branch: branch,
                worktree: worktree,
                appVersion: currentAppVersion,
                updatedAt: Date(),
                runID: runID
            )
        }

        return self
    }

    var isReadyForReview: Bool {
        state == "ready_for_review" ||
        state == "build_failed" ||
        state == "task_verification_failed" ||
        state == "recovered_candidate_ready" ||
        state == "recovered_candidate_build_failed" ||
        state == "recovered_candidate_verification_failed",
            "recovered_candidate_surface_regression"
    }

    var isLearningActive: Bool {
        [
            "checking",
            "learning",
            "running",
            "retrying",
            "verifying",
            "repairing_cline",
            "repairing_runtime",
            "local_ai_checking",
            "local_ai_installing",
            "local_ai_starting",
            "local_model_downloading",
            "local_tool_probe",
            "local_model_fallback",
            "local_model_specialized",
            "local_ai_ready",
            "remote_ai_ready",
            "remote_agent_starting",
            "local_agent_starting",
            "local_agent_resumed",
            "local_agent_verified_resume_controller",
            "local_agent_running",
            "local_agent_tool",
            "task_verifying",
            "local_agent_structured_tool",
            "local_agent_structured_mutation",
            "local_agent_structured_failure",
            "local_agent_mutation_rolled_back",
            "local_agent_checkpoint_stale",
            "local_agent_controller_preparing",
            "local_agent_timeout_controller",
            "local_agent_controller_rejected",
            "local_agent_target_found",
            "local_agent_target_not_found",
            "local_agent_create_target_ready",
            "local_agent_target_verified",
            "local_agent_iteration_grace",
            "local_agent_dependency_neighborhood_verified",
            "local_agent_root_cause_pool_ready",
            "local_agent_root_cause_pruned",
            "local_agent_root_cause_ranking",
            "local_agent_root_cause_ranked",
            "local_agent_root_cause_analyzing",
            "local_agent_root_cause_verifying",
            "local_agent_root_cause_verified",
            "local_agent_root_cause_rejected",
            "local_agent_root_cause_selected",
            "local_agent_mutation_model_fallback",
            "local_agent_repair_anchor_preserved",
            "local_agent_failed_mutation_recorded",
            "local_agent_failed_diff_recorded",
            "local_agent_repeated_failed_mutation_rejected",
            "local_agent_repeated_failed_diff_rejected",
            "local_agent_strategy_escalated",
            "skill_extracting",
            "skill_candidate_ready",
            "local_agent_candidate_handoff",
            "local_agent_completed",
            "cursor_architect_running",
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
            "provider_platform_bug",
            "recovering_candidate",
            "candidate_recovered",
            "candidate_repair_running"
        ].contains(state)
    }

    var shouldShowLearningStatus: Bool {
        isLearningActive ||
        [
            "ready_for_review",
            "build_failed",
            "setup_local_ai",
            "local_ai_failed",
            "local_model_failed",
            "local_model_specialized",
            "local_ai_upgrade_required",
            "local_tool_probe_failed",
            "local_agent_root_cause_inconclusive",
            "local_agent_strategy_escalation_inconclusive",
            "local_agent_resumed",
            "local_storage_low",
            "local_agent_failed",
            "local_agent_tool_protocol_failed",
            "local_agent_iteration_limit",
            "local_agent_completion_gate_failed",
            "local_agent_watchdog_timeout",
            "cursor_architect_ready",
            "sdk_tool_protocol_failed",
            "no_change_unverified",
            "sdk_provider_failed",
            "sdk_failed",
            "sdk_watchdog_timeout",
            "stale_run",
            "recovered_candidate_ready",
            "recovered_candidate_build_failed",
            "candidate_recovery_failed",
            "candidate_repair_failed",
            "system_action_approval_required",
            "system_action_rejected",
            "failed"
        ].contains(state)
    }

    var learningStageTitle: String {
        switch state {
        case "system_action_approval_required":
            return "Sistem işlemi için onay bekliyor"
        case "system_action_rejected":
            return "Sistem işlemi kullanıcı tarafından reddedildi"
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
        case "local_ai_checking":
            return "Yerel AI kontrol ediliyor"
        case "local_ai_installing":
            return "Yerel AI kuruluyor"
        case "local_ai_starting":
            return "Yerel AI başlatılıyor"
        case "local_model_downloading":
            return "Yerel model indiriliyor"
        case "local_tool_probe":
            return "Yerel model araç kullanımı doğrulanıyor"
        case "local_model_fallback":
            return "Alternatif yerel model deneniyor"
        case "local_model_specialized":
            return "Göreve uygun yerel model seçildi"
        case "local_ai_ready":
            return "Ücretsiz yerel AI hazır"
        case "remote_ai_ready":
            return "Remote Developer AI hazır"
        case "remote_agent_starting":
            return "Remote Developer Agent başlatılıyor"
        case "local_agent_starting":
            return "Native yerel agent başlatılıyor"
        case "local_agent_resumed":
            return "Checkpoint'ten devam ediyor"
        case "local_agent_verified_resume_controller":
            return "Doğrulanmış checkpoint'ten controller devam ediyor"
        case "local_agent_running":
            return "Native yerel agent çalışıyor"
        case "local_agent_tool":
            return "Yerel agent araç kullanıyor"
        case "local_agent_structured_tool":
            return "Controller araç devamı uyguluyor"
        case "local_agent_structured_mutation":
            return "Controller kaynak kod değişikliği uyguluyor"
        case "local_agent_structured_failure":
            return "Controller mutation hatasını analiz ediyor"
        case "local_agent_mutation_rolled_back":
            return "Başarısız mutation geri alındı"
        case "local_agent_checkpoint_stale":
            return "Eski kaynak checkpoint'i yenileniyor"
        case "local_agent_controller_preparing":
            return "Controller için model ve kanıt hazırlanıyor"
        case "local_agent_timeout_controller":
            return "Zaman aşımı sonrası controller devralıyor"
        case "local_agent_controller_rejected":
            return "Controller kararı güvenlik kontrolünde reddedildi"
        case "local_agent_target_found":
            return "İzinli değişiklik hedefi bulundu"
        case "local_agent_target_not_found":
            return "İzinli değişiklik hedefi aranıyor"
        case "local_agent_create_target_ready":
            return "Yeni dosya oluşturma scope'u hazır"
        case "local_agent_target_verified":
            return "Değişiklik hedefi doğrulandı"
        case "local_agent_iteration_grace":
            return "Gereksiz inspection ana bütçeden düşülmedi"
        case "local_agent_dependency_neighborhood_verified":
            return "Bağımlılık çevresi doğrulanıyor"
        case "local_agent_root_cause_analyzing":
            return "Kök neden analiz ediliyor"
        case "local_agent_root_cause_selected":
            return "Gerçek düzeltme hedefi seçildi"
        case "local_agent_root_cause_inconclusive":
            return "Kök neden analizi sonuçsuz"
        case "local_agent_repair_anchor_preserved":
            return "Repair kaynağı korunuyor"
        case "local_agent_failed_mutation_recorded",
             "local_agent_failed_diff_recorded":
            return "Başarısız strateji kaydediliyor"
        case "local_agent_repeated_failed_mutation_rejected",
             "local_agent_repeated_failed_diff_rejected":
            return "Tekrarlanan başarısız strateji engellendi"
        case "local_agent_strategy_escalated":
            return "Architect yeni stratejiye geçti"
        case "local_agent_strategy_escalation_inconclusive":
            return "Alternatif strateji bulunamadı"
        case "skill_extracting":
            return "Genellenebilir skill çıkarılıyor"
        case "skill_candidate_ready":
            return "Experimental skill adayı hazır"
        case "local_ai_upgrade_required":
            return "Ollama güncellemesi gerekli"
        case "local_agent_candidate_handoff":
            return "Aday build ve recovery hattına devrediliyor"
        case "local_agent_completed":
            return "Yerel agent turu tamamlandı"
        case "setup_local_ai":
            return "Yerel AI kurulumu gerekli"
        case "local_ai_failed":
            return "Yerel AI başlatılamadı"
        case "local_model_failed":
            return "Yerel model indirilemedi"
        case "local_tool_probe_failed":
            return "Yerel model tool-call testi başarısız"
        case "local_storage_low":
            return "Yerel model için disk alanı yetersiz"
        case "local_agent_failed":
            return "Native yerel agent durdu"
        case "local_agent_tool_protocol_failed":
            return "Native tool-call protokolü başarısız"
        case "local_agent_iteration_limit":
            return "Native yerel agent adım sınırına ulaştı"
        case "local_agent_completion_gate_failed":
            return "Native yerel agent gerçek candidate üretmedi"
        case "local_agent_watchdog_timeout":
            return "Native yerel agent zaman aşımına uğradı"
        case "cursor_architect_running":
            return "Cursor ikinci görüşü alınıyor"
        case "cursor_architect_ready":
            return "Cursor Architect teşhisi hazır"
        case "sdk_tool_protocol_failed":
            return "Yerel model araç protokolü başarısız"
        case "no_change_unverified":
            return "Öğrenme kanıt üretmedi"
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
        case "recovering_candidate":
            return "Önceki öğrenme adayı kurtarılıyor"
        case "candidate_recovered":
            return "Aday GitHub'a yedeklendi"
        case "candidate_repair_running":
            return "Aday compiler hatasıyla onarılıyor"
        case "candidate_repair_failed":
            return "Aday onarımı durdu"
        case "recovered_candidate_ready":
            return "Kurtarılan öğrenme adayı hazır"
        case "recovered_candidate_build_failed":
            return "Kurtarılan aday build geçmedi"
        case "candidate_recovery_failed":
            return "Aday kurtarma başarısız"
        case "stale_run":
            return "Önceki öğrenme oturumu"
        case "failed":
            return "Öğrenme durdu"
        default:
            return "Öğrenme"
        }
    }

    var learningTimingText: String? {
        guard isLearningActive else {
            return nil
        }

        let elapsedText: String
        if let elapsedMinutes {
            elapsedText =
                "Geçen: " +
                String(elapsedMinutes) +
                " dk"
        } else {
            elapsedText = "Geçen süre hesaplanıyor"
        }

        guard let estimate =
            estimatedRemainingRange
        else {
            return elapsedText
        }

        return elapsedText +
            " • Tahmini kalan: " +
            estimate
    }

    private var elapsedMinutes: Int? {
        guard let runStartedAt else {
            return nil
        }

        let seconds = max(
            0,
            Date().timeIntervalSince(
                runStartedAt
            )
        )

        return Int(seconds / 60)
    }

    private var runStartedAt: Date? {
        guard
            let runID,
            !runID.isEmpty
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale =
            Locale(identifier: "en_US_POSIX")
        formatter.calendar =
            Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat =
            "yyyyMMdd-HHmmss"

        return formatter.date(
            from: runID
        )
    }

    private var estimatedRemainingRange: String? {
        switch state {
        case "repairing_cline",
             "repairing_runtime",
             "local_ai_checking",
             "local_ai_installing",
             "local_ai_starting",
             "local_model_downloading",
             "local_tool_probe",
             "local_model_fallback",
             "local_ai_ready",
             "remote_ai_ready",
             "remote_agent_starting",
             "sdk_fallback_preparing",
             "sdk_importing",
             "sdk_import_ready",
             "sdk_provider_ready",
             "sdk_runtime_starting",
             "sdk_runtime_ready":
            return "4–8 dk"

        case "sdk_session_starting",
             "sdk_session_running",
             "remote_agent_starting",
             "local_agent_starting",
             "local_agent_running",
             "learning",
             "running":
            return "3–7 dk"

        case "sdk_tools_running",
             "sdk_tool_completed",
             "local_agent_tool":
            return "2–6 dk"

        case "sdk_session_ended",
             "sdk_session_completed",
             "local_agent_completed",
             "cursor_architect_running",
             "verifying":
            return "1–3 dk"

        case "retrying":
            return "3–7 dk"

        default:
            return nil
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
            "waiting_cline_auth",
            "setup_local_ai",
            "local_ai_upgrade_required",
            "local_storage_low"
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
        case "setup_local_ai":
            return "Yerel Ollama runtime otomatik hazırlanamadı."
        case "local_storage_low":
            return "Diskte yeterli boş alan yok. KRALİ yeni büyük model indirmeyi durdurdu; mevcut kurulu model korunuyor."
        case "local_ai_upgrade_required":
            return "Devstral Small 2 için Ollama 0.13.3 veya daha yeni sürüm gerekir; KRALİ Homebrew kurulumunda otomatik güncellemeyi dener."
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

enum AgentDeveloperToolOperation:
    String,
    Hashable {
    case trainingLab
    case arena
    case liveResearchEval
    case screenPerceptionProbe
    case desktopControlProbe
    case developerSystemEffects
}

struct AgentDeveloperToolSafetyPolicy {
    func requiresApproval(
        _ operation: AgentDeveloperToolOperation
    ) -> Bool {
        switch operation {
        case .desktopControlProbe,
             .developerSystemEffects:
            return true

        case .trainingLab,
             .arena,
             .liveResearchEval,
             .screenPerceptionProbe:
            return false
        }
    }
}

struct AgentDeveloperTaskDescriptor: Hashable {
    let id: String
    let title: String
    let url: URL
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

    var recoveryScriptURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent/Scripts/recover-developer-candidate.command",
                isDirectory: false
            )
    }

    var developerTasksDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent/DeveloperAgent/Tasks",
                isDirectory: true
            )
    }

    func resolveDeveloperTask(
        _ rawQuery: String
    ) -> AgentDeveloperTaskDescriptor? {
        let query = normalizedDeveloperTaskKey(
            rawQuery
        )

        guard !query.isEmpty,
              let urls = try? fileManager
                .contentsOfDirectory(
                    at:
                        developerTasksDirectoryURL,
                    includingPropertiesForKeys: nil,
                    options: [
                        .skipsHiddenFiles
                    ]
                )
        else {
            return nil
        }

        for url in urls
            .filter({
                $0.pathExtension.lowercased() ==
                    "json"
            })
            .sorted(
                by: {
                    $0.lastPathComponent <
                    $1.lastPathComponent
                }
            ) {
            guard
                let data = try? Data(
                    contentsOf: url
                ),
                let object = try? JSONSerialization
                    .jsonObject(
                        with: data
                    ) as? [String: Any],
                let task =
                    object["developerTask"]
                        as? [String: Any]
            else {
                continue
            }

            let capabilityID =
                String(
                    describing:
                        task["capabilityID"] ??
                        ""
                )
            let title =
                String(
                    describing:
                        task["capabilityName"] ??
                        url.deletingPathExtension()
                            .lastPathComponent
                )
            let fileID =
                url.deletingPathExtension()
                    .lastPathComponent

            let aliases = [
                fileID,
                capabilityID,
                capabilityID
                    .split(separator: ".")
                    .last
                    .map(String.init) ??
                    "",
                title
            ]
            .map(normalizedDeveloperTaskKey)

            if aliases.contains(query) {
                return AgentDeveloperTaskDescriptor(
                    id: fileID,
                    title: title,
                    url: url
                )
            }
        }

        return nil
    }

    private func normalizedDeveloperTaskKey(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "tr_TR"
                    )
            )
            .lowercased()
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )
            .filter {
                !$0.isEmpty
            }
            .joined(separator: "-")
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

        let rawParts = text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .split(
                separator: "|",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        let metaIndex =
            rawParts.firstIndex(
                of: "@meta"
            )

        let parts =
            metaIndex.map {
                Array(
                    rawParts.prefix($0)
                )
            } ?? rawParts

        var appVersion: String?
        var updatedAt: Date?
        var runID: String?

        if let metaIndex {
            for item in rawParts.dropFirst(
                metaIndex + 1
            ) {
                if item.hasPrefix("app=") {
                    appVersion =
                        String(
                            item.dropFirst(4)
                        )
                } else if item.hasPrefix("at="),
                          let seconds =
                            TimeInterval(
                                item.dropFirst(3)
                            ) {
                    updatedAt =
                        Date(
                            timeIntervalSince1970:
                                seconds
                        )
                } else if item.hasPrefix("run=") {
                    runID =
                        String(
                            item.dropFirst(4)
                        )
                }
            }
        }

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
                : nil,
            appVersion: appVersion,
            updatedAt: updatedAt,
            runID: runID
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

        let currentVersion =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "unknown"

        let value = [
            status.state,
            status.message,
            status.branch ?? "",
            status.worktree ?? "",
            "@meta",
            "app=" +
                (status.appVersion ??
                    currentVersion),
            "at=" +
                String(
                    Int(
                        (status.updatedAt ??
                            Date())
                            .timeIntervalSince1970
                    )
                ),
            "run=" +
                (status.runID ?? "")
        ]
        .joined(separator: "|")

        try? value.write(
            to: statusURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func recoverPendingCandidate() async -> DeveloperAgentStatus? {
        let current = readStatus()

        guard
            current.worktree != nil,
            current.branch != nil,
            fileManager.fileExists(
                atPath: recoveryScriptURL.path
            )
        else {
            return nil
        }

        let scriptPath =
            recoveryScriptURL.path

        _ = await Task.detached(
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
            } catch {
                return
            }
        }
        .value

        let recovered = readStatus()

        if recovered.state != current.state ||
           recovered.message != current.message {
            return recovered
        }

        return nil
    }

    func run(
        learningJobBriefURL: URL? = nil,
        developerTaskURL: URL? = nil,
        approvedSystemEffect: String? = nil
    ) async -> DeveloperAgentStatus {
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

            var environment =
                ProcessInfo.processInfo
                    .environment

            environment[
                "KRALI_APPROVED_SYSTEM_EFFECT"
            ] =
                approvedSystemEffect ?? ""

            if let learningJobBriefURL {
                environment[
                    "KRALI_LEARNING_JOB_FILE"
                ] =
                    learningJobBriefURL.path
            }

            if let developerTaskURL {
                environment[
                    "KRALI_DEV_TASK_FILE"
                ] =
                    developerTaskURL.path
            }

            process.environment =
                environment

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
