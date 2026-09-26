import SwiftUI
import AppKit

struct ConversationSidebarView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var pendingDelete:
        ConversationArchiveSegment?
    @State private var expandedSuggestionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Button {
                engine.startNewConversation()
            } label: {
                Label(
                    "Yeni sohbet",
                    systemImage: "square.and.pencil"
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(engine.busy)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    sectionLabel("ŞİMDİ")

                    conversationButton(
                        title: "Aktif sohbet",
                        subtitle: engine.busy
                            ? "KRALİ çalışıyor…"
                            : "\(engine.messages.count) mesaj",
                        systemImage: "message.fill",
                        selected:
                            !engine
                                .isViewingArchivedConversation
                    ) {
                        engine.showActiveConversation()
                    }

                    if !newIdeaSuggestions.isEmpty {
                        HStack(spacing: 6) {
                            sectionLabel("YENİ FİKİRLER")

                            Spacer()

                            Button {
                                engine.refreshDevelopmentSuggestionIdeas()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderless)
                            .help("Yeni, yalnızca inceleme amaçlı fikir ekle")
                        }
                        .padding(.top, 10)

                        ForEach(newIdeaSuggestions) { suggestion in
                            developmentSuggestionCard(
                                suggestion
                            )
                        }
                    }

                    if !activeDevelopmentSuggestions.isEmpty {
                        sectionLabel("GELİŞTİRME ÖNERİLERİ")
                            .padding(.top, 10)

                        ForEach(activeDevelopmentSuggestions) { suggestion in
                            developmentSuggestionCard(suggestion)
                        }
                    }

                    sectionLabel("GEÇMİŞ")
                        .padding(.top, 10)

                    if engine.conversationHistory.isEmpty {
                        Text(
                            "Henüz arşivlenmiş sohbet yok."
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    } else {
                        ForEach(
                            engine.conversationHistory
                        ) { segment in
                            archiveConversationRow(
                                segment
                            )
                        }
                    }
                }
                .padding(10)
            }

            Divider()

            HStack(spacing: 7) {
                Circle()
                    .fill(
                        engine.busy
                            ? Color.orange
                            : Color.green
                    )
                    .frame(width: 7, height: 7)

                Text(
                    engine.busy
                        ? "Çalışıyor"
                        : "Hazır"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(12)
        }
        .background(
            .ultraThinMaterial
        )
        .confirmationDialog(
            "Bu sohbet silinsin mi?",
            isPresented:
                Binding(
                    get: {
                        pendingDelete != nil
                    },
                    set: { value in
                        if !value {
                            pendingDelete = nil
                        }
                    }
                ),
            titleVisibility: .visible
        ) {
            Button(
                "Sohbeti sil",
                role: .destructive
            ) {
                guard
                    let segment =
                        pendingDelete
                else {
                    return
                }

                _ =
                    engine
                        .deleteConversationArchive(
                            segment
                        )
                pendingDelete = nil
            }

            Button(
                "Vazgeç",
                role: .cancel
            ) {
                pendingDelete = nil
            }
        } message: {
            if let segment =
                pendingDelete {
                Text(segment.title)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(
                nsImage:
                    NSApplication.shared
                        .applicationIconImage
            )
            .resizable()
            .interpolation(.high)
            .frame(width: 30, height: 30)

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text("KRALİ")
                    .font(.headline)

                Text("Personal AI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func sectionLabel(
        _ text: String
    ) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    private var visibleDevelopmentSuggestions:
        [AgentDevelopmentSuggestion] {
        let visible = engine.developmentSuggestions.filter {
            $0.state != .suppressed
        }
        let lineageKeys = Set(visible.map { suggestionLineageKey($0) }).sorted()

        return lineageKeys
            .compactMap { key in
                visible
                    .filter { suggestionLineageKey($0) == key }
                    .min {
                        let left = developmentSuggestionPriority($0)
                        let right = developmentSuggestionPriority($1)
                        return left == right
                            ? $0.updatedAt > $1.updatedAt
                            : left < right
                    }
            }
            .sorted {
                developmentSuggestionPriority(
                    $0
                ) <
                developmentSuggestionPriority(
                    $1
                )
            }
    }

    private var newIdeaSuggestions: [AgentDevelopmentSuggestion] {
        visibleDevelopmentSuggestions.filter {
            $0.fingerprint.hasPrefix("innovation:")
        }
    }

    private var activeDevelopmentSuggestions: [AgentDevelopmentSuggestion] {
        visibleDevelopmentSuggestions.filter {
            !$0.fingerprint.hasPrefix("innovation:")
        }
    }

    private func suggestionLineageKey(
        _ suggestion: AgentDevelopmentSuggestion
    ) -> String {
        suggestion.fingerprint.components(
            separatedBy: "|retry|"
        ).first ?? suggestion.fingerprint
    }

    private func developmentSuggestionPriority(
        _ suggestion:
            AgentDevelopmentSuggestion
    ) -> String {
        let rank: Int

        switch suggestion.state {
        case .developing:
            rank = 0
        case .readyForReview:
            rank = 1
        case .approved:
            rank = 2
        case .proposed:
            rank = 3
        case .deferred:
            rank = 4
        case .failed:
            rank = 5
        case .released,
             .completed:
            rank = 6
        case .suppressed:
            rank = 9
        }

        let impactRank = suggestion.source == .usability ? 0 : 1
        let riskRank: Int
        switch suggestion.risk.lowercased() {
        case "low": riskRank = 0
        case "medium": riskRank = 1
        default: riskRank = 2
        }

        return String(
            format: "%02d-%02d-%02d-%020.3f",
            rank,
            impactRank,
            riskRank,
            -suggestion
                .updatedAt
                .timeIntervalSince1970
        )
    }

    @ViewBuilder
    private func developmentSuggestionCard(
        _ suggestion:
            AgentDevelopmentSuggestion
    ) -> some View {
        let progress =
            engine.developmentProgress(
                for: suggestion
            )
        let isExpanded = expandedSuggestionID == suggestion.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Button {
                    expandedSuggestionID = isExpanded
                        ? nil
                        : suggestion.id
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        Text(suggestion.title)
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(isExpanded ? 3 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                suggestionMenu(suggestion)
            }

            HStack(spacing: 5) {
                Text(suggestion.source.title)
                Text("•")
                Text(suggestion.state.title)
                Spacer(minLength: 0)
                if suggestion.state == .proposed || suggestion.state == .deferred {
                    Text(engine.canDevelopSuggestion(suggestion) ? "Uygulanabilir" : "İnceleme")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)

            if suggestion.state == .approved ||
                suggestion.state == .developing ||
                suggestion.state == .readyForReview ||
                suggestion.state == .failed {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .help(progress.title + " — " + progress.detail)
            }

            if isExpanded {
                Divider()

                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Fayda: " + suggestion.expectedBenefit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Durum: " + progress.title + " — " + progress.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if suggestion.state == .proposed || suggestion.state == .deferred {
                    HStack(spacing: 7) {
                        Button("Geliştir") {
                            engine.approveDevelopmentSuggestion(id: suggestion.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!engine.canDevelopSuggestion(suggestion))

                        Button("Gizle", role: .destructive) {
                            engine.suppressDevelopmentSuggestion(id: suggestion.id)
                            expandedSuggestionID = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if suggestion.state == .failed || suggestion.state == .readyForReview {
                    Button("Kontrollü tekrar dene") {
                        engine.retryDevelopmentSuggestion(id: suggestion.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Color.primary
                .opacity(isExpanded ? 0.08 : 0.05)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.08),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func suggestionMenu(
        _ suggestion: AgentDevelopmentSuggestion
    ) -> some View {
        Menu {
            if suggestion.state == .proposed || suggestion.state == .deferred {
                Button("Geliştir") {
                    engine.approveDevelopmentSuggestion(id: suggestion.id)
                }
                .disabled(!engine.canDevelopSuggestion(suggestion))

                Button("Bir daha önerme", role: .destructive) {
                    engine.suppressDevelopmentSuggestion(id: suggestion.id)
                }
            }

            if suggestion.state == .failed || suggestion.state == .readyForReview {
                Button("Kontrollü tekrar dene") {
                    engine.retryDevelopmentSuggestion(id: suggestion.id)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .help(suggestionTooltip(
            suggestion,
            progress: engine.developmentProgress(for: suggestion)
        ))
    }

    private func suggestionTooltip(
        _ suggestion: AgentDevelopmentSuggestion,
        progress: AgentDevelopmentProgressSnapshot
    ) -> String {
        [
            suggestion.title,
            suggestion.reason,
            "Beklenen fayda: " + suggestion.expectedBenefit,
            "Durum: " + progress.title,
            progress.detail
        ].joined(separator: "\n\n")
    }

    private func archiveConversationRow(
        _ segment: ConversationArchiveSegment
    ) -> some View {
        HStack(spacing: 4) {
            conversationButton(
                title: segment.title,
                subtitle:
                    segment.subtitle +
                    " • " +
                    String(
                        segment.messageCount
                    ) +
                    " mesaj",
                systemImage: "clock",
                selected:
                    engine
                        .selectedConversationArchiveID ==
                    segment.id
            ) {
                engine.openConversationArchive(
                    segment
                )
            }

            Menu {
                Button {
                    engine.openConversationArchive(
                        segment
                    )
                } label: {
                    Label(
                        "Sohbeti aç",
                        systemImage: "message"
                    )
                }

                Divider()

                Button(
                    role: .destructive
                ) {
                    pendingDelete =
                        segment
                } label: {
                    Label(
                        "Sohbeti sil",
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(
                    systemName: "ellipsis"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(
                    width: 24,
                    height: 28
                )
                .contentShape(
                    Rectangle()
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Sohbet seçenekleri")
        }
        .contextMenu {
            Button {
                engine.openConversationArchive(
                    segment
                )
            } label: {
                Label(
                    "Sohbeti aç",
                    systemImage: "message"
                )
            }

            Button(
                role: .destructive
            ) {
                _ =
                    engine
                        .deleteConversationArchive(
                            segment
                        )
            } label: {
                Label(
                    "Sohbeti sil",
                    systemImage: "trash"
                )
            }
        }
    }

    private func conversationButton(
        title: String,
        subtitle: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(
                alignment: .top,
                spacing: 9
            ) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(
                        selected
                            ? Color.primary
                            : Color.secondary
                    )
                    .frame(width: 16)

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(title)
                        .font(
                            .system(
                                size: 13,
                                weight:
                                    selected
                                    ? .semibold
                                    : .medium
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                selected
                    ? Color.primary.opacity(0.07)
                    : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 9,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }
}
