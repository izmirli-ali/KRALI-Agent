import SwiftUI
import AppKit

struct ConversationSidebarView: View {
    @EnvironmentObject private var engine: AgentEngine

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
