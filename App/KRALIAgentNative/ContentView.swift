import SwiftUI
import AppKit
import Foundation

struct ContentView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var prompt = ""
    @State private var inspectorVisible = false
    @State private var compactSidebarVisible = false
    @StateObject private var updater = UpdateController()

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let compactSidebar =
                usesCompactSidebar(width)
            let overlayInspector =
                usesOverlayInspector(width)

            ZStack {
                HStack(spacing: 0) {
                    if !compactSidebar {
                        ConversationSidebarView()
                            .frame(
                                width:
                                    inlineSidebarWidth(
                                        width
                                    )
                            )

                        Divider()
                    }

                    VStack(spacing: 0) {
                        topBar(
                            compactSidebar:
                                compactSidebar
                        )
                        Divider()
                        chatPane(
                            horizontalPadding:
                                width < 820
                                    ? 16
                                    : 28
                        )
                    }
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity
                    )

                    if inspectorVisible &&
                       !overlayInspector {
                        Divider()

                        sidePane
                            .frame(
                                width:
                                    inlineInspectorWidth(
                                        width
                                    )
                            )
                            .transition(
                                .move(edge: .trailing)
                                    .combined(
                                        with: .opacity
                                    )
                            )
                    }
                }

                if (
                    compactSidebar &&
                    compactSidebarVisible
                ) || (
                    overlayInspector &&
                    inspectorVisible
                ) {
                    Color.black
                        .opacity(0.18)
                        .ignoresSafeArea()
                        .contentShape(
                            Rectangle()
                        )
                        .onTapGesture {
                            compactSidebarVisible =
                                false

                            if overlayInspector {
                                inspectorVisible =
                                    false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(10)
                }

                if compactSidebar &&
                   compactSidebarVisible {
                    HStack(spacing: 0) {
                        ConversationSidebarView()
                            .frame(
                                width:
                                    overlaySidebarWidth(
                                        width
                                    )
                            )
                            .background(
                                Color(
                                    nsColor:
                                        .windowBackgroundColor
                                )
                            )
                            .shadow(
                                color:
                                    Color.black
                                        .opacity(0.22),
                                radius: 18,
                                x: 6,
                                y: 0
                            )

                        Spacer(minLength: 0)
                    }
                    .transition(
                        .move(edge: .leading)
                            .combined(
                                with: .opacity
                            )
                    )
                    .zIndex(20)
                }

                if overlayInspector &&
                   inspectorVisible {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        sidePane
                            .frame(
                                width:
                                    overlayInspectorWidth(
                                        width
                                    )
                            )
                            .background(
                                Color(
                                    nsColor:
                                        .windowBackgroundColor
                                )
                            )
                            .shadow(
                                color:
                                    Color.black
                                        .opacity(0.24),
                                radius: 18,
                                x: -6,
                                y: 0
                            )
                    }
                    .transition(
                        .move(edge: .trailing)
                            .combined(
                                with: .opacity
                            )
                    )
                    .zIndex(20)
                }
            }
            .onChange(
                of: compactSidebar
            ) { _, isCompact in
                if !isCompact {
                    compactSidebarVisible =
                        false
                }
            }
            .background(
                Color(
                    nsColor:
                        .windowBackgroundColor
                )
            )
            .animation(
                .easeInOut(duration: 0.18),
                value: inspectorVisible
            )
            .animation(
                .easeInOut(duration: 0.18),
                value: compactSidebarVisible
            )
        }
    }

    private func usesCompactSidebar(
        _ width: CGFloat
    ) -> Bool {
        width < 780
    }

    private func usesOverlayInspector(
        _ width: CGFloat
    ) -> Bool {
        width < 1120
    }

    private func inlineSidebarWidth(
        _ width: CGFloat
    ) -> CGFloat {
        width < 920
            ? 186
            : 220
    }

    private func overlaySidebarWidth(
        _ width: CGFloat
    ) -> CGFloat {
        min(
            300,
            max(
                226,
                width * 0.38
            )
        )
    }

    private func inlineInspectorWidth(
        _ width: CGFloat
    ) -> CGFloat {
        min(
            360,
            max(
                300,
                width * 0.28
            )
        )
    }

    private func overlayInspectorWidth(
        _ width: CGFloat
    ) -> CGFloat {
        min(
            360,
            max(
                286,
                width * 0.48
            )
        )
    }

    private func topBar(
        compactSidebar: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if compactSidebar {
                Button {
                    compactSidebarVisible
                        .toggle()

                    if compactSidebarVisible {
                        inspectorVisible =
                            false
                    }
                } label: {
                    Image(
                        systemName:
                            "sidebar.left"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Sohbet geçmişini aç/kapat")
            }

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
            .layoutPriority(1)

            Spacer(minLength: 8)

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
                engine.inspectorState.mentorSyncBusy ||
                engine.busy
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
                "Güncellemeleri kontrol et • v\(updater.currentVersion) • build \(updater.currentBuild)"
            )

            Button {
                if !inspectorVisible {
                    engine.loadDiagnosticsIfNeeded()
                }
                inspectorVisible.toggle()

                if inspectorVisible {
                    compactSidebarVisible =
                        false
                }
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
            ? "Yeni sürüm hazır • v\(updater.currentVersion) • build \(updater.currentBuild)"
            : "Hazır • v\(updater.currentVersion) • build \(updater.currentBuild)"
    }

    private func chatPane(
        horizontalPadding: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            if engine.isViewingArchivedConversation {
                archiveBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 22
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

                        if !engine.isViewingArchivedConversation,
                           engine.pendingTaskApproval == nil,
                           let developerApproval =
                            engine.pendingDeveloperToolApproval {
                            developerToolApprovalCard(
                                developerApproval
                            )
                            .id(developerApproval.id)
                        }

                        if !engine.isViewingArchivedConversation,
                           engine.pendingTaskApproval == nil,
                           engine.pendingDeveloperToolApproval == nil,
                           let fileAction =
                            engine.pendingFileAction {
                            fileActionApprovalCard(
                                fileAction
                            )
                            .id(fileAction.id)
                        }

                        if engine.busy &&
                           !engine.isViewingArchivedConversation {
                            thinkingRow
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("chat-bottom-anchor")
                    }
                    .frame(
                        maxWidth: 820,
                        alignment: .leading
                    )
                    .padding(
                        .horizontal,
                        horizontalPadding
                    )
                    .padding(.vertical, 24)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(
                            "chat-bottom-anchor",
                            anchor: .bottom
                        )
                    }
                }
                .onChange(
                    of:
                        engine
                            .selectedConversationArchiveID
                ) { _, _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo(
                            "chat-bottom-anchor",
                            anchor: .bottom
                        )
                    }
                }
                .onChange(
                    of: engine
                        .visibleConversationMessages
                        .count
                ) { _, _ in
                    withAnimation(
                        .easeOut(duration: 0.18)
                    ) {
                        proxy.scrollTo(
                            "chat-bottom-anchor",
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
                assistantStatusBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

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
                        engine.pendingTaskApproval != nil ||
                        engine.pendingDeveloperToolApproval != nil,
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


    private var assistantStatusBar: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(
                        assistantPhaseColor
                            .opacity(0.12)
                    )
                    .frame(
                        width: 28,
                        height: 28
                    )

                if engine.busy {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(
                        systemName:
                            assistantPhaseIcon
                    )
                    .font(.caption)
                    .foregroundStyle(
                        assistantPhaseColor
                    )
                }
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(assistantPhaseTitle)
                    .font(
                        .caption
                            .weight(.semibold)
                    )

                Text(assistantPhaseDetail)
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
            }

            Spacer()

            if engine.pendingTaskApproval != nil ||
               engine.pendingDeveloperToolApproval != nil ||
               engine.pendingFileAction != nil {
                Text("ONAY")
                    .font(
                        .caption2
                            .weight(.bold)
                    )
                    .foregroundStyle(
                        Color.orange
                    )
                    .padding(
                        .horizontal,
                        7
                    )
                    .padding(
                        .vertical,
                        3
                    )
                    .background(
                        Color.orange
                            .opacity(0.10)
                    )
                    .clipShape(
                        Capsule()
                    )
            }
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            8
        )
        .background(
            Color(nsColor:
                .controlBackgroundColor)
                .opacity(0.78)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
    }

    private var assistantPhaseTitle: String {
        if engine.pendingTaskApproval != nil ||
           engine.pendingDeveloperToolApproval != nil ||
           engine.pendingFileAction != nil {
            return "Onayın bekleniyor"
        }

        if engine.busy {
            return "KRALİ çalışıyor"
        }

        switch engine.verificationState {
        case .checking:
            return "Sonuç doğrulanıyor"
        case .passed:
            return "Görev doğrulandı"
        case .partial:
            return "Görev kısmen tamamlandı"
        case .attention:
            return "Dikkat gerekiyor"
        case .skipped:
            return "Doğrulama gerekmedi"
        case .idle:
            return "Hazır"
        }
    }

    private var assistantPhaseDetail: String {
        if let approval =
            engine.pendingTaskApproval {
            return approval.title
        }

        if let approval =
            engine.pendingDeveloperToolApproval {
            return approval.title
        }

        if let action =
            engine.pendingFileAction {
            return action.title
        }

        if engine.busy {
            return engine.currentGoal
        }

        if engine.verificationSummary
            .isEmpty {
            return "Yeni bir görev verebilirsin."
        }

        return engine.verificationSummary
    }

    private var assistantPhaseIcon: String {
        if engine.pendingTaskApproval != nil ||
           engine.pendingDeveloperToolApproval != nil ||
           engine.pendingFileAction != nil {
            return "hand.raised.fill"
        }

        switch engine.verificationState {
        case .checking:
            return "magnifyingglass"
        case .passed:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.circle.fill"
        case .attention:
            return "exclamationmark.triangle.fill"
        case .skipped:
            return "minus.circle"
        case .idle:
            return "sparkles"
        }
    }

    private var assistantPhaseColor: Color {
        if engine.pendingTaskApproval != nil ||
           engine.pendingDeveloperToolApproval != nil ||
           engine.pendingFileAction != nil {
            return .orange
        }

        switch engine.verificationState {
        case .passed:
            return .green
        case .partial,
             .attention:
            return .orange
        default:
            return .secondary
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
                HStack(
                    alignment: .top,
                    spacing: 0
                ) {
                    Spacer(minLength: 72)

                    VStack(
                        alignment: .trailing,
                        spacing: 5
                    ) {
                        Text(message.text)
                            .font(
                                .system(
                                    size: 15,
                                    weight: .regular
                                )
                            )
                            .lineSpacing(4)
                            .textSelection(
                                .enabled
                            )
                            .padding(
                                .horizontal,
                                15
                            )
                            .padding(
                                .vertical,
                                11
                            )
                            .background(
                                Color.accentColor
                                    .opacity(0.13)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 17,
                                    style:
                                        .continuous
                                )
                            )
                            .frame(
                                maxWidth: 600,
                                alignment:
                                    .trailing
                            )
                    }
                }
            } else {
                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    HStack(spacing: 7) {
                        Image(
                            systemName:
                                "sparkles"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )

                        Text("KRALİ")
                            .font(
                                .caption
                                    .weight(
                                        .semibold
                                    )
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        Spacer()

                        Button {
                            copyMessageText(
                                message.text
                            )
                        } label: {
                            Image(
                                systemName:
                                    "doc.on.doc"
                            )
                            .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(
                            .secondary
                        )
                        .help("Mesajı kopyala")
                    }

                    AssistantMessageText(
                        text: message.text
                    )
                    .textSelection(.enabled)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(
                    maxWidth: 760,
                    alignment: .leading
                )
            }
        }
        .contextMenu {
            Button {
                copyMessageText(
                    message.text
                )
            } label: {
                Label(
                    "Kopyala",
                    systemImage:
                        "doc.on.doc"
                )
            }
        }
    }

    private func copyMessageText(
        _ text: String
    ) {
        let pasteboard =
            NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            text,
            forType: .string
        )
    }

    private func fileActionApprovalCard(
        _ action: PendingFileAction
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
                        "folder.badge.gearshape"
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
                Text("Dosya işlemi onayı")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                Text(action.title)
                    .font(.callout.weight(.medium))

                Text(action.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    "Dosyalarda henüz değişiklik yapılmadı."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Onaylıyorum") {
                        let reply =
                            engine
                                .approvePendingFileAction()
                        engine
                            .postAssistantMessage(
                                reply
                            )
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
                            .cancelPendingFileAction()
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
                Text("Fiziksel işlem için onayın gerekiyor")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                Text(approval.title)
                    .font(.callout.weight(.medium))

                if let target =
                    approval.targetSummary,
                   !target.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Hedef")
                            .font(
                                .caption2
                                    .weight(
                                        .semibold
                                    )
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        Text(target)
                            .font(
                                .caption
                                    .monospaced()
                            )
                            .textSelection(
                                .enabled
                            )
                    }
                    .padding(8)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        Color.orange
                            .opacity(0.06)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 8
                        )
                    )
                }

                Text(approval.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(
                    "Henüz hiçbir fiziksel işlem uygulanmadı",
                    systemImage:
                        "pause.circle.fill"
                )
                .font(
                    .caption2
                        .weight(.medium)
                )
                .foregroundStyle(
                    Color.orange
                )

                Text(
                    "Bu onay yalnız bu adıma ve gösterilen hedefe geçerlidir; sonraki dış işlemler ayrıca onay ister."
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

    private func developerToolApprovalCard(
        _ approval: PendingDeveloperToolApproval
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
                        "hammer.circle.fill"
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
                Text("Sistem etkisi için onayın gerekiyor")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                Text(approval.title)
                    .font(.callout.weight(.medium))

                if let target =
                    approval.targetSummary,
                   !target.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("İzin verilen tek adım")
                            .font(
                                .caption2
                                    .weight(
                                        .semibold
                                    )
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        Text(target)
                            .font(
                                .caption
                                    .monospaced()
                            )
                            .textSelection(
                                .enabled
                            )
                    }
                    .padding(8)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        Color.orange
                            .opacity(0.06)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 8
                        )
                    )
                }

                Text(approval.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(
                    "Mac üzerinde henüz sistem etkisi oluşturulmadı",
                    systemImage:
                        "pause.circle.fill"
                )
                .font(
                    .caption2
                        .weight(.medium)
                )
                .foregroundStyle(
                    Color.orange
                )

                Text(
                    "Bu onay yalnız gösterilen developer adımına geçerlidir; sonraki fiziksel veya sistem etkili adım yeniden onay ister."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Onaylıyorum") {
                        engine
                            .approvePendingDeveloperToolApproval()
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
                            .cancelPendingDeveloperToolApproval()
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
                    "Detaylı araştır",
                    "Bu konuyu güncel ve bağımsız kaynaklarla detaylı araştır; her önemli iddiayı doğrudan kanıtla ve belirsizlikleri açıkça belirt."
                )

                quickButton(
                    "Kaynakları doğrula",
                    "Bu konuşmadaki önemli iddiaları kaynak kalitesi, güncellik ve çelişki açısından doğrula."
                )

                quickButton(
                    "Fikir danış",
                    "Bu konu için alternatifleri, artıları, riskleri ve en güçlü önerini birlikte değerlendirelim."
                )

                quickButton(
                    "KRALİ'yi geliştir",
                    "KRALİ'nin mevcut kaynak kodunu ve kanıtlarını incele; en yüksek etkili güvenli geliştirmeyi bir GitHub adayı olarak planla."
                )

                quickButton(
                    "Bağlamı özetle",
                    "Bu konuşmadaki hedefi, doğrulanmış bulguları, açık soruları ve sonraki en iyi adımı özetle."
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
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack {
                    Text("KRALİ Durumu")
                        .font(.headline)

                    Spacer()

                    Button {
                        inspectorVisible = false
                    } label: {
                        Image(
                            systemName: "xmark"
                        )
                    }
                    .buttonStyle(.borderless)
                    .help("Paneli kapat")
                }

                compactStatusCard

                coreCapabilitiesSection

                if let incident =
                    engine.inspectorState
                        .debugIncident {
                    compactDebugCard(
                        incident
                    )
                }

                if engine.inspectorState
                    .shouldShowPrimaryDeveloperStatus ||
                   !engine.inspectorState
                    .activeLearningJobs
                    .isEmpty {
                    compactDeveloperCard
                }

            }
            .padding(14)
        }
    }

    private var compactStatusCard: some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            HStack(
                alignment: .top,
                spacing: 9
            ) {
                Image(
                    systemName:
                        engine.busy
                        ? "sparkles"
                        : engine
                            .verificationState
                            .systemImage
                )
                .foregroundStyle(
                    engine.verificationState ==
                        .attention ||
                    engine.verificationState ==
                        .partial
                        ? Color.orange
                        : Color.secondary
                )
                .frame(width: 18)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(engine.currentGoal)
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Text(
                        engine.busy
                            ? "KRALİ çalışıyor…"
                            : engine
                                .verificationSummary
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Spacer(minLength: 0)
            }

            if engine.currentPlan !=
                "Yeni görevi bekliyor" {
                Divider()

                Text(engine.currentPlan)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

        }
        .padding(12)
        .background(
            Color(
                nsColor:
                    .controlBackgroundColor
            )
            .opacity(0.82)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }

    private var coreCapabilitiesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Text("Çekirdek yetenekler")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(engine.activeCoreIntent.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }

            Divider()

            coreStatusRow(
                title: "Konuşma ve anlama",
                detail: engine.contextMemoryStatus,
                systemImage: "bubble.left.and.bubble.right"
            )

            coreStatusRow(
                title: "Araştırma",
                detail: engine.webResearchStatus,
                systemImage: "globe"
            )

            coreStatusRow(
                title: "GitHub geliştirme",
                detail: engine.inspectorState.developerAgentStatus.message,
                systemImage: "hammer"
            )

            Text(
                "Desktop, ekran kontrolü ve yerel dosya otomasyonu bu çekirdek profilde kapalıdır."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(
            Color(nsColor: .controlBackgroundColor)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 11,
                style: .continuous
            )
        )
    }

    private func coreStatusRow(
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
    }

    private func compactDebugCard(
        _ incident: AgentDebugIncident
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack(spacing: 7) {
                if incident.progress.isActive {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(
                        systemName:
                            incident
                                .kind
                                .systemImage
                    )
                    .foregroundStyle(
                        incident.progress ==
                            .recovered
                            ? Color.green
                            : Color.orange
                    )
                }

                Text(
                    incident.progress.title
                )
                .font(
                    .caption
                        .weight(.semibold)
                )

                Spacer()
            }

            Text(incident.summary)
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if incident.progress.isActive {
                Divider()

                Text(
                    incident.recoveryPlan
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
        .padding(11)
        .background(
            incident.progress == .recovered
                ? Color.green.opacity(0.06)
                : Color.orange.opacity(0.06)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 11,
                style: .continuous
            )
        )
    }

    private var compactDeveloperCard: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            let status =
                engine.inspectorState
                    .developerAgentStatus

            HStack(spacing: 7) {
                if status.isLearningActive {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(
                        systemName:
                            status.isReadyForReview
                            ? "checkmark.circle.fill"
                            : "hammer"
                    )
                    .foregroundStyle(
                        status.isReadyForReview
                            ? Color.green
                            : Color.secondary
                    )
                }

                Text("Geliştirme")
                    .font(
                        .caption
                            .weight(.semibold)
                    )

                Spacer()

                if !engine.inspectorState
                    .activeLearningJobs
                    .isEmpty {
                    Text(
                        String(
                            engine
                                .inspectorState
                                .activeLearningJobs
                                .count
                        ) +
                        " iş"
                    )
                    .font(
                        .caption2
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            if engine.inspectorState
                .shouldShowPrimaryDeveloperStatus {
                Text(
                    status
                        .learningStageTitle
                )
                .font(
                    .caption
                        .weight(.medium)
                )

                Text(status.message)
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            ForEach(
                engine.inspectorState
                    .activeLearningJobs
                    .prefix(2)
            ) { job in
                Divider()

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        job.capabilityName
                    )
                    .font(
                        .caption
                            .weight(.medium)
                    )

                    Text(job.state.title)
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }
        }
        .padding(11)
        .background(
            Color(
                nsColor:
                    .controlBackgroundColor
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 11,
                style: .continuous
            )
        )
    }


    @ViewBuilder
    private var contextInspectorSection: some View {
        Group {
            sectionTitle("Bağlam")

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Label(
                        engine.contextMemoryStatus,
                        systemImage: "brain"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text(
                        String(
                            engine
                                .contextMemoryEntries
                                .count
                        )
                    )
                    .font(
                        .caption2
                            .monospacedDigit()
                    )
                    .foregroundStyle(.secondary)
                }

                let visibleContext =
                    engine
                        .activeContextMemories
                        .isEmpty
                        ? Array(
                            engine
                                .contextMemoryEntries
                                .prefix(3)
                        )
                        : Array(
                            engine
                                .activeContextMemories
                                .prefix(3)
                        )

                if visibleContext.isEmpty {
                    Text(
                        "KRALİ tamamlanan görevlerden henüz yeniden kullanılabilir bir bağlam oluşturmadı."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        visibleContext
                    ) { memory in
                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            HStack(spacing: 5) {
                                Image(
                                    systemName:
                                        memory.kind ==
                                            .userRule
                                        ? "bookmark.fill"
                                        : memory.kind ==
                                            .research
                                            ? "globe"
                                            : "clock.arrow.circlepath"
                                )
                                .font(.caption2)
                                .foregroundStyle(
                                    .secondary
                                )

                                Text(memory.title)
                                    .font(
                                        .caption
                                            .weight(
                                                .medium
                                            )
                                    )
                                    .lineLimit(1)

                                Spacer()
                            }

                            Text(
                                memoryPreview(
                                    memory.summary
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineSpacing(1.5)
                            .lineLimit(3)
                        }
                    }
                }
            }
            .padding(11)
            .background(
                Color(nsColor:
                    .controlBackgroundColor)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 11
                )
            )
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
        VStack(alignment: .leading, spacing: 7) {
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
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            }
        } else if let bullet = bulletText(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                inlineMarkdown(bullet)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(4)
            }
        } else if let numbered = numberedText(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(numbered.number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)

                inlineMarkdown(numbered.text)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(4)
            }
        } else {
            inlineMarkdown(trimmed)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(4)
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
