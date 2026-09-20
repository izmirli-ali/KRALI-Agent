import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var prompt = ""
    @State private var memoryDraft = ""
    @StateObject private var updater = UpdateController()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            HSplitView {
                chatPane
                    .frame(minWidth: 640)

                sidePane
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 410)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)
                .shadow(
                    color: Color.red.opacity(0.22),
                    radius: 8
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("KRALİ")
                    .font(.headline)

                Text("Native macOS • v\(updater.currentVersion) • personal agent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(updater.updateAvailable ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)

                Text(updater.statusText)
                    .font(.caption)
                    .foregroundStyle(updater.updateAvailable ? Color.orange : Color.green)

                Button {
                    updater.checkForUpdates()
                } label: {
                    if updater.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(updater.isChecking || updater.isLaunchingUpdate)
                .help("GitHub güncellemelerini kontrol et")

                if updater.updateAvailable {
                    Button("Güncelle") {
                        updater.updateNow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(updater.isLaunchingUpdate)
                }

                Button {
                    engine.syncMentorTrace()
                } label: {
                    if engine.mentorSyncBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(
                            "Mentor",
                            systemImage: "arrow.up.doc"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(
                    !engine.mentorTraceReady ||
                    engine.mentorSyncBusy
                )
                .help(
                    "Son KRALİ görev kaydını private GitHub reposuna gönder. Sonra ChatGPT'ye “mentor kaydına bak” diyebilirsin."
                )
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KRALİ")
                        .font(.headline)

                    Text("Hedefi söyle; KRALİ gerekli kabiliyetleri seçer ve yolu kendisi kurar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(isOn: $engine.voiceOutputEnabled) {
                    Label(
                        "Sesli mod yanıtı",
                        systemImage: engine.voiceOutputEnabled
                            ? "speaker.wave.2.fill"
                            : "speaker.slash.fill"
                    )
                }
                .toggleStyle(.button)
                .help(
                    "Yalnızca mikrofonla gönderdiğin mesajlara sesli yanıt verir. Yazılı mesajlar sessiz kalır."
                )
            }
            .padding(14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(engine.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if engine.busy {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)

                                Text("KRALİ düşünüyor…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(14)
                }
                .onChange(of: engine.messages.count) { _, _ in
                    if let last = engine.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            quickActions
                .padding(.horizontal, 12)
                .padding(.top, 10)

            VoiceStatusView(speech: engine.speech)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            VoiceComposerView(
                speech: engine.speech,
                prompt: $prompt,
                onSend: { text, source in
                    engine.send(text, source: source)
                }
            )
            .padding(12)
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 80)
            }

            Text(message.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.22)
                        : Color(nsColor: .controlBackgroundColor)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )

            if message.role == .assistant {
                Spacer(minLength: 80)
            }
        }
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                quickButton(
                    "Ekran görüntülerini toparla",
                    "Masaüstümdeki ekran görüntülerini bir klasöre toparla."
                )

                quickButton(
                    "PDF'leri bul",
                    "PDF dosyalarını bul."
                )

                quickButton(
                    "Videoları bul",
                    "Video dosyalarını bul."
                )

                quickButton(
                    "Geri al",
                    "geri al"
                )

                quickButton(
                    "Bir şey öğret",
                    "Öğret: konuşmalı Reels videolarında 35 saniyeyi geçme."
                )

                quickButton(
                    "Sorunu çöz",
                    "Premiere eklentisinde hata var. Önce projeyi incele, çözemezsen ChatGPT'ye sor."
                )
            }
        }
    }

    private func quickButton(_ title: String, _ value: String) -> some View {
        Button(title) {
            engine.send(value)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var sidePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("KRALİ'nin planı")

                VStack(alignment: .leading, spacing: 8) {
                    Text(engine.currentGoal)
                        .font(.headline)

                    Text(engine.currentPlan)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !engine.selectedCapabilities.isEmpty {
                        Divider()

                        Text("Kabiliyetler")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(engine.selectedCapabilities) { capability in
                                HStack(spacing: 6) {
                                    Image(
                                        systemName: capability.isAvailable
                                            ? "checkmark.circle.fill"
                                            : "clock.badge.exclamationmark"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(
                                        capability.isAvailable
                                            ? Color.secondary
                                            : Color.orange
                                    )

                                    Text(capability.name)
                                        .font(.caption2)

                                    if !capability.isAvailable {
                                        Text("henüz bağlı değil")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }

                    if !engine.capabilityLearningPlans.isEmpty {
                        Divider()

                        Text("Yetkinlik kazanma")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(engine.capabilityLearningPlans) { plan in
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: plan.state.systemImage)
                                        .font(.caption)
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.capabilityName)
                                            .font(.caption.weight(.medium))

                                        Text(plan.state.title)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)

                                        Text(plan.nextStep)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if plan.requiresApprovalBeforeActivation {
                                            Text("Etkinleştirme öncesi kullanıcı onayı gerekir.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }

                    if !engine.executionSteps.isEmpty {
                        Divider()

                        Text("Dinamik işlem planı")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(engine.executionSteps) { step in
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: step.state.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(
                                        (step.state == .attention ||
                                         step.state == .partial ||
                                         step.state == .blocked)
                                            ? Color.orange
                                            : Color.secondary
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.caption.weight(.medium))

                                    Text(step.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }

                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: engine.verificationState.systemImage)
                                .foregroundStyle(
                                    (engine.verificationState == .attention ||
                                     engine.verificationState == .partial)
                                        ? Color.orange
                                        : Color.secondary
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Verifier")
                                    .font(.caption.weight(.medium))

                                Text(engine.verificationSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if let recovery = engine.recoverySummary {
                                    Text("Otomatik Plan B: \(recovery)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if let fallback = engine.fallbackPlan,
                                   engine.verificationState == .attention {
                                    Text("Plan B: \(fallback)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Spacer()
                        }
                    }

                    if !engine.currentAlternatives.isEmpty {
                        Text("Alternatifler")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(engine.currentAlternatives.prefix(3), id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(item)
                                    .font(.caption2)

                                Spacer()
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if !engine.webResearchResults.isEmpty {
                    sectionTitle("Web araştırma")

                    VStack(alignment: .leading, spacing: 8) {
                        Text(engine.webResearchStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ForEach(engine.webResearchResults.prefix(5)) { result in
                            Link(destination: result.url) {
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: "globe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.caption.weight(.medium))
                                            .multilineTextAlignment(.leading)

                                        Text(result.domain)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !engine.webResearchEvidence.isEmpty {
                    sectionTitle("Kaynak kanıtı")

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.webResearchEvidence.prefix(4)) { evidence in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(evidence.source.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(2)

                                    Spacer()

                                    Text("\(evidence.conceptCoverage) kavram")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(evidence.excerpt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(5)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !engine.capabilityLearningBacklog.isEmpty {
                    sectionTitle("Öğrenme kuyruğu")

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.capabilityLearningBacklog.prefix(5)) { task in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: task.progress.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(
                                        task.progress == .enabled
                                            ? Color.green
                                            : Color.orange
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.capabilityName)
                                        .font(.caption.weight(.medium))

                                    Text(task.progress.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Text(task.nextStep)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)

                                    if task.encounterCount > 1 {
                                        Text("\(task.encounterCount) görevde ihtiyaç duyuldu")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                sectionTitle("Zeka katmanı")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(
                            systemName: engine.localIntelligenceState.isAvailable
                                ? "brain.head.profile.fill"
                                : "brain.head.profile"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            engine.localIntelligenceState.isAvailable
                                ? Color.green
                                : Color.secondary
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.localIntelligenceState.title)
                                .font(.caption.weight(.medium))

                            Text(
                                engine.localIntelligenceState.isAvailable
                                    ? "Öncelik cihaz üzerindeki Apple modelinde."
                                    : "Apple modeli hazır değilse KRALİ, yalnızca analiz/yorum gereken görevlerde ChatGPT Subscription sentezini yedek katman olarak kullanabilir."
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sentez durumu")
                                .font(.caption2.weight(.semibold))

                            Text(engine.intelligenceProviderStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                sectionTitle("Live Research Eval")

                VStack(alignment: .leading, spacing: 8) {
                    Text(engine.liveResearchEvalStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let report = engine.liveResearchEvalReport {
                        ForEach(report.probes) { probe in
                            HStack(alignment: .top, spacing: 7) {
                                Image(
                                    systemName: probe.passed
                                        ? "checkmark.circle.fill"
                                        : "exclamationmark.triangle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    probe.passed
                                        ? Color.green
                                        : Color.orange
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(probe.title)
                                        .font(.caption.weight(.medium))

                                    Text(
                                        "\(probe.sourceCount) kaynak • \(probe.evidenceCount) derin okuma • \(probe.uniqueDomainCount) domain"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                    if let first = probe.diagnostics.first {
                                        Text(first)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }

                    Button {
                        engine.runLiveResearchEval()
                    } label: {
                        if engine.liveResearchEvalBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                "Gerçek araştırma testini çalıştır",
                                systemImage: "globe.badge.chevron.backward"
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(engine.liveResearchEvalBusy)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                sectionTitle("Training Lab")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.trainingLabStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let report = engine.trainingLabReport {
                                Text(
                                    "Core: \(report.corePassed)/\(report.coreTotal) • North Star: \(report.northStarPassed)/\(report.northStarTotal)"
                                )
                                .font(.caption2.weight(.medium))
                            }
                        }

                        Spacer()
                    }

                    if let report = engine.trainingLabReport {
                        let failures = report.results
                            .filter { !$0.passed }
                            .prefix(5)

                        if !failures.isEmpty {
                            Divider()

                            Text("Geliştirme kuyruğuna düşen testler")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(Array(failures)) { result in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)

                                        Text(result.title)
                                            .font(.caption.weight(.medium))

                                        Spacer()

                                        Text(
                                            result.tier == .core
                                                ? "CORE"
                                                : "NORTH STAR"
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }

                                    if let first = result.diagnostics.first {
                                        Text(first)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        engine.runTrainingLab()
                    } label: {
                        if engine.trainingLabBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                "Training Lab'i çalıştır",
                                systemImage: "checklist.checked"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(engine.trainingLabBusy)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                sectionTitle("Developer Agent")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(
                            systemName: engine.developerAgentStatus.isReadyForReview
                                ? "hammer.circle.fill"
                                : "hammer.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            engine.developerAgentStatus.isReadyForReview
                                ? Color.orange
                                : Color.secondary
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.developerAgentStatus.message)
                                .font(.caption.weight(.medium))

                            Text(
                                "İzole branch/worktree • main otomatik değişmez • ChatGPT Subscription OAuth"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            if let branch = engine.developerAgentStatus.branch {
                                Text(branch)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            if engine.developerAgentStatus.isSetupRequired,
                               let hint = engine.developerAgentStatus.setupHint {
                                Text(hint)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .textSelection(.enabled)
                            }
                        }

                        Spacer()
                    }

                    Button {
                        engine.runDeveloperAgent()
                    } label: {
                        if engine.developerAgentBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                "Developer Agent'i çalıştır",
                                systemImage: "hammer"
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(engine.developerAgentBusy)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                sectionTitle("Mentor bridge")

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 7) {
                        Image(
                            systemName: engine.mentorTraceReady
                                ? "doc.text.fill"
                                : "doc.text"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.mentorTraceStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("API kullanmaz • sen gönderene kadar yerelde kalır")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Button {
                        engine.syncMentorTrace()
                    } label: {
                        Label(
                            "Son kaydı Mentora gönder",
                            systemImage: "arrow.up.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(
                        !engine.mentorTraceReady ||
                        engine.mentorSyncBusy
                    )
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                sectionTitle("Aktif rota")
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 72),
                            spacing: 6,
                            alignment: .leading
                        )
                    ],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(engine.activeRoute, id: \.self) { item in
                        Text(item)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .background(
                                Color.accentColor.opacity(0.12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        Color.accentColor.opacity(0.28),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }

                if let action = engine.pendingFileAction {
                    sectionTitle("Onay bekleyen gerçek işlem")

                    VStack(alignment: .leading, spacing: 9) {
                        Label(action.title, systemImage: "folder.badge.gearshape")
                            .font(.headline)

                        Text(action.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Hedef: \(action.destinationFolderURL.path)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        HStack {
                            Button("Onayla ve Taşı") {
                                let reply = engine.approvePendingFileAction()
                                engine.messages.append(
                                    ChatMessage(role: .assistant, text: reply)
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            Button("İptal", role: .cancel) {
                                engine.cancelPendingFileAction()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(11)
                    .background(Color.orange.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if engine.lastUndoAction != nil {
                    Button {
                        let reply = engine.undoLastFileAction()
                        engine.messages.append(
                            ChatMessage(role: .assistant, text: reply)
                        )
                    } label: {
                        Label("Son dosya taşıma işlemini geri al", systemImage: "arrow.uturn.backward")
                    }
                }

                if !engine.folderSearchResults.isEmpty {
                    sectionTitle(engine.fileSearchTitle)

                    VStack(spacing: 7) {
                        ForEach(engine.folderSearchResults.prefix(12)) { folder in
                            Button {
                                engine.revealFolder(folder)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Text(folder.relativePath)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.forward.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if engine.folderSearchResults.count > 12 {
                        Text("+ \(engine.folderSearchResults.count - 12) klasör daha")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !engine.fileSearchResults.isEmpty {
                    sectionTitle(engine.fileSearchTitle)

                    VStack(spacing: 7) {
                        ForEach(engine.fileSearchResults.prefix(12)) { file in
                            Button {
                                engine.revealFile(file)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: file.isScreenshot ? "photo" : "doc")
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Text(file.relativePath)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.forward.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if engine.fileSearchResults.count > 12 {
                        Text("+ \(engine.fileSearchResults.count - 12) sonuç daha")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                sectionTitle("Şu anda ne yapıyor?")

                VStack(spacing: 7) {
                    ForEach(engine.activities.prefix(12)) { item in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)

                            Text(item.text)
                                .font(.caption)

                            Spacer()
                        }
                        .padding(8)
                        .background(
                            Color(nsColor: .controlBackgroundColor)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 8)
                        )
                    }
                }

                sectionTitle("Öğrendikleri")

                VStack(spacing: 7) {
                    ForEach(engine.memories.reversed(), id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(8)
                            .background(
                                Color(nsColor: .controlBackgroundColor)
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }

                HStack {
                    TextField(
                        "Yeni kural…",
                        text: $memoryDraft
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("Ekle") {
                        engine.addMemory(memoryDraft)
                        memoryDraft = ""
                    }
                    .disabled(
                        memoryDraft
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }

                sectionTitle("Yerel File Agent")

                HStack {
                    Button {
                        engine.chooseFolder()
                    } label: {
                        Label(
                            "Çalışma klasörü seç",
                            systemImage: "folder.badge.plus"
                        )
                    }

                    Button {
                        engine.indexSelectedFolder()
                    } label: {
                        Label(
                            "Yenile",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(engine.selectedRootURL == nil)
                }

                if let root = engine.selectedRootURL {
                    Text("Seçili klasör: \(root.path)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    FlowLayout(
                        items: [
                            "Dosya \(engine.indexedFiles.count)",
                            "Klasör \(engine.indexedFolders.count)",
                            "Görsel \(engine.imageCount)",
                            "Video \(engine.videoCount)",
                            "Proje \(engine.projectCount)",
                            "Belge \(engine.documentCount)",
                            "Ekran Görüntüsü \(engine.screenshotCount)"
                        ]
                    )
                } else {
                    Text("Henüz çalışma klasörü seçilmedi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(
                    engine.indexedFiles.prefix(10)
                ) { file in
                    HStack(spacing: 7) {
                        Image(systemName: file.isScreenshot ? "photo" : "doc")
                            .foregroundStyle(
                                file.isScreenshot ? Color.accentColor : Color.secondary
                            )

                        Text(file.name)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Text(
                    "v0.7.25: ChatGPT Subscription sentez köprüsü sağlamlaştırıldı. Cline çıktısı pipe yerine dosyaya akıtılarak kilitlenme riski azaltıldı; güvenli scratch çalışma alanında otomatik onay kullanılıyor ve shell komutları kapalı kalıyor. Başarısızlık nedeni artık Mentor/activity loguna açıkça yazılıyor. “Bağımsız fikir üret” adımındaki Türkçe ı/i eşleşme hatası da düzeltildi."
                )
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(9)
                .background(
                    Color.orange.opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 8)
                )
            }
            .padding(14)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.0)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Voice UI

private struct VoiceStatusView: View {
    @ObservedObject var speech: SpeechController

    var body: some View {
        Group {
            switch speech.state {
            case .recording:
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text(
                        "Dinliyorum • \(formattedTime(speech.elapsedSeconds)) • tekrar mikrofon/stop tuşuna basınca kayıt bitecek."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("İptal") {
                        speech.cancelRecording()
                    }
                    .buttonStyle(.borderless)
                }

            case .transcribing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Ses yazıya çevriliyor…")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

            case .requestingPermission:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("İzinler kontrol ediliyor…")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

            case .denied:
                HStack {
                    Text(
                        "Mikrofon veya Konuşma Tanıma izni kapalı."
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)

                    Spacer()

                    Button("Ayarları Aç") {
                        speech.openPrivacySettings()
                    }
                    .buttonStyle(.borderless)
                }

            case .failed(let message):
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)

                    Spacer()

                    Button("Kapat") {
                        speech.dismissError()
                    }
                    .buttonStyle(.borderless)
                }

            case .idle:
                if !speech.statusText.isEmpty
                    && speech.statusText != "Hazır" {
                    HStack {
                        Text(speech.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(
            format: "%02d:%02d",
            seconds / 60,
            seconds % 60
        )
    }
}

private struct VoiceComposerView: View {
    @ObservedObject var speech: SpeechController
    @Binding var prompt: String
    let onSend: (String, ChatInputSource) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                speech.microphoneTapped { text in
                    prompt = ""
                    onSend(text, .voice)
                }
            } label: {
                Image(systemName: micIcon)
                    .foregroundStyle(
                        speech.isRecording
                            ? Color.red
                            : Color.primary
                    )
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.bordered)
            .disabled(speech.isBusy)
            .help(micHelp)

            TextField(
                "KRALİ'ye normal konuşur gibi görev ver…",
                text: $prompt,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...5)
            .onSubmit {
                sendPrompt()
            }

            Button("Gönder") {
                sendPrompt()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                prompt
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )
        }
    }

    private var micIcon: String {
        switch speech.state {
        case .recording:
            return "stop.circle.fill"
        case .transcribing, .requestingPermission:
            return "hourglass"
        default:
            return "mic.fill"
        }
    }

    private var micHelp: String {
        switch speech.state {
        case .recording:
            return "Kaydı durdur ve yazıya çevir"
        case .transcribing:
            return "Ses yazıya çevriliyor"
        case .requestingPermission:
            return "İzinler kontrol ediliyor"
        default:
            return "Ses kaydını başlat"
        }
    }

    private func sendPrompt() {
        let text = prompt
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !text.isEmpty else { return }

        prompt = ""
        onSend(text, .text)
    }
}

private struct FlowLayout: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.accentColor.opacity(0.12)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                Color.accentColor.opacity(0.30),
                                lineWidth: 1
                            )
                    )
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}
