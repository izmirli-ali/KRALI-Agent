import SwiftUI
import AppKit
import Foundation

struct ContentView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var prompt = ""
    @State private var developerToolsExpanded = false
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
                isLocked: engine.busy,
                onSend: { text, source in
                    engine.send(text, source: source)
                }
            )
            .padding(12)
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 90)
            }

            Group {
                if message.role == .assistant {
                    AssistantMessageText(text: message.text)
                } else {
                    Text(message.text)
                        .font(.system(size: 14.5, weight: .medium))
                        .lineSpacing(2)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            .textSelection(.enabled)
            .frame(
                maxWidth: message.role == .assistant ? 780 : 640,
                alignment: .leading
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                message.role == .user
                    ? Color.accentColor.opacity(0.18)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .stroke(
                    message.role == .assistant
                        ? Color.primary.opacity(0.06)
                        : Color.accentColor.opacity(0.10),
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
            )

            if message.role == .assistant {
                Spacer(minLength: 90)
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
        .disabled(engine.busy)
    }

    private var sidePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Durum")

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(
                            systemName: engine.busy
                                ? "sparkles"
                                : engine.verificationState.systemImage
                        )
                        .foregroundStyle(
                            engine.verificationState == .attention ||
                            engine.verificationState == .partial
                                ? Color.orange
                                : Color.secondary
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(engine.currentGoal)
                                .font(.headline)

                            Text(
                                engine.busy
                                    ? "KRALİ çalışıyor…"
                                    : engine.verificationSummary
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        }

                        Spacer()
                    }

                    if engine.currentPlan != "Yeni görevi bekliyor" {
                        Divider()

                        Text(engine.currentPlan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if !engine.selectedCapabilities.isEmpty {
                        Divider()

                        HStack(spacing: 6) {
                            ForEach(
                                engine.selectedCapabilities.prefix(4)
                            ) { capability in
                                Text(capability.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(
                                        capability.isAvailable
                                            ? Color.accentColor.opacity(0.10)
                                            : Color.orange.opacity(0.10)
                                    )
                                    .clipShape(Capsule())
                            }

                            Spacer()
                        }
                    }

                    if let root = engine.selectedRootURL {
                        Divider()

                        Label(
                            "\(root.lastPathComponent) • \(engine.indexedFiles.count) dosya",
                            systemImage: "folder"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if engine.intelligenceProviderStatus !=
                        "Sentez sağlayıcısı henüz kullanılmadı." {
                        Text(engine.intelligenceProviderStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(11)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 11))

                sectionTitle("Bağlam")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(
                            engine.contextMemoryStatus,
                            systemImage: "brain"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(engine.contextMemoryEntries.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    let visibleContext =
                        engine.activeContextMemories.isEmpty
                            ? Array(engine.contextMemoryEntries.prefix(3))
                            : Array(engine.activeContextMemories.prefix(3))

                    if visibleContext.isEmpty {
                        Text(
                            "KRALİ tamamlanan görevlerden henüz yeniden kullanılabilir bir bağlam oluşturmadı."
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleContext) { memory in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Image(
                                        systemName: memory.kind == .userRule
                                            ? "bookmark.fill"
                                            : memory.kind == .research
                                                ? "globe"
                                                : "clock.arrow.circlepath"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                    Text(memory.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)

                                    Spacer()
                                }

                                Text(memoryPreview(memory.summary))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(1.5)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(11)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 11))

                if !engine.webResearchResults.isEmpty {
                    sectionTitle("Kaynaklar")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(
                                "\(engine.webResearchResults.count) kaynak • \(engine.webResearchEvidence.count) doğrulanmış kanıt"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Spacer()
                        }

                        ForEach(
                            engine.webResearchResults.prefix(4)
                        ) { result in
                            Link(destination: result.url) {
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(result.title)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(2)
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
                    .padding(11)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if let incident = engine.debugIncident {
                    sectionTitle("Hata Ayıklama")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            if incident.progress.isActive {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: incident.kind.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(
                                        incident.progress == .recovered
                                            ? Color.green
                                            : Color.orange
                                    )
                                    .frame(width: 16)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(incident.progress.title)
                                    .font(.caption.weight(.semibold))

                                Text(
                                    incident.kind.title +
                                    " • " +
                                    incident.source
                                )
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)

                                Text(incident.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer()
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery planı")
                                .font(.caption2.weight(.semibold))

                            Text(incident.recoveryPlan)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        if let evidence = incident.evidence,
                           !evidence.isEmpty {
                            Text("Kanıt: " + evidence)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(11)
                    .background(
                        incident.progress == .recovered
                            ? Color.green.opacity(0.07)
                            : Color.orange.opacity(0.07)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(
                                incident.progress == .recovered
                                    ? Color.green.opacity(0.25)
                                    : Color.orange.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if !engine.capabilityLearningPlans.isEmpty ||
                   !engine.capabilityLearningBacklog.isEmpty ||
                   engine.developerAgentStatus.shouldShowLearningStatus {
                    sectionTitle("Öğrenme")

                    VStack(alignment: .leading, spacing: 8) {
                        if engine.developerAgentStatus.shouldShowLearningStatus {
                            HStack(alignment: .top, spacing: 8) {
                                if engine.developerAgentStatus.isLearningActive {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(
                                        systemName:
                                            engine.developerAgentStatus.state ==
                                                "ready_for_review"
                                                ? "checkmark.circle.fill"
                                                : "exclamationmark.triangle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        engine.developerAgentStatus.state ==
                                            "ready_for_review"
                                            ? Color.green
                                            : Color.orange
                                    )
                                    .frame(width: 16)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        engine.developerAgentStatus
                                            .learningStageTitle
                                    )
                                    .font(.caption.weight(.semibold))

                                    Text(engine.developerAgentStatus.message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)

                                    if let timing =
                                        engine.developerAgentStatus
                                            .learningTimingText {
                                        Text(timing)
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()
                            }

                            if !engine.capabilityLearningPlans.isEmpty ||
                               !engine.capabilityLearningBacklog.isEmpty {
                                Divider()
                            }
                        }

                        ForEach(
                            engine.capabilityLearningPlans.prefix(3)
                        ) { plan in
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: plan.state.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.capabilityName)
                                        .font(.caption.weight(.medium))

                                    Text(plan.nextStep)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                        }

                        if engine.capabilityLearningPlans.isEmpty {
                            ForEach(
                                engine.capabilityLearningBacklog
                                    .filter { $0.progress != .enabled }
                                    .prefix(3)
                            ) { task in
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: task.progress.systemImage)
                                        .font(.caption)
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.capabilityName)
                                            .font(.caption.weight(.medium))

                                        Text(task.nextStep)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(11)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if let action = engine.pendingFileAction {
                    sectionTitle("Onay bekliyor")

                    VStack(alignment: .leading, spacing: 9) {
                        Label(
                            action.title,
                            systemImage: "folder.badge.gearshape"
                        )
                        .font(.headline)

                        Text(action.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Onayla") {
                                let reply =
                                    engine.approvePendingFileAction()
                                engine.messages.append(
                                    ChatMessage(
                                        role: .assistant,
                                        text: reply
                                    )
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
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(
                                Color.orange.opacity(0.35),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if engine.activeRoute.contains("Files") &&
                   (
                       !engine.fileSearchResults.isEmpty ||
                       !engine.folderSearchResults.isEmpty
                   ) {
                    sectionTitle("Sonuçlar")

                    VStack(spacing: 6) {
                        ForEach(
                            engine.folderSearchResults.prefix(5)
                        ) { folder in
                            Button {
                                engine.revealFolder(folder)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")

                                    Text(folder.name)
                                        .font(.caption)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(
                                        systemName: "arrow.forward.circle"
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(
                            engine.fileSearchResults.prefix(5)
                        ) { file in
                            Button {
                                engine.revealFile(file)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(
                                        systemName: file.isScreenshot
                                            ? "photo"
                                            : "doc"
                                    )

                                    Text(file.name)
                                        .font(.caption)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(
                                        systemName: "arrow.forward.circle"
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(11)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if engine.lastUndoAction != nil {
                    Button {
                        let reply = engine.undoLastFileAction()
                        engine.messages.append(
                            ChatMessage(
                                role: .assistant,
                                text: reply
                            )
                        )
                    } label: {
                        Label(
                            "Son dosya işlemini geri al",
                            systemImage: "arrow.uturn.backward"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                DisclosureGroup(
                    "Geliştirici araçları",
                    isExpanded: $developerToolsExpanded
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training Lab")
                                    .font(.caption.weight(.medium))
                                Text(engine.trainingLabStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runTrainingLab()
                            }
                            .controlSize(.small)
                            .disabled(engine.trainingLabBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Research Eval")
                                    .font(.caption.weight(.medium))
                                Text(engine.liveResearchEvalStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runLiveResearchEval()
                            }
                            .controlSize(.small)
                            .disabled(engine.liveResearchEvalBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("KRALİ Arena")
                                    .font(.caption.weight(.medium))
                                Text(engine.arenaStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runArena()
                            }
                            .controlSize(.small)
                            .disabled(engine.arenaBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Screen Perception Probe")
                                    .font(.caption.weight(.medium))
                                Text(engine.screenPerceptionStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer()

                            Button("Test") {
                                engine.runScreenPerceptionProbe()
                            }
                            .controlSize(.small)
                            .disabled(engine.screenPerceptionBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Desktop Control Probe")
                                    .font(.caption.weight(.medium))
                                Text(engine.desktopControlStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer()

                            Button("Test") {
                                engine.runDesktopControlProbe()
                            }
                            .controlSize(.small)
                            .disabled(engine.desktopControlBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Developer Agent")
                                    .font(.caption.weight(.medium))
                                Text(engine.developerAgentStatus.message)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runDeveloperAgent()
                            }
                            .controlSize(.small)
                            .disabled(engine.developerAgentBusy)
                        }

                        Text(
                            "Bu butonlar yalnız geliştirici testi / tanısı içindir. Günlük KRALİ kullanımı doğal dil komutlarıyla yapılır; capability'ler için ayrı kullanıcı butonları gerekmez."
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Text(
                            "Mentor gönderimi üst çubuktaki Mentor düğmesinden yapılır."
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .font(.caption.weight(.medium))
                .padding(11)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .padding(14)
        }
    }

    private func memoryPreview(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(
                of: #"(?m)^#{1,6}\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?m)^>\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.0)
            .foregroundStyle(.secondary)
    }
}

private struct AssistantMessageText: View {
    let text: String

    private var lines: [String] {
        text.components(
            separatedBy: .newlines
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(
                Array(lines.enumerated()),
                id: \.offset
            ) { _, rawLine in
                lineView(rawLine)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    @ViewBuilder
    private func lineView(
        _ rawLine: String
    ) -> some View {
        let trimmed = rawLine.trimmingCharacters(
            in: .whitespaces
        )

        if trimmed.isEmpty {
            Color.clear
                .frame(height: 3)
        } else if trimmed == "---" ||
                    trimmed == "___" {
            Divider()
                .padding(.vertical, 3)
        } else if let heading = headingText(trimmed) {
            inlineMarkdown(heading.text)
                .font(
                    .system(
                        size: heading.level == 1 ? 18 : 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.primary)
                .padding(
                    .top,
                    heading.level == 1 ? 4 : 2
                )
        } else if trimmed.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 3)

                inlineMarkdown(
                    String(trimmed.dropFirst(2))
                )
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
            }
        } else if let bullet = bulletText(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                inlineMarkdown(bullet)
                    .font(.system(size: 14.5, weight: .regular))
                    .lineSpacing(3)
            }
        } else if let numbered = numberedText(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(numbered.number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)

                inlineMarkdown(numbered.text)
                    .font(.system(size: 14.5, weight: .regular))
                    .lineSpacing(3)
            }
        } else {
            inlineMarkdown(trimmed)
                .font(.system(size: 14.5, weight: .regular))
                .lineSpacing(3)
        }
    }

    private func inlineMarkdown(
        _ value: String
    ) -> Text {
        if let attributed = try? AttributedString(
            markdown: value
        ) {
            return Text(attributed)
        }

        return Text(value)
    }

    private func headingText(
        _ value: String
    ) -> (level: Int, text: String)? {
        var level = 0

        for character in value {
            guard character == "#" else {
                break
            }
            level += 1
        }

        guard
            level > 0,
            level <= 6
        else {
            return nil
        }

        let index = value.index(
            value.startIndex,
            offsetBy: level
        )

        let remainder = value[index...]
            .trimmingCharacters(
                in: .whitespaces
            )

        guard !remainder.isEmpty else {
            return nil
        }

        return (level, remainder)
    }

    private func bulletText(
        _ value: String
    ) -> String? {
        for prefix in ["- ", "* ", "• "] {
            if value.hasPrefix(prefix) {
                return String(
                    value.dropFirst(prefix.count)
                )
            }
        }

        return nil
    }

    private func numberedText(
        _ value: String
    ) -> (number: String, text: String)? {
        guard
            let regex = try? NSRegularExpression(
                pattern: #"^([0-9]{1,3}[.)])\s+(.+)$"#
            )
        else {
            return nil
        }

        let fullRange = NSRange(
            value.startIndex..<value.endIndex,
            in: value
        )

        guard
            let match = regex.firstMatch(
                in: value,
                range: fullRange
            ),
            let numberRange = Range(
                match.range(at: 1),
                in: value
            ),
            let textRange = Range(
                match.range(at: 2),
                in: value
            )
        else {
            return nil
        }

        return (
            String(value[numberRange]),
            String(value[textRange])
        )
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
    let isLocked: Bool
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
            .disabled(speech.isBusy || isLocked)
            .help(micHelp)

            TextField(
                isLocked
                    ? "KRALİ mevcut görevi tamamlıyor…"
                    : "KRALİ'ye normal konuşur gibi görev ver…",
                text: $prompt,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...5)
            .disabled(isLocked)
            .onSubmit {
                sendPrompt()
            }

            Button("Gönder") {
                sendPrompt()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isLocked ||
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
