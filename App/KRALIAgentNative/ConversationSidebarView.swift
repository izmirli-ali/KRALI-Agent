import SwiftUI
import AppKit

struct ConversationSidebarView: View {
    @EnvironmentObject private var engine: AgentEngine
    @State private var pendingDelete:
        ConversationArchiveSegment?

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

                    if !visibleDevelopmentSuggestions.isEmpty {
                        sectionLabel("GELİŞTİRME ÖNERİLERİ")
                            .padding(.top, 10)

                        ForEach(
                            visibleDevelopmentSuggestions
                        ) { suggestion in
                            developmentSuggestionCard(
                                suggestion
                            )
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
        engine.developmentSuggestions
            .filter {
                $0.state != .suppressed
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

        return String(
            format: "%02d-%020.3f",
            rank,
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

        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack(spacing: 6) {
                Text(
                    suggestion.source.title
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(
                    suggestion.state.title
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if suggestion.occurrenceCount > 1 {
                    Text(
                        "×" +
                        String(
                            suggestion
                                .occurrenceCount
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Text(suggestion.title)
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(suggestion.reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            switch suggestion.state {
            case .proposed,
                 .deferred:
                HStack(spacing: 5) {
                    Button("Geliştir") {
                        engine
                            .approveDevelopmentSuggestion(
                                id:
                                    suggestion.id
                            )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .disabled(
                        !suggestion
                            .isExecutableCapabilityGap
                    )
                    .help(
                        suggestion
                            .isExecutableCapabilityGap
                        ? "Kontrollü candidate geliştirmesini başlat"
                        : "Bu öneri tipi için bounded task compiler henüz etkin değil"
                    )

                    Button("Şimdilik") {
                        engine
                            .deferDevelopmentSuggestion(
                                id:
                                    suggestion.id
                            )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                if !suggestion
                    .isExecutableCapabilityGap {
                    Label(
                        "Geliştirme kapsamı derleyicisi bekliyor",
                        systemImage:
                            "lock.shield"
                    )
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }

            case .approved,
                 .developing,
                 .readyForReview,
                 .failed:
                ProgressView(
                    value:
                        progress.fraction
                )
                .progressViewStyle(.linear)

                HStack(spacing: 4) {
                    Text(
                        String(
                            Int(
                                (
                                    progress
                                        .fraction *
                                    100
                                )
                                .rounded()
                            )
                        ) +
                        "%"
                    )
                    .font(
                        .caption2
                            .weight(.semibold)
                    )

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(progress.title)
                        .font(.caption2)
                        .foregroundStyle(
                            progress
                                .isTerminalFailure
                            ? Color.secondary
                            : Color.primary
                        )
                        .lineLimit(1)
                }

                Text(progress.detail)
                    .font(
                        .system(size: 9)
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if suggestion.state ==
                    .readyForReview {
                    Label(
                        "İnceleme gerekiyor",
                        systemImage:
                            "person.badge.shield.checkmark"
                    )
                    .font(
                        .caption2
                            .weight(.semibold)
                    )
                }

                if let branch =
                    suggestion
                        .candidateBranch {
                    Text(branch)
                        .font(
                            .system(
                                size: 9,
                                design:
                                    .monospaced
                            )
                        )
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

            case .released,
                 .completed:
                Label(
                    progress.title,
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(
                    .caption2
                        .weight(.semibold)
                )

            case .suppressed:
                EmptyView()
            }
        }
        .padding(9)
        .background(
            Color.primary
                .opacity(0.045)
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
        .contextMenu {
            if suggestion.state ==
                .proposed ||
               suggestion.state ==
                .deferred {
                Button(
                    role: .destructive
                ) {
                    engine
                        .suppressDevelopmentSuggestion(
                            id:
                                suggestion.id
                        )
                } label: {
                    Label(
                        "Bir daha önerme",
                        systemImage:
                            "eye.slash"
                    )
                }
            }
        }
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
