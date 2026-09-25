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

                    if !engine.learningSuggestions.filter({ $0.state == .proposed }).isEmpty {
                        sectionLabel("GELİŞTİRME ÖNERİLERİ")
                            .padding(.top, 10)

                        ForEach(engine.learningSuggestions.filter({ $0.state == .proposed }).prefix(2)) { suggestion in
                            learningSuggestionCard(suggestion)
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

    private func learningSuggestionCard(_ suggestion: AgentLearningSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion.capabilityName).font(.caption.weight(.semibold))
            Text(suggestion.reason).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                Button("Geliştir") { engine.acceptLearningSuggestion(suggestion.id) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .help("Yalnız izole ve bounded bir aday görevi başlatır.")
                Button("Şimdilik geliştirme") { engine.deferLearningSuggestion(suggestion.id) }
                    .buttonStyle(.bordered).controlSize(.small)
                Menu {
                    Button("Bir daha önerme") { engine.suppressLearningSuggestion(suggestion.id) }
                } label: { Image(systemName: "ellipsis") }
                .help("Bu öneriyi kalıcı olarak gizle")
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
