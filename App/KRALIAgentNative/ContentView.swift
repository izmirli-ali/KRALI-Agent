import SwiftUI
import AppKit
import Foundation

struct ContentView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var prompt = ""
    @State private var developerToolsExpanded = false
    @State private var inspectorVisible = false
    @StateObject private var updater = UpdateController()

    var body: some View {
        HStack(spacing: 0) {
            ConversationSidebarView()
                .frame(
                    minWidth: 200,
                    idealWidth: 228,
                    maxWidth: 238
                )

            Divider()

            VStack(spacing: 0) {
                topBar
                Divider()
                chatPane
            }
            .frame(minWidth: 480)

            if inspectorVisible {
                Divider()

                sidePane
                    .frame(
                        minWidth: 280,
                        idealWidth: 340,
                        maxWidth: 390
                    )
                    .transition(
                        .move(edge: .trailing)
                            .combined(with: .opacity)
                    )
            }
        }
        .background(
            Color(nsColor: .windowBackgroundColor)
        )
        .animation(
            .easeInOut(duration: 0.18),
            value: inspectorVisible
        )
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    engine.isViewingArchivedConversation
                        ? "Geçmiş sohbet"
                        : "KRALİ"
                )
                .font(.headline)

                Text(topBarSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if updater.updateAvailable {
                Button("Güncelle") {
                    updater.updateNow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(
                    updater.isLaunchingUpdate
                )
            }

            Button {
                engine.voiceOutputEnabled.toggle()
            } label: {
                Image(
                    systemName:
                        engine.voiceOutputEnabled
                        ? "speaker.wave.2.fill"
                        : "speaker.slash.fill"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Sesli yanıt modunu aç/kapat")

            Button {
                engine.syncMentorTrace()
            } label: {
                if engine.inspectorState.mentorSyncBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(
                        systemName: "arrow.up.doc"
                    )
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(
                !engine.inspectorState.mentorTraceReady ||
                engine.inspectorState.mentorSyncBusy
            )
            .help("Son görevin Mentor kaydını gönder")

            Button {
                updater.checkForUpdates()
            } label: {
                if updater.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(
                        systemName: "arrow.clockwise"
                    )
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(
                updater.isChecking ||
                updater.isLaunchingUpdate
            )
            .help(
                "Güncellemeleri kontrol et • v\(updater.currentVersion)"
            )

            Button {
                if !inspectorVisible {
                    engine.loadDiagnosticsIfNeeded()
                }
                inspectorVisible.toggle()
            } label: {
                Image(
                    systemName: "sidebar.right"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(
                inspectorVisible
                    ? 1.0
                    : 0.82
            )
            .help("Durum ve geliştirici Inspector'ı")
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.ultraThinMaterial)
    }

    private var topBarSubtitle: String {
        if engine.isViewingArchivedConversation {
            return "Salt okunur geçmiş • aktif sohbete dönerek devam edebilirsin"
        }

        if engine.busy {
            return engine.currentGoal
        }

        return updater.updateAvailable
            ? "Yeni sürüm hazır • v\(updater.currentVersion)"
            : "Hazır • v\(updater.currentVersion)"
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            if engine.isViewingArchivedConversation {
                archiveBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 18
                    ) {
                        ForEach(
                            engine.visibleConversationMessages
                        ) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if !engine.isViewingArchivedConversation,
                           let approval =
                            engine.pendingTaskApproval {
                            taskApprovalCard(
                                approval
                            )
                            .id(approval.id)
                        }

                        if engine.busy &&
                           !engine.isViewingArchivedConversation {
                            thinkingRow
                        }
                    }
                    .frame(
                        maxWidth: 860,
                        alignment: .leading
                    )
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                }
                .onChange(
                    of: engine
                        .visibleConversationMessages
                        .count
                ) { _, _ in
                    guard
                        let last =
                            engine
                                .visibleConversationMessages
                                .last
                    else {
                        return
                    }

                    withAnimation(
                        .easeOut(duration: 0.18)
                    ) {
                        proxy.scrollTo(
                            last.id,
                            anchor: .bottom
                        )
                    }
                }
            }

            Divider()

            if engine.isViewingArchivedConversation {
                HStack {
                    Spacer()

                    Button {
                        engine.showActiveConversation()
                    } label: {
                        Label(
                            "Aktif sohbete dön",
                            systemImage:
                                "arrow.uturn.backward"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding(14)
                .background(.ultraThinMaterial)
            } else {
                if engine.messages.count <= 3 {
                    quickActions
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                }

                VoiceStatusView(
                    speech: engine.speech
                )
                .padding(.horizontal, 18)
                .padding(.top, 8)

                VoiceComposerView(
                    speech: engine.speech,
                    prompt: $prompt,
                    isLocked:
                        engine.busy ||
                        engine.pendingTaskApproval != nil,
                    onSend: { text, source in
                        engine.send(
                            text,
                            source: source
                        )
                    }
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var archiveBanner: some View {
        HStack(spacing: 8) {
            Image(
                systemName: "clock.arrow.circlepath"
            )
            .foregroundStyle(.secondary)

            Text(
                "Geçmiş bir sohbeti görüntülüyorsun. Bu kayıt salt okunur."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Aktif sohbete dön") {
                engine.showActiveConversation()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
        .background(
            Color.primary.opacity(0.035)
        )
    }

    private var thinkingRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        Color.accentColor.opacity(0.12)
                    )
                    .frame(width: 28, height: 28)

                ProgressView()
                    .controlSize(.small)
            }

            Text("KRALİ düşünüyor…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func messageBubble(
        _ message: ChatMessage
    ) -> some View {
        Group {
            if message.role == .user {
                HStack(alignment: .top) {
                    Spacer(minLength: 100)

                    Text(message.text)
                        .font(
                            .system(
                                size: 14.5,
                                weight: .medium
                            )
                        )
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            Color.accentColor
                                .opacity(0.14)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                        .frame(
                            maxWidth: 620,
                            alignment: .trailing
                        )
                }
            } else {
                HStack(
                    alignment: .top,
                    spacing: 11
                ) {
                    ZStack {
                        Circle()
                            .fill(
                                Color.accentColor
                                    .opacity(0.10)
                            )
                            .frame(
                                width: 30,
                                height: 30
                            )

                        Image(
                            systemName: "sparkles"
                        )
                        .font(.caption)
                    }

                    AssistantMessageText(
                        text: message.text
                    )
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: 760,
                        alignment: .leading
                    )

                    Spacer(minLength: 20)
                }
            }
        }
    }

    private func taskApprovalCard(
        _ approval: PendingTaskApproval
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 11
        ) {
            ZStack {
                Circle()
                    .fill(
                        Color.orange.opacity(
                            0.14
                        )
                    )
                    .frame(
                        width: 30,
                        height: 30
                    )

                Image(
                    systemName:
                        "exclamationmark.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(
                    Color.orange
                )
            }

            VStack(
                alignment: .leading,
                spacing: 9
            ) {
                Text("Onayın gerekiyor")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                Text(approval.title)
                    .font(.callout.weight(.medium))

                Text(approval.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    "İşlem henüz uygulanmadı. Onay verirsen KRALİ aynı görevde kaldığı adımdan devam edecek."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Onaylıyorum") {
                        engine
                            .approvePendingTaskApproval()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .controlSize(.small)

                    Button(
                        "İptal",
                        role: .cancel
                    ) {
                        engine
                            .cancelPendingTaskApproval()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer(minLength: 20)
        }
        .padding(13)
        .background(
            Color.orange.opacity(0.07)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.orange.opacity(0.28),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
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
                            engine.workspaceIndexReady
                                ? "\(root.lastPathComponent) • \(engine.indexedFiles.count) dosya"
                                : "\(root.lastPathComponent) • indeks gerektiğinde hazırlanacak",
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

                if let incident = engine.inspectorState.debugIncident {
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
                   !engine.inspectorState.activeLearningJobs.isEmpty ||
                   engine.inspectorState.shouldShowPrimaryDeveloperStatus {
                    sectionTitle("Öğrenme")

                    VStack(alignment: .leading, spacing: 8) {
                        let activeQueueJobs =
                            engine.inspectorState.activeLearningJobs

                        if !activeQueueJobs.isEmpty {
                            HStack(spacing: 6) {
                                Image(
                                    systemName:
                                        "list.number"
                                )
                                .font(.caption2)
                                .foregroundStyle(
                                    .secondary
                                )

                                Text(
                                    "Öğrenme kuyruğu • " +
                                    String(
                                        activeQueueJobs
                                            .count
                                    ) +
                                    " iş"
                                )
                                .font(
                                    .caption
                                        .weight(
                                            .semibold
                                        )
                                )

                                Spacer()
                            }

                            ForEach(
                                activeQueueJobs
                                    .prefix(4)
                            ) { job in
                                HStack(
                                    alignment: .top,
                                    spacing: 7
                                ) {
                                    if job.state ==
                                        .running {
                                        ProgressView()
                                            .controlSize(
                                                .mini
                                            )
                                            .frame(
                                                width: 14,
                                                height: 14
                                            )
                                    } else {
                                        Image(
                                            systemName:
                                                "clock"
                                        )
                                        .font(
                                            .caption2
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                        .frame(
                                            width: 14
                                        )
                                    }

                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing: 2
                                    ) {
                                        Text(
                                            job.capabilityName +
                                            " • " +
                                            job.state.title
                                        )
                                        .font(
                                            .caption
                                                .weight(
                                                    .medium
                                                )
                                        )

                                        Text(
                                            "Kanıt: " +
                                            String(
                                                job.evidenceCount
                                            ) +
                                            " • job " +
                                            job.shortID
                                        )
                                        .font(
                                            .caption2
                                                .monospacedDigit()
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )

                                        if let status =
                                            job.lastStatus {
                                            Text(status)
                                                .font(
                                                    .caption2
                                                )
                                                .foregroundStyle(
                                                    .secondary
                                                )
                                                .lineLimit(
                                                    2
                                                )
                                        }
                                    }

                                    Spacer()
                                }
                            }

                            if engine.inspectorState
                                .shouldShowPrimaryDeveloperStatus ||
                               !engine
                                .capabilityLearningPlans
                                .isEmpty {
                                Divider()
                            }
                        }

                        if engine.inspectorState.shouldShowPrimaryDeveloperStatus {
                            HStack(alignment: .top, spacing: 8) {
                                if engine.inspectorState.developerAgentStatus.isLearningActive {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(
                                        systemName:
                                            engine.inspectorState.developerAgentStatus
                                            .isReadyForReview &&
                                        engine.inspectorState.developerAgentStatus.state !=
                                            "build_failed" &&
                                        engine.inspectorState.developerAgentStatus.state !=
                                            "recovered_candidate_build_failed"
                                                ? "checkmark.circle.fill"
                                                : "exclamationmark.triangle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        engine.inspectorState.developerAgentStatus
                                            .isReadyForReview &&
                                        engine.inspectorState.developerAgentStatus.state !=
                                            "build_failed" &&
                                        engine.inspectorState.developerAgentStatus.state !=
                                            "recovered_candidate_build_failed"
                                            ? Color.green
                                            : Color.orange
                                    )
                                    .frame(width: 16)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        engine.inspectorState.developerAgentStatus
                                            .learningStageTitle
                                    )
                                    .font(.caption.weight(.semibold))

                                    Text(engine.inspectorState.developerAgentStatus.message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)

                                    if let timing =
                                        engine.inspectorState.developerAgentStatus
                                            .learningTimingText {
                                        Text(timing)
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()
                            }

                            if !engine.capabilityLearningPlans.isEmpty {
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
                                engine.postAssistantMessage(
                                    reply
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
                        engine.postAssistantMessage(
                            reply
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
                                Text(engine.inspectorState.trainingLabStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runTrainingLab()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.trainingLabBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Research Eval")
                                    .font(.caption.weight(.medium))
                                Text(engine.inspectorState.liveResearchEvalStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runLiveResearchEval()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.liveResearchEvalBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("KRALİ Arena")
                                    .font(.caption.weight(.medium))
                                Text(engine.inspectorState.arenaStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runArena()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.arenaBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Screen Perception Probe")
                                    .font(.caption.weight(.medium))
                                Text(engine.inspectorState.screenPerceptionStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer()

                            Button("Test") {
                                engine.runScreenPerceptionProbe()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.screenPerceptionBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Desktop Control Probe")
                                    .font(.caption.weight(.medium))
                                Text(engine.inspectorState.desktopControlStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer()

                            Button("Test") {
                                engine.runDesktopControlProbe()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.desktopControlBusy)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Developer Agent")
                                    .font(.caption.weight(.medium))
                                Text(engine.inspectorState.developerAgentStatus.message)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button("Çalıştır") {
                                engine.runDeveloperAgent()
                            }
                            .controlSize(.small)
                            .disabled(engine.inspectorState.developerAgentBusy)
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
        HStack(alignment: .bottom, spacing: 10) {
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
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(speech.isBusy || isLocked)
            .help(micHelp)

            TextField(
                isLocked
                    ? "KRALİ mevcut görevi tamamlıyor…"
                    : "KRALİ'ye bir şey sor veya görev ver…",
                text: $prompt,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14.5))
            .lineLimit(1...6)
            .disabled(isLocked)
            .padding(.vertical, 7)
            .onSubmit {
                sendPrompt()
            }

            Button {
                sendPrompt()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(
                        isSendDisabled
                            ? Color.secondary.opacity(0.35)
                            : Color.accentColor
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
            .help("Gönder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Color(nsColor: .controlBackgroundColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.08),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private var isSendDisabled: Bool {
        isLocked ||
        prompt
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
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
